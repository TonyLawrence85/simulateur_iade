require "test_helper"

class Iade::TibCalculatorTest < ActiveSupport::TestCase
  test "computes full time TIB from fallback grade scale" do
    calculator = Iade::TibCalculator.new(grade: "grade1", echelon: 1, quotite: 1)

    assert_equal BigDecimal("2215.25"), calculator.compute
    assert_equal 450, calculator.indice_majore
  end

  test "applies work quotite to TIB" do
    calculator = Iade::TibCalculator.new(grade: "grade1", echelon: 1, quotite: "0.8")

    assert_equal BigDecimal("1772.20"), calculator.compute
  end

  test "computes annual and hourly values consistently" do
    calculator = Iade::TibCalculator.new(grade: "grade2", echelon: 1, quotite: 1)
    monthly = calculator.compute

    assert_equal monthly * 12, calculator.compute_annuel
    assert_in_delta((monthly * 12 / BigDecimal("1820")).to_f, calculator.taux_horaire.to_f, 0.000001)
  end

  test "rejects an unknown echelon" do
    calculator = Iade::TibCalculator.new(grade: "grade1", echelon: 99, quotite: 1)

    error = assert_raises(ArgumentError) { calculator.compute }
    assert_match(/Échelon 99 inconnu/, error.message)
  end
end
