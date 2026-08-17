# frozen_string_literal: true

module Iade
  # Reclassement Aide-soignant → IDE AP-HP (Décret n° 2010-1139, art. 10) : classement
  # à l'échelon IDE grade 1 dont l'indice est égal ou immédiatement supérieur à
  # l'indice AS détenu au moment de la nomination.
  class ReclassementAsVersIdeCalculator
    FALLBACK = { grade: "ide_grade1", echelon: 1, anciennete: "Sans ancienneté" }.freeze

    def initialize(situation_actuelle: nil, statut_administratif: nil, grade_source: nil, echelon_source: nil,
                   mois_echelon_source: nil, mois_nomination: nil, zone_paris: nil, nb_enfants_sft: nil,
                   dtc_choix: nil, dtc_montant: nil, **)
      @situation_actuelle    = situation_actuelle.to_s
      @statut_administratif  = statut_administratif.to_s
      @grade_source          = grade_source
      @echelon_source        = echelon_source.presence&.to_i
      @mois_echelon_source   = parse_mois(mois_echelon_source)
      @mois_nomination       = parse_mois(mois_nomination)
      @zone_paris            = zone_paris.to_s
      @nb_enfants_sft        = nb_enfants_sft.presence&.to_i || 0
      @dtc_choix             = dtc_choix.to_s
      @dtc_montant           = dtc_montant
      @alertes = []
    end

    def call
      return fallback_result if %w[prive non ne_sais_pas].include?(@situation_actuelle)
      return { "incomplet" => true, "alertes" => ["Grade, échelon et dates requis pour projeter la carrière."] } unless prerequis_presents?

      @alertes << "Statut contractuel : reprise d'ancienneté à valider par RH, non prise en compte ici." if @statut_administratif == "contractuel"

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
      indice_source = GradeScale.indice_for(grade: @grade_source, echelon: projection.echelon, date: @mois_nomination)
      unless indice_source
        @alertes << "Indice AS introuvable pour cet échelon à cette date — classement par défaut appliqué."
        return FALLBACK
      end

      classement = Iade::CarriereProjectionCalculator.classer_par_indice(
        grade_cible: "ide_grade1", indice_source: indice_source, date: @mois_nomination
      )
      unless classement
        @alertes << "Grille IDE grade 1 introuvable à cette date — classement par défaut appliqué."
        return FALLBACK
      end

      if classement.depasse
        @alertes << "Aucun échelon IDE grade 1 n'atteint votre indice AS : classé au dernier échelon, " \
                    "maintien d'un indice personnel à vérifier auprès de votre gestionnaire RH."
      end

      { grade: "ide_grade1", echelon: classement.echelon, anciennete: "Sans ancienneté (classement par indice)" }
    end

    def net_avant_pas(echelon_ide)
      return nil unless @mois_nomination

      result = Iade::PayslipCalculator.call(
        mois_paie: @mois_nomination.strftime("%Y-%m"), profession: "ide", statut: "titulaire",
        grade: "ide_grade1", echelon: echelon_ide, quotite: 1.0,
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

    def fallback_result
      {
        "situation_actuelle" => { "grade" => @grade_source, "echelon" => @echelon_source },
        "reclassement" => { "grade" => FALLBACK[:grade], "echelon" => FALLBACK[:echelon], "anciennete" => FALLBACK[:anciennete] },
        "net_avant_pas" => net_avant_pas(FALLBACK[:echelon]),
        "alertes" => ["Situation AS privée, non déclarée ou inconnue : classement simplifié IDE grade 1 échelon 1, " \
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
