# frozen_string_literal: true

module Iade
  # Reclassement IDE → IADE AP-HP (Décret n° 2017-984 art. 14-15, correspondance
  # officielle IDE grade 1 → IADE 1er grade ; classement par indice pour IDE grade 2).
  class ReclassementIdeVersIadeCalculator
    # IDE G1 échelon => [échelon IADE G1, ancienneté] ; échelon 3 dépend de l'ancienneté
    # dans l'échelon (voir #reclassement_grade1).
    TABLE_IDE_G1_VERS_IADE_G1 = {
      4  => { echelon: 2, anciennete: "Ancienneté acquise" },
      5  => { echelon: 3, anciennete: "4/5 de l'ancienneté acquise" },
      6  => { echelon: 4, anciennete: "2/3 de l'ancienneté acquise" },
      7  => { echelon: 5, anciennete: "5/6 de l'ancienneté acquise" },
      8  => { echelon: 6, anciennete: "Ancienneté acquise" },
      9  => { echelon: 7, anciennete: "3/4 de l'ancienneté acquise" },
      10 => { echelon: 8, anciennete: "Sans ancienneté" },
      11 => { echelon: 9, anciennete: "Ancienneté acquise" }
    }.freeze

    FALLBACK = { grade: "grade1", echelon: 1, anciennete: "Sans ancienneté" }.freeze

    def initialize(situation_actuelle: nil, grade_source: nil, echelon_source: nil, mois_echelon_source: nil,
                   mois_nomination: nil, zone_paris: nil, nb_enfants_sft: nil, dtc_choix: nil, dtc_montant: nil, **)
      @situation_actuelle  = situation_actuelle.to_s
      @grade_source        = grade_source
      @echelon_source      = echelon_source.presence&.to_i
      @mois_echelon_source = parse_mois(mois_echelon_source)
      @mois_nomination     = parse_mois(mois_nomination)
      @zone_paris          = zone_paris.to_s
      @nb_enfants_sft      = nb_enfants_sft.presence&.to_i || 0
      @dtc_choix           = dtc_choix.to_s
      @dtc_montant         = dtc_montant
      @alertes = []
    end

    def call
      return fallback_result("mode_simple") if %w[prive non ne_sais_pas].include?(@situation_actuelle)
      return { "incomplet" => true, "alertes" => ["Grade, échelon et dates requis pour projeter la carrière."] } unless prerequis_presents?

      projection = Iade::CarriereProjectionCalculator.project_to_date(
        grade: @grade_source, echelon_connu: @echelon_source, date_connue: @mois_echelon_source,
        date_cible: @mois_nomination
      )

      reclassement = reclasser(projection)

      {
        "situation_actuelle" => { "grade" => @grade_source, "echelon" => @echelon_source,
                                   "depuis" => @mois_echelon_source.strftime("%Y-%m") },
        "projection" => { "grade" => @grade_source, "echelon" => projection.echelon,
                           "anciennete_mois" => projection.anciennete_mois,
                           "au" => @mois_nomination.strftime("%Y-%m") },
        "reclassement" => { "grade" => reclassement[:grade], "echelon" => reclassement[:echelon],
                             "anciennete" => reclassement[:anciennete] },
        "net_avant_pas" => net_avant_pas(reclassement[:echelon]),
        "alertes" => @alertes + alertes_saisie
      }
    end

    private

    def prerequis_presents?
      @grade_source && @echelon_source && @mois_echelon_source && @mois_nomination
    end

    def reclasser(projection)
      if @grade_source == "ide_grade1"
        reclassement_grade1(projection)
      elsif @grade_source == "ide_grade2"
        reclassement_grade2(projection)
      else
        @alertes << "Grade IDE inconnu — classement par défaut appliqué, à confirmer RH."
        FALLBACK
      end
    end

    def reclassement_grade1(projection)
      echelon = projection.echelon

      if echelon == 3
        anciennete = projection.anciennete_mois >= 12 ? "Ancienneté acquise" : "Sans ancienneté"
        return { grade: "grade1", echelon: 1, anciennete: anciennete }
      end

      entree = TABLE_IDE_G1_VERS_IADE_G1[echelon]
      unless entree
        @alertes << "Échelon IDE #{echelon} hors de la table de correspondance connue — classement par défaut appliqué, à confirmer RH."
        return FALLBACK
      end

      { grade: "grade1", echelon: entree[:echelon], anciennete: entree[:anciennete] }
    end

    def reclassement_grade2(projection)
      if projection.echelon == 1
        return { grade: "grade1", echelon: 1, anciennete: "Sans ancienneté" }
      end

      indice_source = GradeScale.indice_for(grade: "ide_grade2", echelon: projection.echelon, date: @mois_nomination)
      unless indice_source
        @alertes << "Indice IDE grade 2 introuvable pour cet échelon à cette date — classement par défaut appliqué."
        return FALLBACK
      end

      classement = Iade::CarriereProjectionCalculator.classer_par_indice(
        grade_cible: "grade1", indice_source: indice_source, date: @mois_nomination
      )
      unless classement
        @alertes << "Grille IADE 1er grade introuvable à cette date — classement par défaut appliqué."
        return FALLBACK
      end

      @alertes << "Maintien d'indice à vérifier RH : aucun échelon IADE n'atteint votre indice IDE." if classement.depasse
      @alertes << "Ancienneté non conservée par hypothèse pour un classement par indice — à confirmer RH."
      { grade: "grade1", echelon: classement.echelon, anciennete: "Sans ancienneté (par hypothèse)" }
    end

    def net_avant_pas(echelon_iade)
      return nil unless @mois_nomination

      result = Iade::PayslipCalculator.call(
        mois_paie: @mois_nomination.strftime("%Y-%m"), profession: "iade", statut: "titulaire",
        grade: "grade1", echelon: echelon_iade, quotite: 1.0,
        departement_code: @zone_paris == "oui" ? "75" : "00",
        nb_enfants_sft: @nb_enfants_sft, nbi_points: 0, taux_pas: 0,
        dtc_montant: @dtc_choix.in?(%w[dtc dtf]) ? @dtc_montant : nil
      )
      result.errors.any? ? nil : result.net_avant_pas.to_f.round(2)
    end

    def alertes_saisie
      alertes = []
      alertes << "Zone d'indemnité de résidence inconnue : Paris (3%) appliqué par défaut." if @zone_paris == "ne_sais_pas"
      alertes << "Ligne DTC/DTF non renseignée : calculée hors DTC/DTF." if @dtc_choix.in?(%w[non ne_sais_pas ""])
      alertes << "Le maintien de la ligne DTC/DTF après changement de corps n'est pas garanti — à vérifier RH." if @dtc_choix.in?(%w[dtc dtf])
      alertes
    end

    def fallback_result(_reason)
      {
        "situation_actuelle" => { "grade" => @grade_source, "echelon" => @echelon_source },
        "reclassement" => { "grade" => FALLBACK[:grade], "echelon" => FALLBACK[:echelon], "anciennete" => FALLBACK[:anciennete] },
        "net_avant_pas" => net_avant_pas(FALLBACK[:echelon]),
        "alertes" => ["Situation IDE privée, non déclarée ou inconnue : classement simplifié IADE 1er grade échelon 1, " \
                      "à confirmer avec votre gestionnaire RH (reprise d'ancienneté éventuelle non prise en compte)."]
      }
    end

    def parse_mois(str)
      return nil if str.blank?

      Date.strptime("#{str}-01", "%Y-%m-%d")
    rescue ArgumentError
      nil
    end
  end
end
