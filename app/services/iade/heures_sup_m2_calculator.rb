# frozen_string_literal: true

module Iade
  # Heures supplémentaires + heures de greffe/transplantation, activité de M-2 (payées M+2).
  #
  # Contingent mensuel de 20h : les heures cumulées (nuit, puis dimanche, puis jours fériés,
  # puis jour, dans cet ordre) sont payées au tarif IHTS de leur catégorie tant que le
  # contingent n'est pas épuisé (code IT7). Au-delà de 20h cumulées, les heures restantes
  # sont payées à un tarif réduit de 0,25 × base horaire (code DHN).
  #
  # TP7 (greffe/transplantation de nuit) et TP8 (greffe/transplantation dimanche/JF) sont
  # payées respectivement au tarif nuit et au tarif dimanche/JF, sans plafond de contingent.
  class HeuresSupM2Calculator
    CONTINGENT_MENSUEL = BigDecimal("20")

    CATEGORIES = %i[nuit dimanche ferie jour].freeze
    CATEGORIE_TAUX_HS = { nuit: :nuit, dimanche: :dim_jf, ferie: :dim_jf, jour: :jour }.freeze

    def initialize(tib_mensuel:, ir_mensuel: 0, hs_m2_nuit: 0, hs_m2_dimanche: 0, hs_m2_ferie: 0, hs_m2_jour: 0,
                   tp7_heures: 0, tp8_heures: 0)
      @heures = { nuit: hs_m2_nuit, dimanche: hs_m2_dimanche, ferie: hs_m2_ferie, jour: hs_m2_jour }
                .transform_values { |v| BigDecimal(v.to_s) }
      @tp7_heures = BigDecimal(tp7_heures.to_s)
      @tp8_heures = BigDecimal(tp8_heures.to_s)

      # Taux horaires tronqués au multiple inférieur de 0,02 € (règle moteur AP-HP)
      @taux = {
        jour: PlanningCalculator.taux_hs(:jour, tib_mensuel: tib_mensuel, ir_mensuel: ir_mensuel),
        nuit: PlanningCalculator.taux_hs(:nuit, tib_mensuel: tib_mensuel, ir_mensuel: ir_mensuel),
        dim_jf: PlanningCalculator.taux_hs(:dim_jf, tib_mensuel: tib_mensuel, ir_mensuel: ir_mensuel),
        dhn: PlanningCalculator.taux_hs(:dhn, tib_mensuel: tib_mensuel, ir_mensuel: ir_mensuel)
      }
    end

    def compute
      lines = heures_sup_lines + greffe_lines
      { lines: lines, total: lines.sum { |l| l[:montant] }.round(2) }
    end

    private

    def heures_sup_lines # rubocop:disable Metrics/MethodLength
      contingent_restant = CONTINGENT_MENSUEL
      it7_montant = BigDecimal("0")
      dhn_montant = BigDecimal("0")
      it7_detail  = []
      dhn_detail  = []

      CATEGORIES.each do |cat|
        h = @heures[cat]
        next if h.zero?

        h_it7 = [h, contingent_restant].min
        h_dhn = h - h_it7
        contingent_restant -= h_it7

        if h_it7.positive?
          it7_montant += @taux[CATEGORIE_TAUX_HS[cat]] * h_it7
          it7_detail << "#{cat} #{h_it7}h"
        end
        next unless h_dhn.positive?

        dhn_montant += @taux[:dhn] * h_dhn
        dhn_detail << "#{cat} #{h_dhn}h"
      end

      [
        (it7_line(it7_montant, it7_detail) if it7_montant.positive?),
        (dhn_line(dhn_montant, dhn_detail) if dhn_montant.positive?)
      ].compact
    end

    def it7_line(montant, detail)
      { code: "IT7", label: "H. SUP. CONTINGENT 20H (M-2)", montant: montant.round(2), detail: detail.join(" + ") }
    end

    def dhn_line(montant, detail)
      { code: "DHN", label: "H. SUP. HORS CONTINGENT (M-2)", montant: montant.round(2), detail: detail.join(" + ") }
    end

    def greffe_lines
      [
        (tp7_line if @tp7_heures.positive?),
        (tp8_line if @tp8_heures.positive?)
      ].compact
    end

    def tp7_line
      montant = (@taux[:nuit] * @tp7_heures).round(2)
      { code: "TP7", label: "GREFFE/TRANSPLANT. NUIT (M-2)", montant: montant, detail: "#{@tp7_heures}h × tarif nuit" }
    end

    def tp8_line
      montant = (@taux[:dim_jf] * @tp8_heures).round(2)
      { code: "TP8", label: "GREFFE/TRANSPLANT. DIM./FÉRIÉS (M-2)", montant: montant,
        detail: "#{@tp8_heures}h × tarif dim./fériés" }
    end
  end
end
