# frozen_string_literal: true

module Iade
  class NbiCalculator
    def initialize(points:, date_effet: Date.today)
      @points     = points.to_i
      @date_effet = date_effet
    end

    def montant
      return BigDecimal("0") if @points.zero?

      (@points * valeur_point).round(2)
    end

    private

    def valeur_point
      TibCalculator::VALEUR_POINT
    end
  end
end
