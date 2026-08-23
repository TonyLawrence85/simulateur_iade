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

    test "applies work quota to TIB and automatic IADE primes" do
      full_time = PayslipCalculator.call(base_params)
      part_time = PayslipCalculator.call(base_params.merge(quotite: "0.8"))

      %w[BT0 CW1 LP1 LPN].each do |code|
        assert_in_delta line(full_time, code)[:montant] * BigDecimal("0.8"),
                        line(part_time, code)[:montant], BigDecimal("0.01"),
                        "Expected #{code} to follow the 80% work quota"
      end
      assert_operator part_time.brut_total, :<, full_time.brut_total
    end

    test "adds NBI and its residence allowance when NBI points are present" do
      result = PayslipCalculator.call(base_params.merge(nbi_points: 20))

      assert_empty result.errors
      assert_operator line(result, "KB1")[:montant], :>, BigDecimal("0")
      assert_operator line(result, "KR0")[:montant], :>, BigDecimal("0")
      assert_line(result, "RCB", type: :deduction)
    end

    test "adds NBI family supplement lines for two children" do
      result = PayslipCalculator.call(base_params.merge(nbi_points: 20, nb_enfants_sft: 2))

      assert_empty result.errors
      assert_operator line(result, "CS0")[:montant], :>, BigDecimal("0")
      assert_operator line(result, "KS0")[:montant], :>, BigDecimal("0")
      assert_operator line(result, "KS1")[:montant], :>, BigDecimal("0")
    end

    test "keeps night overtime within IT7 up to the twenty hour monthly contingent" do
      result = PayslipCalculator.call(base_params.merge(hs_m2_nuit: 12))

      assert_empty result.errors
      assert_line(result, "IT7", type: :brut)
      assert_nil line(result, "DHN")
      assert result.warnings.any? { |warning| warning.include?("M-2") }
    end

    test "splits night overtime above twenty hours between IT7 and DHN" do
      result = PayslipCalculator.call(base_params.merge(hs_m2_nuit: 25))
      it7 = line(result, "IT7")
      dhn = line(result, "DHN")

      assert_empty result.errors
      assert it7
      assert dhn
      assert_operator it7[:montant], :>, dhn[:montant]
      assert_match(/20\.0h|20h/, it7[:detail])
      assert_match(/5\.0h|5h/, dhn[:detail])
    end

    test "warns and makes the excess overtime taxable once the annual exemption cap is reached" do
      result = PayslipCalculator.call(base_params.merge(
                                        hs_m2_nuit: 25,
                                        cumul_hs_brut_anterieur: "7490",
                                        taux_pas: "5"
                                      ))
      q60 = line(result, "Q60")

      assert_empty result.errors
      assert q60
      assert_equal true, q60[:estimatif]
      assert result.warnings.any? { |warning| warning.include?("7 500") }
      assert_operator q60[:base_imposable], :>, BigDecimal("0")
    end

    test "does not apply IADE-only overtime inputs to an IDE" do
      result = PayslipCalculator.call(base_params.merge(profession: "ide", hs_m2_nuit: 10, tp7_heures: 4))

      assert_empty result.errors
      assert_nil line(result, "TP7")
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
