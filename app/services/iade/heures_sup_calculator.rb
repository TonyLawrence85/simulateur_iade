# frozen_string_literal: true

module Iade
  class HeuresSupCalculator
    MAJORATIONS = {
      jour_25: BigDecimal("1.25"), jour_50:  BigDecimal("1.50"), jour_100: BigDecimal("2.00"),
      nuit_25: BigDecimal("1.25"), nuit_50:  BigDecimal("1.50"), nuit_100: BigDecimal("2.00")
    }.freeze

    LABELS = {
      jour_25: "HS JOUR – 25%",  jour_50:  "HS JOUR – 50%",  jour_100: "HS JOUR – 100%",
      nuit_25: "HS NUIT – 25%",  nuit_50:  "HS NUIT – 50%",  nuit_100: "HS NUIT – 100%"
    }.freeze

    def initialize(tib_mensuel:, hs_jour_25: 0, hs_jour_50: 0, hs_jour_100: 0,
                   hs_nuit_25: 0, hs_nuit_50: 0, hs_nuit_100: 0)
      @heures = {
        jour_25: BigDecimal(hs_jour_25.to_s), jour_50: BigDecimal(hs_jour_50.to_s), jour_100: BigDecimal(hs_jour_100.to_s),
        nuit_25: BigDecimal(hs_nuit_25.to_s), nuit_50: BigDecimal(hs_nuit_50.to_s), nuit_100: BigDecimal(hs_nuit_100.to_s)
      }
      @taux_horaire = PlanningCalculator.taux_horaire_from_tib(tib_mensuel)
    end

    def compute
      lines = []
      total = BigDecimal("0")

      @heures.each do |type, heures|
        next if heures.zero?

        montant = (@taux_horaire * heures * MAJORATIONS[type]).round(2)
        lines << { code: "HS#{type.to_s.upcase}", label: LABELS[type], montant: montant,
                   detail: "#{heures}h × #{@taux_horaire.round(4)} €/h × #{MAJORATIONS[type]}" }
        total += montant
      end

      { lines: lines, total: total.round(2) }
    end
  end
end
