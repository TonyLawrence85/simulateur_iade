# frozen_string_literal: true

module Iade
  # Calcule les retenues absence AP-HP selon le bulletin de référence (§4.2 du cahier paramètres).
  # Formules confirmées par bulletin observé IADE AP-HP.
  class AbsencesCalculator
    CODES = {
      "07C" => "RET. TR. BRUT 10%",
      "30A" => "RET. TR. BRUT CAR.",
      "30B" => "RET. I.A./I.R. CAR",
      "07A" => "RET. N.B.I. 10%",
      "30G" => "RET. N.B.I. CAR.",
      "30F" => "RET. NBI IR/IA CAR",
      "07L" => "RET. IND. SP. 10%",
      "50C" => "RET. TR. BRUT 50%",
      "50L" => "RET. IND. SP. 50%",
      "DTR" => "RET. IND. COMP."
    }.freeze

    def initialize(params:, tib:, cti:, ir:, nbi:, ir_nbi:, iss:, veil:, iade:, dtc:)
      @jours_carence = params[:jours_carence].to_i
      @jours_cmo90   = params[:jours_cmo90].to_i
      @jours_cmo50   = params[:jours_cmo50].to_i
      @tib = tib; @cti = cti; @ir = ir
      @nbi = nbi; @ir_nbi = ir_nbi
      @iss = iss; @veil = veil; @iade = iade
      @dtc = dtc
    end

    def any?
      @jours_carence.positive? || @jours_cmo90.positive? || @jours_cmo50.positive?
    end

    def retenues # rubocop:disable Metrics/MethodLength
      lines = []

      # ── Carence (100% de retenue par jour) ──────────────────────
      if @jours_carence.positive?
        j = BigDecimal(@jours_carence.to_s)
        lines << ret("30A", (@tib + @cti) * j / 30, "#{@jours_carence}j")
        lines << ret("30B", @ir              * j / 30, "#{@jours_carence}j × IR")
        if @nbi.positive?
          lines << ret("30G", @nbi    * j / 30, "#{@jours_carence}j × NBI")
          lines << ret("30F", @ir_nbi * j / 30, "#{@jours_carence}j × IR NBI")
        end
      end

      # ── CMO 90% (retenue 10% du traitement par jour) ────────────
      if @jours_cmo90.positive?
        j = BigDecimal(@jours_cmo90.to_s)
        lines << ret("07C", (@tib + @cti) * j / 30 * BigDecimal("0.10"), "#{@jours_cmo90}j × 10%")
        lines << ret("07L", (@iss + @veil + @iade) * j / 30 * BigDecimal("0.10"), "#{@jours_cmo90}j × 10%")
        lines << ret("07A", @nbi * j / 30 * BigDecimal("0.10"), "#{@jours_cmo90}j × 10%") if @nbi.positive?
      end

      # ── CMO 50% (retenue 50% du traitement par jour) ────────────
      if @jours_cmo50.positive?
        j = BigDecimal(@jours_cmo50.to_s)
        lines << ret("50C", (@tib + @cti) * j / 30 * BigDecimal("0.50"), "#{@jours_cmo50}j × 50%")
        lines << ret("50L", (@iss + @veil + @iade) * j / 30 * BigDecimal("0.50"), "#{@jours_cmo50}j × 50%")
      end

      # ── DTR : retenue DTC proportionnelle ───────────────────────
      if @dtc.positive? && any?
        proportion = BigDecimal("0")
        proportion += BigDecimal(@jours_carence.to_s) / 30 if @jours_carence.positive?
        proportion += BigDecimal(@jours_cmo90.to_s) / 30 * BigDecimal("0.10") if @jours_cmo90.positive?
        proportion += BigDecimal(@jours_cmo50.to_s) / 30 * BigDecimal("0.50") if @jours_cmo50.positive?
        lines << ret("DTR", @dtc * proportion, "DTC × proportion absence")
      end

      lines.select { |l| l[:montant].positive? }
    end

    private

    def ret(code, montant, detail)
      { code: code, label: CODES[code], montant: montant.to_d.round(2), detail: detail }
    end
  end
end
