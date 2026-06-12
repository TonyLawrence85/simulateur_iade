# frozen_string_literal: true

module Iade
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
