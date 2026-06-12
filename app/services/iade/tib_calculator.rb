# frozen_string_literal: true

module Iade
  class TibCalculator
    VALEUR_POINT = BigDecimal("4.92284")

    GRILLE_FALLBACK = {
      "grade1" => {
        1 => 340, 2  => 358, 3  => 379, 4  => 405, 5  => 430,
        6 => 458, 7  => 487, 8  => 514, 9  => 541, 10 => 566, 11 => 583
      },
      "grade2" => {
        1 => 517, 2  => 536, 3  => 556, 4  => 577, 5  => 598,
        6 => 618, 7  => 638, 8  => 659, 9  => 680, 10 => 700, 11 => 718
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
      compute_annuel / BigDecimal("1607")
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
