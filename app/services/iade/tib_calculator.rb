# frozen_string_literal: true

module Iade
  class TibCalculator
    VALEUR_POINT = BigDecimal("4.92278")

    # Grille officielle IADE FPH — vérifiée le 18/04/2026
    # Grade 1 : 10 échelons / Grade 2 : 8 échelons
    GRILLE_FALLBACK = {
      "grade1" => {
        1 => 450, 2 => 478, 3 => 506, 4 => 534, 5 => 563,
        6 => 593, 7 => 624, 8 => 656, 9 => 690, 10 => 727
      },
      "grade2" => {
        1 => 558, 2 => 582, 3 => 615, 4 => 648, 5 => 681,
        6 => 714, 7 => 743, 8 => 769
      }
    }.freeze

    attr_reader :grade, :echelon, :quotite, :indice_majore

    def initialize(grade:, echelon:, quotite:, date_effet: Date.today)
      @grade      = grade.to_s
      @echelon    = echelon.to_i
      @quotite    = BigDecimal(quotite.to_s)
      @date_effet = date_effet
    end

    def compute
      @indice_majore = resolve_indice_majore
      raise ArgumentError, "Échelon #{@echelon} inconnu pour grade #{@grade}" unless @indice_majore

      (@indice_majore * valeur_point * @quotite).round(2)
    end

    def compute_annuel
      compute * 12
    end

    def taux_horaire
      compute_annuel / BigDecimal("1820")
    end

    private

    def resolve_indice_majore
      scale = GradeScale.active_at(@date_effet).find_by(grade: @grade, echelon: @echelon)
      return scale.indice_majore if scale

      GRILLE_FALLBACK.dig(@grade, @echelon)
    end

    def valeur_point
      pv = PointValue.active_at(@date_effet).first
      return BigDecimal(pv.valeur.to_s) if pv

      VALEUR_POINT
    end
  end
end
