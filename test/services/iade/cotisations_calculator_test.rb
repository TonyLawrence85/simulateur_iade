# frozen_string_literal: true

require "test_helper"

module Iade
  class CotisationsCalculatorTest < ActiveSupport::TestCase
    test "calculates CNRACL contribution from its assessment base" do
      assert_equal BigDecimal("222.00"), CotisationsCalculator.cnracl(assiette: 2000)
    end

    test "calculates IRCANTEC contribution from its assessment base" do
      assert_equal BigDecimal("80.20"), CotisationsCalculator.ircantec(assiette: 2000)
    end

    test "caps annual RAFP assessment base at twenty percent of annual TIB" do
      contribution = CotisationsCalculator.rafp(assiette_primes: 1000, tib_annuel: 30_000)

      assert_equal BigDecimal("25.00"), contribution
    end

    test "calculates CSG base after professional expense allowance" do
      assert_equal BigDecimal("982.50"), CotisationsCalculator.base_csg(montant: 1000)
    end

    test "calculates CSG CRDS and maladie from CSG base" do
      base = BigDecimal("982.50")

      assert_equal BigDecimal("28.49"), CotisationsCalculator.csg_crds(base_csg: base)
      assert_equal BigDecimal("66.81"), CotisationsCalculator.csg_maladie(base_csg: base)
    end

    test "calculates withholding tax from taxable base and rate" do
      assert_equal BigDecimal("150.00"), CotisationsCalculator.pas(base_imposable: 3000, taux: "0.05")
    end
  end
end
