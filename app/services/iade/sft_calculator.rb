# frozen_string_literal: true

module Iade
  class SftCalculator
    BAREME = {
      0 => { fixe: BigDecimal("0"),     taux: BigDecimal("0"),    plancher: BigDecimal("0")      },
      1 => { fixe: BigDecimal("2.29"),  taux: BigDecimal("0"),    plancher: BigDecimal("2.29")   },
      2 => { fixe: BigDecimal("10.67"), taux: BigDecimal("0.03"), plancher: BigDecimal("73.04")  },
      3 => { fixe: BigDecimal("15.24"), taux: BigDecimal("0.08"), plancher: BigDecimal("181.56") }
    }.freeze

    EXTRA_PAR_ENFANT = {
      fixe: BigDecimal("4.57"),
      taux: BigDecimal("0.06"),
      plancher: BigDecimal("129.10")
    }.freeze

    def initialize(nb_enfants:, tib:, garde_alternee: false)
      @nb_enfants     = nb_enfants.to_i
      @tib            = BigDecimal(tib.to_s)
      @garde_alternee = garde_alternee
    end

    def compute
      return BigDecimal("0") if @nb_enfants.zero?

      montant = calcul_brut
      montant = apply_plancher(montant)
      montant = apply_plafond(montant)
      montant = apply_garde_alternee(montant)
      montant.round(2)
    end

    private

    def calcul_brut
      if @nb_enfants <= 3
        b = BAREME[@nb_enfants]
        b[:fixe] + (@tib * b[:taux])
      else
        base = BAREME[3]
        extra_count = @nb_enfants - 3
        fixe = base[:fixe] + (EXTRA_PAR_ENFANT[:fixe] * extra_count)
        taux = base[:taux] + (EXTRA_PAR_ENFANT[:taux] * extra_count)
        fixe + (@tib * taux)
      end
    end

    def apply_plancher(montant)
      [montant, plancher_for(@nb_enfants)].max
    end

    def apply_plafond(montant)
      [montant, @tib].min
    end

    def apply_garde_alternee(montant)
      @garde_alternee ? (montant / 2).round(2) : montant
    end

    def plancher_for(nb)
      if nb <= 3
        BAREME[nb][:plancher]
      else
        extra_count = nb - 3
        BAREME[3][:plancher] + (EXTRA_PAR_ENFANT[:plancher] * extra_count)
      end
    end
  end
end
