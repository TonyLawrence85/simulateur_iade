# frozen_string_literal: true

module Iade
  class PayslipComparison
    TOLERANCE_CENTS = BigDecimal("0.05")

    ComparisonLine = Struct.new(:code, :label, :category, :pay_lag,
                                :montant_sim, :montant_real, :delta, :status, :detail,
                                keyword_init: true)

    Result = Struct.new(:lines, :anomalies, :brut_sim, :brut_real, :delta_brut,
                        :net_sim, :net_real, :delta_net, :has_anomalies, keyword_init: true)

    def self.compare(simulated_result:, real_lines: {}, real_totals: {})
      new(simulated_result: simulated_result, real_lines: real_lines, real_totals: real_totals).compare
    end

    def initialize(simulated_result:, real_lines:, real_totals:)
      @sim    = simulated_result
      @real   = real_lines.transform_keys(&:to_s).transform_values { |v| BigDecimal(v.to_s) }
      @totals = real_totals.transform_keys(&:to_sym)
    end

    def compare
      lines     = build_comparison_lines
      anomalies = lines.reject { |l| l.status == :ok }

      brut_real = @totals[:brut] ? BigDecimal(@totals[:brut].to_s) : nil
      net_real  = @totals[:net]  ? BigDecimal(@totals[:net].to_s)  : nil

      Result.new(
        lines: lines, anomalies: anomalies,
        brut_sim: @sim.brut_total, brut_real: brut_real,
        delta_brut: brut_real ? (@sim.brut_total - brut_real).round(2) : nil,
        net_sim: @sim.net_paye, net_real: net_real,
        delta_net: net_real ? (@sim.net_paye - net_real).round(2) : nil,
        has_anomalies: anomalies.any?
      )
    end

    private

    def build_comparison_lines
      all_codes = (@sim.lines.map { |l| l[:code] } + @real.keys).uniq

      all_codes.map do |code|
        sim_line     = @sim.lines.find { |l| l[:code] == code }
        montant_sim  = sim_line ? sim_line[:montant] : nil
        montant_real = @real[code]
        delta  = compute_delta(montant_sim, montant_real)
        status = compute_status(montant_sim, montant_real, delta)

        ComparisonLine.new(
          code: code, label: sim_line&.dig(:label) || code,
          category: sim_line&.dig(:category), pay_lag: sim_line&.dig(:pay_lag),
          montant_sim: montant_sim, montant_real: montant_real,
          delta: delta, status: status, detail: sim_line&.dig(:detail)
        )
      end
    end

    def compute_delta(sim, real)
      return nil if sim.nil? && real.nil?

      ((sim || BigDecimal("0")) - (real || BigDecimal("0"))).round(2)
    end

    def compute_status(sim, real, delta)
      return :missing if sim.present? && real.nil?
      return :extra   if sim.nil?     && real.present?
      return :ok      if delta.nil? || delta.abs <= TOLERANCE_CENTS

      delta.positive? ? :under : :over
    end
  end
end
