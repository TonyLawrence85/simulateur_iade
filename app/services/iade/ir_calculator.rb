# frozen_string_literal: true

module Iade
  class IrCalculator
    ZONES = {
      "75" => 1, "92" => 1, "93" => 1, "94" => 1,
      "77" => 2, "78" => 2, "91" => 2, "95" => 2
    }.freeze

    TAUX = {
      1 => BigDecimal("0.03"),
      2 => BigDecimal("0.01"),
      3 => BigDecimal("0.00")
    }.freeze

    attr_reader :zone, :taux

    def initialize(tib:, departement_code:)
      @tib              = BigDecimal(tib.to_s)
      @departement_code = departement_code.to_s.strip
      @zone             = resolve_zone
      @taux             = TAUX[@zone]
    end

    def compute
      { montant: montant, zone: @zone, taux_pct: (@taux * 100).to_f.to_s }
    end

    def montant
      (@tib * @taux).round(2)
    end

    private

    def resolve_zone
      DepartmentZone.zone_for(@departement_code)
    end
  end
end
