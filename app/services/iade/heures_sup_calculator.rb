# frozen_string_literal: true

module Iade
  class HeuresSupCalculator
    # Formules FPH (Décret IHTS) : base = (TIB + IR) × 12 / 1820
    TAUX_JOUR   = BigDecimal("1.26")
    TAUX_NUIT   = BigDecimal("2.52")  # 1.26 × 2
    TAUX_DIM_JF = BigDecimal("2.10")  # 1.26 × (1 + 2/3)

    TYPES = [
      { key: :jour,   code: "HSJOUR",  label: "HS JOUR",        taux: TAUX_JOUR },
      { key: :nuit,   code: "HSNUIT",  label: "HS NUIT",        taux: TAUX_NUIT },
      { key: :dim_jf, code: "HSDIMJF", label: "HS DIM./FÉRIÉS", taux: TAUX_DIM_JF }
    ].freeze

    def initialize(tib_mensuel:, ir_mensuel: 0, hs_jour: 0, hs_nuit: 0, hs_dim_jf: 0)
      @base   = PlanningCalculator.base_horaire(tib_mensuel: tib_mensuel, ir_mensuel: ir_mensuel)
      @heures = { jour: BigDecimal(hs_jour.to_s), nuit: BigDecimal(hs_nuit.to_s),
                  dim_jf: BigDecimal(hs_dim_jf.to_s) }
    end

    def compute
      lines = TYPES.filter_map { |t| compute_line(t) }
      { lines: lines, total: lines.sum { |l| l[:montant] }.round(2) }
    end

    private

    def compute_line(type)
      heures = @heures[type[:key]]
      return nil if heures.zero?

      montant = (@base * heures * type[:taux]).round(2)
      { code: type[:code], label: type[:label], montant: montant,
        detail: "#{heures}h × #{@base.round(4)} €/h × #{type[:taux]}" }
    end
  end
end
