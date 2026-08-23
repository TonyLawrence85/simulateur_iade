# frozen_string_literal: true

require "test_helper"

module Iade
  class PayslipCalculatorTest < ActiveSupport::TestCase
    setup do
      GradeScale.delete_all
      PointValue.delete_all
    end

    test "returns a failure result when required parameters are missing" do
      result = PayslipCalculator.call({})

      assert result.errors.any?
      assert_includes result.errors, "Paramètre manquant : mois_paie"
      assert_includes result.errors, "Paramètre manquant : grade"
      assert_empty result.lines
      assert_equal BigDecimal("0"), result.brut_total
      assert_equal BigDecimal("0"), result.net_paye
    end

    test "builds a basic titular IADE payslip from the fallback grade scale" do
      result = PayslipCalculator.call(base_params)

      assert_empty result.errors
      assert_operator result.brut_total, :>, BigDecimal("0")
      assert_operator result.cotisations_total, :>, BigDecimal("0")
      assert_operator result.net_social, :<, result.brut_total
      assert_equal result.net_social, result.net_avant_pas
      assert_equal result.net_avant_pas, result.net_paye

      assert_line(result, "BT0", type: :brut)
      assert_line(result, "CW1", type: :brut)
      assert_line(result, "LP1", type: :brut)
      assert_line(result, "LPN", type: :brut)
      assert_line(result, "RCN", type: :deduction)
    end

    test "does not add the IADE-specific prime for an IDE" do
      result = PayslipCalculator.call(base_params.merge(profession: "ide"))

      assert_empty result.errors
      assert_line(result, "LP1", type: :brut)
      assert_nil line(result, "LPN")
    end

    test "applies withholding tax after net before PAS" do
      result = PayslipCalculator.call(base_params.merge(taux_pas: "5"))
      q60 = line(result, "Q60")

      assert_empty result.errors
      assert q60
      assert_equal :fiscal, q60[:type]
      assert_operator q60[:montant], :>, BigDecimal("0")
      assert_in_delta(result.net_avant_pas - q60[:montant], result.net_paye, BigDecimal("0.01"))
    end

    private

    def base_params
      {
        mois_paie: "2026-08",
        statut: "titulaire",
        profession: "iade",
        grade: "grade1",
        echelon: 5,
        quotite: "1.0",
        departement_code: "75",
        nb_enfants_sft: 0,
        nbi_points: 0
      }
    end

    def line(result, code)
      result.lines.find { |entry| entry[:code] == code }
    end

    def assert_line(result, code, type:)
      entry = line(result, code)
      assert entry, "Expected payslip line #{code} to be present"
      assert_equal type, entry[:type]
    end
  end
end
