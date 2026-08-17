# frozen_string_literal: true

module Iade
  # Promouvabilité IADE 1er grade → 2e grade (Décret n° 2017-984, art. 16) : au moins
  # 1 an dans le 4e échelon du 1er grade ET 10 ans de services effectifs catégorie A
  # paramédicale. Donne une ANNÉE de promouvabilité, jamais une promesse de promotion
  # automatique (l'inscription sur liste d'aptitude reste une décision RH distincte).
  class Promotion2eGradeCalculator
    # Reclassement au 2e grade si la promotion est accordée, selon l'échelon 1er grade
    # détenu au moment du passage.
    TABLE_RECLASSEMENT_2E_GRADE = {
      4  => { echelon: 1, anciennete: "Ancienneté acquise" },
      5  => { echelon: 2, anciennete: "4/5 de l'ancienneté acquise" },
      6  => { echelon: 3, anciennete: "5/6 de l'ancienneté acquise" },
      7  => { echelon: 4, anciennete: "Ancienneté acquise" },
      8  => { echelon: 5, anciennete: "3/4 de l'ancienneté acquise" },
      9  => { echelon: 6, anciennete: "Ancienneté acquise" },
      10 => { echelon: 7, anciennete: "Ancienneté acquise" }
    }.freeze

    def initialize(echelon_actuel: nil, mois_echelon_actuel: nil, mois_debut_cat_a: nil,
                   periode_exclue: nil, periode_debut: nil, periode_fin: nil, **)
      @echelon_actuel       = echelon_actuel.presence&.to_i
      @mois_echelon_actuel  = parse_mois(mois_echelon_actuel)
      @mois_debut_cat_a     = parse_mois(mois_debut_cat_a)
      @periode_exclue       = periode_exclue.to_s
      @periode_debut        = parse_mois(periode_debut)
      @periode_fin          = parse_mois(periode_fin)
      @alertes = []
    end

    def call
      return { "incomplet" => true, "alertes" => ["Échelon actuel et dates requis pour estimer la promouvabilité."] } unless prerequis_presents?

      date_condition_echelon = calc_date_condition_echelon
      date_condition_10_ans  = calc_date_condition_10_ans

      resultat = {
        "situation_actuelle" => {
          "grade" => "grade1", "echelon" => @echelon_actuel, "depuis" => @mois_echelon_actuel.strftime("%Y-%m")
        },
        "condition_echelon" => format_condition("Vous aurez 1 an dans le 4e échelon", date_condition_echelon),
        "condition_10_ans"  => format_condition("Vous atteindrez 10 ans de catégorie A", date_condition_10_ans),
        "alertes" => @alertes
      }

      if date_condition_echelon && date_condition_10_ans
        date_reunies = [date_condition_echelon, date_condition_10_ans].max
        resultat["annee_promouvabilite"] = date_reunies.year
        resultat["resultat"] =
          "Conditions réunies au plus tard en #{date_reunies.year} : vous serez promouvable au titre de l'année #{date_reunies.year}."
        resultat["conseil"] = "À partir de cette année-là, vous pouvez demander confirmation à votre gestionnaire RH."
      end

      resultat["reclassement_2e_grade"] = reclassement_2e_grade if @echelon_actuel && @echelon_actuel >= 4

      resultat
    end

    private

    def prerequis_presents?
      @echelon_actuel && @mois_echelon_actuel && @mois_debut_cat_a
    end

    def calc_date_condition_echelon
      date_echelon_4 = Iade::CarriereProjectionCalculator.date_entree_echelon_estime(
        grade: "grade1", echelon_connu: @echelon_actuel, date_connue: @mois_echelon_actuel, echelon_cible: 4
      )
      unless date_echelon_4
        @alertes << "Impossible d'estimer la date d'entrée dans le 4e échelon (échelon terminal atteint avant)."
        return nil
      end

      ecart = (@echelon_actuel - 4).abs
      if ecart >= 3
        @alertes << "La date d'entrée dans le 4e échelon est extrapolée sur plusieurs échelons : estimation très indicative."
      elsif ecart >= 1
        @alertes << "La date d'entrée dans le 4e échelon est estimée à partir de votre échelon actuel (cadence standard supposée)."
      end

      date_echelon_4 + 1.year
    end

    def calc_date_condition_10_ans
      duree_exclue_mois = periode_exclue_mois
      date = @mois_debut_cat_a + 10.years
      date += duree_exclue_mois.months if duree_exclue_mois.positive?

      if @periode_exclue == "ne_sais_pas" || (@periode_exclue == "oui" && duree_exclue_mois.zero?)
        @alertes << "Date des 10 ans catégorie A calculée sans période exclue confirmée : il s'agit d'un minimum, " \
                    "la vraie date peut être identique ou postérieure si une période a été exclue."
      end

      date
    end

    def periode_exclue_mois
      return 0 unless @periode_exclue == "oui" && @periode_debut && @periode_fin

      [Iade::CarriereProjectionCalculator.months_between(@periode_debut, @periode_fin), 0].max
    end

    def reclassement_2e_grade
      entree = TABLE_RECLASSEMENT_2E_GRADE[@echelon_actuel]
      return { "disponible" => false } unless entree

      { "disponible" => true, "grade" => "grade2", "echelon" => entree[:echelon], "anciennete" => entree[:anciennete] }
    end

    def format_condition(label, date)
      return "#{label} : date indisponible." unless date
      return "Condition déjà acquise (depuis le #{date.strftime('%m/%Y')})." if date <= Date.today

      "#{label} le #{date.strftime('%m/%Y')}."
    end

    def parse_mois(str)
      return nil if str.blank?

      Date.strptime("#{str}-01", "%Y-%m-%d")
    rescue ArgumentError
      nil
    end
  end
end
