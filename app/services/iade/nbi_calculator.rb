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

  module AutoPrimesCalculator
    CTI_MONTANT      = BigDecimal("206.00")
    PRIME_VEIL       = BigDecimal("26.30")
    PRIME_IADE_PLEIN = BigDecimal("485.72")

    def self.prime_iade(quotite)
      (PRIME_IADE_PLEIN * BigDecimal(quotite.to_s)).round(2)
    end

    def self.cti(quotite)
      (CTI_MONTANT * BigDecimal(quotite.to_s)).round(2)
    end
  end
end
