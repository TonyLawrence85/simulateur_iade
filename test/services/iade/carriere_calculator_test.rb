# frozen_string_literal: true

require "test_helper"

module Iade
  class CarriereCalculatorTest < ActiveSupport::TestCase
    setup do
      @today = Date.today
      GradeScale.delete_all
      GradeScale.create!(grade: "grade1", echelon: 5, indice_majore: 600, date_debut: @today - 1.year)
      GradeScale.create!(grade: "grade1", echelon: 6, indice_majore: 620, date_debut: @today - 1.year)
      GradeScale.create!(grade: "grade1", echelon: 10, indice_majore: 800, date_debut: @today - 1.year)
    end

    test "computes progression to the next echelon" do
      result = calculator(echelon: 5).compute

      assert_equal 5, result.echelon_actuel
      assert_equal 600, result.im_actuel
      assert_equal 6, result.echelon_suivant
      assert_equal 620, result.im_suivant
      assert_equal 24, result.duree_echelon_mois
      assert_operator result.tib_suivant, :>, result.tib_actuel
      assert_equal result.tib_suivant - result.tib_actuel, result.delta_tib
    end

    test "applies work quota to current and next TIB" do
      full_time = calculator(echelon: 5, quotite: 1).compute
      part_time = calculator(echelon: 5, quotite: "0.8").compute

      assert_equal (full_time.tib_actuel * BigDecimal("0.8")).round(2), part_time.tib_actuel
      assert_equal (full_time.tib_suivant * BigDecimal("0.8")).round(2), part_time.tib_suivant
    end

    test "calculates remaining months and estimated advancement date" do
      result = calculator(echelon: 5, date_entree_echelon: @today << 12).compute

      assert_equal 12, result.mois_restants
      assert_equal @today >> 12, result.date_estimee
    end

    test "never reports negative remaining months for an overdue advancement" do
      result = calculator(echelon: 5, date_entree_echelon: @today << 36).compute

      assert_equal 0, result.mois_restants
      assert_equal @today, result.date_estimee
    end

    test "returns a terminal result at the final echelon" do
      result = calculator(echelon: 10).compute

      assert_equal 10, result.echelon_actuel
      assert_nil result.echelon_suivant
      assert_nil result.im_suivant
      assert_nil result.tib_suivant
      assert_nil result.delta_tib
      assert_nil result.duree_echelon_mois
      assert_equal false, result.passage_grade2_possible
    end

    test "returns nil when no active grade scale exists" do
      assert_nil calculator(echelon: 4).compute
    end

    private

    def calculator(echelon:, quotite: 1, date_entree_echelon: nil)
      CarriereCalculator.new(
        grade: "grade1",
        echelon: echelon,
        quotite: quotite,
        ir_taux: "0.01",
        date_entree_echelon: date_entree_echelon
      )
    end
  end
end
