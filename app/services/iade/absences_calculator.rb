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
      "07E" => "RET. IND. SUJ. 10%",
      "30K" => "RET. IND.SP.NBI CAR",
      "50C" => "RET. TR. BRUT 50%",
      "50L" => "RET. IND. SP. 50%",
      "DTR" => "RET. IND. COMP.",
      "CL5" => "RET. TR. BRUT 50% (CLM/CLD)",
      "CL5I" => "RET. I.A./I.R. 50% (CLM/CLD)",
      "CLR" => "RET. PRIMES (CLM/CLD)",
      "CLRN" => "RET. N.B.I. (CLM/CLD)",
      "ANR" => "ABSENCE NON REMUNEREE"
    }.freeze

    def initialize(params:, tib:, cti:, ir:, nbi:, ir_nbi:, iss:, veil:, iade:, dtc:, ks1: BigDecimal("0"),
                   brut_total: BigDecimal("0"), jours_calendaires: 30)
      @jours_carence      = params[:jours_carence].to_i
      @jours_cmo90        = params[:jours_cmo90].to_i
      @jours_cmo50        = params[:jours_cmo50].to_i
      @jours_clm_cld_plein = params[:jours_clm_cld_plein].to_i
      @jours_clm_cld_demi  = params[:jours_clm_cld_demi].to_i
      @jours_anr           = params[:jours_anr].to_i
      @tib = tib; @cti = cti; @ir = ir
      @nbi = nbi; @ir_nbi = ir_nbi
      @iss = iss; @veil = veil; @iade = iade
      @dtc = dtc; @ks1 = ks1
      @brut_total = brut_total
      @jours_calendaires = jours_calendaires.to_i.positive? ? jours_calendaires.to_i : 30
    end

    def any?
      @jours_carence.positive? || @jours_cmo90.positive? || @jours_cmo50.positive? ||
        @jours_clm_cld_plein.positive? || @jours_clm_cld_demi.positive? || @jours_anr.positive?
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
          lines << ret("30K", @ks1    * j / 30, "#{@jours_carence}j × KS1") if @ks1.positive?
        end
      end

      # ── CMO 90% (retenue 10% du traitement par jour) ────────────
      if @jours_cmo90.positive?
        j = BigDecimal(@jours_cmo90.to_s)
        lines << ret("07C", (@tib + @cti) * j / 30 * BigDecimal("0.10"), "#{@jours_cmo90}j × 10%")
        lines << ret("07L", (@iss + @veil + @iade) * j / 30 * BigDecimal("0.10"), "#{@jours_cmo90}j × 10%")
        if @nbi.positive?
          lines << ret("07A", @nbi * j / 30 * BigDecimal("0.10"), "#{@jours_cmo90}j × 10%")
          lines << ret("07E", @ks1 * j / 30 * BigDecimal("0.10"), "#{@jours_cmo90}j × 10% × KS1") if @ks1.positive?
        end
      end

      # ── CMO 50% (retenue 50% du traitement par jour) ────────────
      if @jours_cmo50.positive?
        j = BigDecimal(@jours_cmo50.to_s)
        lines << ret("50C", (@tib + @cti) * j / 30 * BigDecimal("0.50"), "#{@jours_cmo50}j × 50%")
        lines << ret("50L", (@iss + @veil + @iade) * j / 30 * BigDecimal("0.50"), "#{@jours_cmo50}j × 50%")
      end

      # ── CLM/CLD : primes coupées à 100% sur toute la durée, TIB/IR maintenus à
      # 100% en 1ère période puis retenus à 50% au-delà (pas de jour de carence) ──
      jours_clm_cld = @jours_clm_cld_plein + @jours_clm_cld_demi
      if jours_clm_cld.positive?
        j = BigDecimal(jours_clm_cld.to_s)
        lines << ret("CLR", (@iss + @veil + @iade) * j / 30, "#{jours_clm_cld}j × primes coupées")
        lines << ret("CLRN", @nbi * j / 30, "#{jours_clm_cld}j × NBI coupée") if @nbi.positive?
      end
      if @jours_clm_cld_demi.positive?
        jd = BigDecimal(@jours_clm_cld_demi.to_s)
        lines << ret("CL5", (@tib + @cti) * jd / 30 * BigDecimal("0.50"), "#{@jours_clm_cld_demi}j × 50%")
        lines << ret("CL5I", @ir * jd / 30 * BigDecimal("0.50"), "#{@jours_clm_cld_demi}j × 50% × IR")
      end

      # ── ANR : retenue intégrale sur la rémunération brute totale ─────────────
      # Retenue = (rémunération brute mensuelle / jours calendaires du mois) × jours d'absence
      if @jours_anr.positive?
        ja = BigDecimal(@jours_anr.to_s)
        lines << ret("ANR", @brut_total * ja / @jours_calendaires,
                     "#{@jours_anr}j × brut / #{@jours_calendaires}j calendaires")
      end

      # ── DTR : retenue DTC = DTC × 10% × nb_jours / 30 ─────────
      if @dtc.positive? && any?
        total_jours = BigDecimal((@jours_carence + @jours_cmo90 + @jours_cmo50).to_s)
        lines << ret("DTR", @dtc * BigDecimal("0.10") * total_jours / 30,
                     "DTC × 10% × #{total_jours.to_i}j / 30")
      end

      lines.select { |l| l[:montant].positive? }
    end

    private

    def ret(code, montant, detail)
      { code: code, label: CODES[code], montant: montant.to_d.round(2), detail: detail }
    end
  end
end
