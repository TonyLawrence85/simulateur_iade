# frozen_string_literal: true

module Iade
  module PlanningCalculator
    HEURES_ANNUELLES_FPH = BigDecimal("1820")
    TAUX_HORAIRE_IDJF    = BigDecimal("7.50")

    # Taux IHTS FPH (Décret heures supplémentaires) — base = (TIB + IR) × 12 / 1820
    TAUX_JOUR   = BigDecimal("1.26")
    TAUX_NUIT   = BigDecimal("2.52")  # 1.26 × 2
    TAUX_DIM_JF = BigDecimal("2.10")  # 1.26 × (1 + 2/3)

    # Base horaire FPH = (TIB + IR) × 12 / 1820
    def self.base_horaire(tib_mensuel:, ir_mensuel: 0)
      (BigDecimal(tib_mensuel.to_s) + BigDecimal(ir_mensuel.to_s)) * 12 / HEURES_ANNUELLES_FPH
    end

    # JMA (travail de nuit) = 25 % × base_horaire × heures
    def self.indemnite_nuit(heures:, tib_mensuel:, ir_mensuel: 0)
      return BigDecimal("0") if heures.to_f.zero?

      taux = base_horaire(tib_mensuel: tib_mensuel, ir_mensuel: ir_mensuel) * BigDecimal("0.25")
      (taux * BigDecimal(heures.to_s)).round(2)
    end

    # IDJF (dimanche / JF non-HS) = 7,50 €/h fixe (60 € / 8 h) — indépendant du TIB
    def self.dimanche_ferie(heures_dim:, heures_ferie:)
      total_heures = BigDecimal(heures_dim.to_s) + BigDecimal(heures_ferie.to_s)
      (total_heures * TAUX_HORAIRE_IDJF).round(2)
    end
  end
end
