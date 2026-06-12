# frozen_string_literal: true

module Iade
  module PlanningCalculator
    MAJORATION_NUIT_PCT = BigDecimal("0.25")
    MAJORATION_DIMANCHE_PCT = BigDecimal("0.25")
    MAJORATION_FERIE_PCT    = BigDecimal("1.00")
    HEURES_MENSUELLES_REF   = BigDecimal("151.67")

    def self.indemnite_nuit(heures:, tib_mensuel:)
      return BigDecimal("0") if heures.to_f.zero?

      taux = taux_horaire_from_tib(tib_mensuel)
      (taux * BigDecimal(heures.to_s) * (1 + MAJORATION_NUIT_PCT)).round(2)
    end

    def self.dimanche_ferie(heures_dim:, heures_ferie:, tib_mensuel:)
      taux = taux_horaire_from_tib(tib_mensuel)
      indemn_dim   = taux * BigDecimal(heures_dim.to_s)   * MAJORATION_DIMANCHE_PCT
      indemn_ferie = taux * BigDecimal(heures_ferie.to_s) * MAJORATION_FERIE_PCT
      (indemn_dim + indemn_ferie).round(2)
    end

    def self.rappels_m2(tp7_qty:, it7_qty:, dhn_heures:, tib_mensuel:)
      taux = taux_horaire_from_tib(tib_mensuel)
      montant_tp7 = taux * BigDecimal("7") * BigDecimal(tp7_qty.to_s)
      montant_it7 = taux * BigDecimal("7") * BigDecimal(it7_qty.to_s)
      montant_dhn = taux * BigDecimal(dhn_heures.to_s) * (1 + MAJORATION_NUIT_PCT)
      (montant_tp7 + montant_it7 + montant_dhn).round(2)
    end

    def self.taux_horaire_from_tib(tib_mensuel)
      BigDecimal(tib_mensuel.to_s) / HEURES_MENSUELLES_REF
    end
  end
end
