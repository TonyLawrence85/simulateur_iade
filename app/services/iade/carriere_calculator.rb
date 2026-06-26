# frozen_string_literal: true

module Iade
  # Calcule la prochaine évolution de carrière IADE.
  # Durées indicatives (Décret n° 2012-1483) — arrondies à l'année.
  class CarriereCalculator
    # Durée minimale en mois par échelon avant avancement
    DUREES_GRADE1 = {
      1 => 12, 2 => 24, 3 => 24, 4 => 24, 5 => 24,
      6 => 24, 7 => 24, 8 => 36, 9 => 48, 10 => nil
    }.freeze

    DUREES_GRADE2 = {
      1 => 12, 2 => 24, 3 => 24, 4 => 24, 5 => 30,
      6 => 36, 7 => 48, 8 => nil
    }.freeze

    Result = Struct.new(
      :echelon_actuel, :im_actuel, :tib_actuel,
      :echelon_suivant, :im_suivant, :tib_suivant, :delta_tib,
      :duree_echelon_mois, :mois_restants, :date_estimee,
      :taux_hs_nuit_actuel, :taux_hs_nuit_suivant,
      :passage_grade2_possible,
      keyword_init: true
    )

    def initialize(grade:, echelon:, quotite:, ir_taux:, date_entree_echelon: nil)
      @grade   = grade
      @echelon = echelon.to_i
      @quotite = BigDecimal(quotite.to_s)
      @ir_taux = BigDecimal(ir_taux.to_s)
      @date    = date_entree_echelon.presence
    end

    def compute
      im_actuel  = GradeScale.indice_for(grade: @grade, echelon: @echelon)
      return nil unless im_actuel

      tib_actuel = tib(im_actuel)
      taux_actuel = taux_hs_nuit(tib_actuel)

      durees     = @grade == "grade1" ? DUREES_GRADE1 : DUREES_GRADE2
      duree_mois = durees[@echelon]

      if duree_mois.nil?
        return terminal_result(im_actuel, tib_actuel, taux_actuel, @echelon)
      end

      echelon_suivant = @echelon + 1
      im_suivant = GradeScale.indice_for(grade: @grade, echelon: echelon_suivant)

      if im_suivant.nil?
        return terminal_result(im_actuel, tib_actuel, taux_actuel, @echelon)
      end

      tib_suivant  = tib(im_suivant)
      taux_suivant = taux_hs_nuit(tib_suivant)

      mois_restants = nil
      date_estimee  = nil
      if @date
        mois_ecoules  = months_between(@date, Date.today)
        mois_restants = [duree_mois - mois_ecoules, 0].max
        date_estimee  = Date.today >> mois_restants
      end

      Result.new(
        echelon_actuel: @echelon,
        im_actuel: im_actuel,
        tib_actuel: tib_actuel.round(2),
        echelon_suivant: echelon_suivant,
        im_suivant: im_suivant,
        tib_suivant: tib_suivant.round(2),
        delta_tib: (tib_suivant - tib_actuel).round(2),
        duree_echelon_mois: duree_mois,
        mois_restants: mois_restants,
        date_estimee: date_estimee,
        taux_hs_nuit_actuel: taux_actuel.round(2),
        taux_hs_nuit_suivant: taux_suivant.round(2),
        passage_grade2_possible: @grade == "grade1" && @echelon >= 6
      )
    end

    private

    def tib(im)
      BigDecimal(im.to_s) * Iade::TibCalculator::VALEUR_POINT * @quotite
    end

    def taux_hs_nuit(tib_m)
      ir_m       = tib_m * @ir_taux
      base_h     = (tib_m + ir_m) * 12 / BigDecimal("1820")
      base_h * BigDecimal("1.26") * 2
    end

    def months_between(from, to)
      (to.year - from.year) * 12 + (to.month - from.month)
    end

    def terminal_result(im, tib, taux, echelon)
      Result.new(
        echelon_actuel: echelon, im_actuel: im, tib_actuel: tib.round(2),
        echelon_suivant: nil, im_suivant: nil, tib_suivant: nil, delta_tib: nil,
        duree_echelon_mois: nil, mois_restants: nil, date_estimee: nil,
        taux_hs_nuit_actuel: taux.round(2), taux_hs_nuit_suivant: nil,
        passage_grade2_possible: false
      )
    end
  end
end
