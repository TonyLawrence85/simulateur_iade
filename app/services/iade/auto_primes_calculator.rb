# frozen_string_literal: true

module Iade
  module AutoPrimesCalculator
    CTI_POINTS       = 49
    PRIME_VEIL_PLEIN = BigDecimal("90.00")
    PRIME_IADE_PLEIN = BigDecimal("180.00")

    def self.cti(quotite)
      (CTI_POINTS * TibCalculator::VALEUR_POINT * BigDecimal(quotite.to_s)).round(2)
    end

    def self.prime_veil(quotite)
      (PRIME_VEIL_PLEIN * BigDecimal(quotite.to_s)).round(2)
    end

    def self.prime_iade(quotite)
      (PRIME_IADE_PLEIN * BigDecimal(quotite.to_s)).round(2)
    end
  end
end
