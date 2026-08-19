# frozen_string_literal: true

module Iade
  # Heures supplémentaires + heures de greffe/transplantation, activité de M-2 (payées M+2).
  #
  # Règle IT7/DHN (fiche corrective codeur du 17/08/2026) : DHN n'est pas un deuxième type
  # d'heure sup de nuit, c'est la partie des heures sup de NUIT située au-delà du plafond de
  # 20h porté par IT7. Un seul champ de saisie (heures sup de nuit, gardes incluses — 1 garde
  # = 4h de nuit) ; le moteur répartit automatiquement :
  #   IT7 = min(HS_nuit_total, 20) × taux_HS_nuit
  #   DHN = max(HS_nuit_total - 20, 0) × taux_HS_nuit   (même taux qu'IT7, pas de taux réduit)
  #
  # Les heures sup de jour et de dimanche/jours fériés ne partagent PAS ce contingent : elles
  # sont payées directement à leur propre tarif IHTS, sans plafond ni répartition.
  #
  # TP7 (greffe/transplantation de nuit) et TP8 (greffe/transplantation dimanche/JF) sont
  # payées respectivement au tarif nuit et au tarif dimanche/JF, sans plafond de contingent.
  class HeuresSupM2Calculator
    CONTINGENT_MENSUEL = BigDecimal("20")

    def initialize(tib_mensuel:, ir_mensuel: 0, hs_m2_nuit: 0, hs_m2_dimanche: 0, hs_m2_ferie: 0, hs_m2_jour: 0,
                   garde_heures: 0, tp7_heures: 0, tp8_heures: 0)
      @hs_nuit_total = BigDecimal(hs_m2_nuit.to_s) + BigDecimal(garde_heures.to_s)
      @hs_dimanche   = BigDecimal(hs_m2_dimanche.to_s)
      @hs_ferie      = BigDecimal(hs_m2_ferie.to_s)
      @hs_jour       = BigDecimal(hs_m2_jour.to_s)
      @tp7_heures    = BigDecimal(tp7_heures.to_s)
      @tp8_heures    = BigDecimal(tp8_heures.to_s)

      # Taux horaires tronqués au multiple inférieur de 0,02 € (règle moteur AP-HP)
      @taux = {
        jour: PlanningCalculator.taux_hs(:jour, tib_mensuel: tib_mensuel, ir_mensuel: ir_mensuel),
        nuit: PlanningCalculator.taux_hs(:nuit, tib_mensuel: tib_mensuel, ir_mensuel: ir_mensuel),
        dim_jf: PlanningCalculator.taux_hs(:dim_jf, tib_mensuel: tib_mensuel, ir_mensuel: ir_mensuel)
      }
    end

    def compute
      lines = heures_sup_nuit_lines + heures_sup_autres_lines + greffe_lines
      { lines: lines, total: lines.sum { |l| l[:montant] }.round(2) }
    end

    private

    def heures_sup_nuit_lines
      it7_h = [@hs_nuit_total, CONTINGENT_MENSUEL].min
      dhn_h = [@hs_nuit_total - CONTINGENT_MENSUEL, BigDecimal("0")].max

      [
        (it7_line(it7_h) if it7_h.positive?),
        (dhn_line(dhn_h) if dhn_h.positive?)
      ].compact
    end

    def it7_line(heures)
      { code: "IT7", label: "H. SUP. NUIT — CONTINGENT 20H (M-2)", montant: (@taux[:nuit] * heures).round(2),
        detail: "#{heures}h × #{@taux[:nuit]}€/h" }
    end

    def dhn_line(heures)
      { code: "DHN", label: "H. SUP. NUIT — HORS CONTINGENT (M-2)", montant: (@taux[:nuit] * heures).round(2),
        detail: "#{heures}h × #{@taux[:nuit]}€/h (même taux qu'IT7)" }
    end

    def heures_sup_autres_lines
      [
        (jour_line if @hs_jour.positive?),
        (dim_ferie_line if (@hs_dimanche + @hs_ferie).positive?)
      ].compact
    end

    def jour_line
      { code: "IT5", label: "H. SUP. JOUR (M-2)", montant: (@taux[:jour] * @hs_jour).round(2),
        detail: "#{@hs_jour}h × #{@taux[:jour]}€/h" }
    end

    def dim_ferie_line
      heures = @hs_dimanche + @hs_ferie
      { code: "IT8", label: "H. SUP. DIM./FÉRIÉS (M-2)", montant: (@taux[:dim_jf] * heures).round(2),
        detail: "#{heures}h × #{@taux[:dim_jf]}€/h" }
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
