# frozen_string_literal: true

module Iade
  class PayslipCalculator # rubocop:disable Metrics/ClassLength
    Result = Struct.new(:lines, :brut_total, :cotisations_total, :net_social,
                        :net_avant_pas, :net_paye, :errors, :warnings, keyword_init: true)

    REQUIRED = %i[mois_paie statut grade echelon quotite departement_code
                  nb_enfants_sft nbi_points taux_pas].freeze

    def self.call(params)
      new(params).call
    end

    def initialize(params)
      @p = params.with_indifferent_access
      @lines    = []
      @errors   = []
      @warnings = []
    end

    def call # rubocop:disable Metrics/MethodLength
      validate_required_params
      return failure_result if @errors.any?

      build_brut_lines
      compute_brut_total
      build_deduction_lines
      compute_totals

      Result.new(
        lines: @lines, brut_total: @brut_total, cotisations_total: @cotisations_total,
        net_social: @net_social, net_avant_pas: @net_avant_pas, net_paye: @net_paye,
        errors: @errors, warnings: @warnings
      )
    end

    private

    def validate_required_params
      REQUIRED.each { |key| @errors << "Paramètre manquant : #{key}" if @p[key].nil? }
    end

    # ---------------- BRUT ----------------

    def build_brut_lines # rubocop:disable Metrics/MethodLength
      add_tib
      add_cti
      add_prime_veil
      add_prime_iade
      add_indemnite_residence   # → @ir_montant, @ir_taux
      add_nbi
      add_ir_nbi                # → @ir_nbi_montant
      add_sft
      add_sft_nbi               # KS0 + KS1 (nécessite @ir_nbi_montant)
      add_iss                   # IS1 calculé automatiquement
      add_abattement_ppcr       # IBA (déduction PPCR, réduit le brut et l'assiette RAFP)
      add_dtc
      add_wt1
      add_jma
      add_dim_jf
      add_tp7_it7_dhn
      add_heures_sup
      add_gardes
      add_psr
      add_lsu
    end

    def add_tib
      tib = tib_calculator.compute
      add_line(code: "BT0", label: "TR. MENS. REEL (TIB)", category: :fixe_calc, montant: tib,
               detail: "IM #{tib_calculator.indice_majore} × #{Iade::TibCalculator::VALEUR_POINT} × #{quotite_pct}")
    end

    def add_cti
      @cti_montant = Iade::AutoPrimesCalculator.cti(quotite)
      add_line(code: "CW1", label: "COMPL. TRAITEMENT (CTI/Ségur)", category: :auto,
               montant: @cti_montant,
               detail: "#{Iade::AutoPrimesCalculator::CTI_POINTS} pts × valeur_point × #{quotite_pct}")
    end

    def add_prime_veil
      add_line(code: "LP1", label: "PRIME INFIRMIERE (Veil)", category: :auto,
               montant: Iade::AutoPrimesCalculator.prime_veil(quotite),
               detail: "90,00 € × #{quotite_pct}")
    end

    def add_prime_iade
      add_line(code: "LPN", label: "PRIME SP INF ANEST (IADE)", category: :auto,
               montant: Iade::AutoPrimesCalculator.prime_iade(quotite), detail: "180,00 € × #{quotite_pct}")
    end

    def add_indemnite_residence
      ir = Iade::IrCalculator.new(tib: tib_montant, departement_code: @p[:departement_code]).compute
      @ir_montant = ir[:montant]
      @ir_zone    = ir[:zone]
      add_line(code: "BR0", label: "IND. DE RESIDENCE", category: :fixe_calc,
               montant: @ir_montant, detail: "Zone #{ir[:zone]} (#{ir[:taux_pct]}%)")
    end

    def add_nbi
      return if nbi_points.zero?

      montant = Iade::NbiCalculator.new(points: nbi_points).montant
      add_line(code: "KB1", label: "BONIFICATION IND. (NBI)", category: :fixe_calc,
               montant: montant, detail: "#{nbi_points} pts")
    end

    def add_ir_nbi
      return if nbi_points.zero?

      nbi_m = Iade::NbiCalculator.new(points: nbi_points).montant
      ir_nbi = Iade::IrCalculator.new(tib: nbi_m, departement_code: @p[:departement_code]).compute
      @ir_nbi_montant = ir_nbi[:montant]
      add_line(code: "KR0", label: "IND. RESID. N.B.I.", category: :fixe_calc,
               montant: @ir_nbi_montant, detail: "IR sur NBI")
    end

    def add_sft
      sft = Iade::SftCalculator.new(nb_enfants: nb_enfants, tib: tib_montant,
                                    garde_alternee: @p[:garde_alternee]).compute
      add_line(code: "CS0", label: "S.F.T. PERCU", category: :fixe_calc,
               montant: sft, detail: "#{nb_enfants} enfant(s)")
    end

    def add_sft_nbi # rubocop:disable Metrics/MethodLength
      return if nbi_points.zero? || nb_enfants.zero?

      nbi_m  = Iade::NbiCalculator.new(points: nbi_points).montant
      ir_nbi = @ir_nbi_montant || BigDecimal("0")
      taux   = sft_taux_nbi

      if taux.positive?
        ks0 = (nbi_m * taux).round(2)
        add_line(code: "KS0", label: "S.F.T. N.B.I.", category: :fixe_calc,
                 montant: ks0, detail: "#{(taux * 100).to_f.to_i}% × NBI")
      end

      ks1 = (BigDecimal("13") / BigDecimal("1900") * 12 * (nbi_m + ir_nbi)).round(2)
      add_line(code: "KS1", label: "ISS N.B.I.", category: :fixe_calc,
               montant: ks1, detail: "13/1900 × 12 × (NBI + IR_NBI)")
    end

    def add_iss
      override = @p[:iss_montant].to_f
      if override.positive?
        add_line(code: "IS1", label: "IND. SPEC.SUJETION (ISS)", category: :profile,
                 montant: BigDecimal(override.to_s), detail: "Saisie manuelle")
      else
        add_line(code: "IS1", label: "IND. SPEC.SUJETION (ISS)", category: :fixe_calc,
                 montant: iss_auto_montant, detail: "13/1900 × 12 × (TIB + IR)")
      end
    end

    def iss_auto_montant
      ir = @ir_montant || BigDecimal("0")
      (BigDecimal("13") / BigDecimal("1900") * 12 * (tib_montant + ir)).round(2)
    end

    def add_abattement_ppcr
      return if @p[:statut] == "contractuel"

      @iba_montant = (BigDecimal("389") * quotite / 12).round(2)
      add_line(code: "IBA", label: "ABAT.PPCR.CAT A", category: :auto,
               montant: -@iba_montant, detail: "389 € × #{quotite_pct} / 12")
    end

    def add_dtc
      return if @p[:dtc_montant].blank? || @p[:dtc_montant].to_f.zero?

      add_line(code: "DTC", label: "IND COMP CSG", category: :profile,
               montant: BigDecimal(@p[:dtc_montant].to_s), detail: "Profil bulletin")
    end

    def add_wt1
      return if @p[:wt1_montant].blank? || @p[:wt1_montant].to_f.zero?

      add_line(code: "WT1", label: "REMBOUR. TRANSPORT", category: :profile,
               montant: BigDecimal(@p[:wt1_montant].to_s), detail: "75% abonnement")
    end

    def add_jma
      heures = @p[:heures_nuit].to_f
      return if heures.zero?

      montant = Iade::PlanningCalculator.indemnite_nuit(
        heures: heures, tib_mensuel: tib_montant, ir_mensuel: @ir_montant || 0
      )
      add_line(code: "JMA", label: "IND. NUIT MAJOREE", category: :var_m1,
               montant: montant, detail: "#{heures}h × 25% × base horaire (TIB+IR)", pay_lag: :mois_m1)
    end

    def add_dim_jf
      h_dim   = @p[:heures_dimanche].to_f
      h_ferie = @p[:heures_ferie].to_f
      return if h_dim.zero? && h_ferie.zero?

      montant = Iade::PlanningCalculator.dimanche_ferie(heures_dim: h_dim, heures_ferie: h_ferie)
      add_line(code: "JW0", label: "IND. DIM. & JOURS FERIES", category: :var_m1,
               montant: montant, detail: "#{h_dim + h_ferie}h × 7,50 €/h (M-1)", pay_lag: :mois_m1)
      @warnings << "JW0 : vérifier que vous avez saisi l'activité de M-1" if montant.positive?
    end

    def add_tp7_it7_dhn # rubocop:disable Metrics/MethodLength
      tp7 = @p[:tp7_qty].to_i
      it7 = @p[:it7_qty].to_i
      dhn = @p[:dhn_heures].to_f
      return if tp7.zero? && it7.zero? && dhn.zero?

      montant = Iade::PlanningCalculator.rappels_m2(
        tp7_qty: tp7, it7_qty: it7, dhn_heures: dhn,
        tib_mensuel: tib_montant, ir_mensuel: @ir_montant || 0
      )
      add_line(code: "TP7/IT7/DHN", label: "RAPPELS TP7/IT7/DHN", category: :var_m2,
               montant: montant, detail: "Activité M-2", pay_lag: :mois_m2)
      @warnings << "TP7/IT7/DHN : vérifier l'activité de M-2" if montant.positive?
    end

    def add_heures_sup # rubocop:disable Metrics/MethodLength
      result = Iade::HeuresSupCalculator.new(
        tib_mensuel: tib_montant,
        ir_mensuel: @ir_montant || 0,
        hs_jour: @p[:hs_jour].to_f,
        hs_nuit: @p[:hs_nuit].to_f,
        hs_dim_jf: @p[:hs_dim_jf].to_f
      ).compute
      return if result[:total].zero?

      result[:lines].each do |hs|
        add_line(code: hs[:code], label: hs[:label], category: :var_m, montant: hs[:montant], detail: hs[:detail])
      end
    end

    def add_gardes
      nb = @p[:nb_gardes].to_f
      return if nb.zero?

      heures_equiv = (@p[:heures_par_garde].presence&.to_f || 4.0)
      taux = taux_hs_nuit
      montant = (nb * heures_equiv * taux).round(2)
      add_line(code: "GAR", label: "GARDES (éq. HS nuit)", category: :var_m2,
               montant: BigDecimal(montant.to_s),
               detail: "#{nb.to_i} garde(s) × #{heures_equiv.to_i}h × #{taux}€/h (M−2)", pay_lag: :mois_m2)
    end

    def add_psr
      montant_ref = @p[:montant_psr].to_f
      return if montant_ref.zero?

      jours = @p[:jours_absence_psr].to_i
      perte = jours.positive? ? (montant_ref * jours / 140.0).round(2) : 0.0
      montant = [montant_ref - perte, 0.0].max
      detail = jours.positive? ? "#{montant_ref}€ − abatt. #{jours}j/140 (−#{perte}€)" : "Montant saisi"
      add_line(code: "PSR", label: "PRIME DE SERVICE", category: :prime_variable,
               montant: BigDecimal(montant.to_s), detail: detail)
    end

    def add_lsu
      montant = @p[:montant_lsu].to_f
      return if montant.zero?

      add_line(code: "LSU", label: "INDEM. EXCEP.", category: :prime_variable,
               montant: BigDecimal(montant.to_s), detail: "Montant saisi")
    end

    def add_retenues_absence
      return unless absence_jours?

      calc = Iade::AbsencesCalculator.new(**absence_calc_args)
      calc.retenues.each do |r|
        add_deduction(code: r[:code], label: r[:label], montant: r[:montant], detail: r[:detail])
      end
    end

    def absence_jours?
      @p[:jours_carence].to_i.positive? ||
        @p[:jours_cmo90].to_i.positive? ||
        @p[:jours_cmo50].to_i.positive?
    end

    def absence_calc_args
      { params: @p,
        tib: line_montant("BT0"), cti: line_montant("CW1"),
        ir: line_montant("BR0"), nbi: line_montant("KB1"),
        ir_nbi: line_montant("KR0"), ks1: line_montant("KS1"),
        iss: line_montant("IS1"), veil: line_montant("LP1"),
        iade: line_montant("LPN"), dtc: line_montant("DTC") }
    end

    # ---------------- DÉDUCTIONS ----------------

    def add_retraite_principale
      case @p[:statut]
      when "contractuel"
        add_retraite_ircantec
      else
        add_retraite_cnracl
      end
    end

    def add_retraite_cnracl # rubocop:disable Metrics/MethodLength
      assiette_cnracl = tib_montant + (@cti_montant || Iade::AutoPrimesCalculator.cti(quotite))

      add_deduction(code: "RCN", label: "CNRACL RETRAITE",
                    montant: Iade::CotisationsCalculator.cnracl(assiette: assiette_cnracl),
                    detail: "11,10% × (TIB + CTI)")

      if nbi_points.positive?
        nbi_m = Iade::NbiCalculator.new(points: nbi_points).montant
        add_deduction(code: "RCB", label: "CNRACL – N.B.I.",
                      montant: Iade::CotisationsCalculator.cnracl(assiette: nbi_m), detail: "11,10% × NBI")
      end

      rafp = Iade::CotisationsCalculator.rafp(
        assiette_primes: brut_primes_total,
        tib_annuel: tib_montant * 12
      )
      @rafp_montant = rafp
      add_deduction(code: "RAF", label: "RETRAITE ADD.TITU. (RAFP)",
                    montant: rafp, detail: "5% plafonné à 20% du TIB annuel")
    end

    def add_retraite_ircantec
      assiette = tib_montant + (@cti_montant || Iade::AutoPrimesCalculator.cti(quotite)) + brut_primes_total
      add_deduction(code: "RET", label: "RETRAITE IRCANTEC",
                    montant: Iade::CotisationsCalculator.ircantec(assiette: assiette),
                    detail: "4,01% tranche A (contractuel)")
    end

    def build_deduction_lines # rubocop:disable Metrics/MethodLength
      add_retenues_absence
      add_retraite_principale

      base_csg = Iade::CotisationsCalculator.base_csg(brut_total: @brut_lines_total)

      add_deduction(code: "UCB", label: "C.S.G. ET R.D.S.",
                    montant: Iade::CotisationsCalculator.csg_crds(base_csg: base_csg), detail: "2,90%")

      add_deduction(code: "UCX", label: "CSG MALADIE TITUL.",
                    montant: Iade::CotisationsCalculator.csg_maladie(base_csg: base_csg), detail: "6,80%")

      hs_total = hs_montant_total
      if hs_total.positive?
        add_deduction(code: "UC8", label: "CSG SUR TTA OU HS",
                      montant: Iade::CotisationsCalculator.csg_hs(assiette_hs: hs_total), detail: "6,80%")
        add_deduction(code: "VR7", label: "REDUC COTIS SUR HS",
                      montant: -(@rafp_montant || BigDecimal("0")), detail: "Réduction (= RAFP)")
      end

      pas = Iade::CotisationsCalculator.pas(
        base_imposable: base_imposable_mensuelle,
        taux: BigDecimal(@p[:taux_pas].to_s) / 100
      )
      add_deduction(code: "Q60", label: "MT PAS TAUX PERS", montant: pas, detail: "#{@p[:taux_pas]}%")
    end

    # ---------------- TOTAUX ----------------

    def compute_brut_total
      @brut_lines_total = @lines.reject { |l| l[:type] == :deduction }.sum { |l| l[:montant] }
    end

    def compute_totals
      deduct_lines = @lines.select { |l| l[:type] == :deduction }

      @brut_total        = @brut_lines_total
      @cotisations_total = deduct_lines.sum { |l| l[:montant] }
      @net_social        = @brut_total - @cotisations_total

      pas_montant = deduct_lines.find { |l| l[:code] == "Q60" }&.dig(:montant) || BigDecimal("0")
      mutuelle    = BigDecimal(@p[:mutuelle].to_s.presence || "0")
      @net_avant_pas = @brut_total - (@cotisations_total - pas_montant)
      @net_paye      = @net_avant_pas - pas_montant - mutuelle
    end

    # ---------------- HELPERS ----------------

    def add_line(code:, label:, category:, montant:, detail: nil, pay_lag: nil) # rubocop:disable Metrics/ParameterLists
      @lines << { code: code, label: label, category: category, montant: montant.to_d.round(2),
                  detail: detail, pay_lag: pay_lag, type: :brut }
    end

    def add_deduction(code:, label:, montant:, detail: nil)
      @lines << { code: code, label: label, category: :deduction, montant: montant.to_d.round(2),
                  detail: detail, type: :deduction }
    end

    def line_montant(code)
      @lines.find { |l| l[:code] == code }&.dig(:montant) || BigDecimal("0")
    end

    def tib_calculator
      @tib_calculator ||= Iade::TibCalculator.new(grade: @p[:grade], echelon: @p[:echelon].to_i, quotite: quotite)
    end

    def tib_montant
      @tib_montant ||= tib_calculator.compute
    end

    def quotite
      @quotite ||= BigDecimal(@p[:quotite].to_s)
    end

    def quotite_pct
      "#{(quotite * 100).to_i}%"
    end

    def nbi_points
      @nbi_points ||= @p[:nbi_points].to_i
    end

    def nb_enfants
      @nb_enfants ||= @p[:nb_enfants_sft].to_i
    end

    def sft_taux_nbi
      case nb_enfants
      when 0, 1 then BigDecimal("0")
      when 2    then BigDecimal("0.03")
      when 3    then BigDecimal("0.08")
      else           BigDecimal("0.08") + ((nb_enfants - 3) * BigDecimal("0.06"))
      end
    end

    def brut_primes_total
      # IBA (négatif) réduit l'assiette RAFP ; PSR/LSU soumis RAFP selon plafond (PDF §8)
      codes = %w[CW1 LP1 LPN IS1 JMA JW0 TP7/IT7/DHN IBA PSR LSU]
      total = @lines.select { |l| codes.include?(l[:code]) && l[:type] == :brut }.sum { |l| l[:montant] }
      [total, BigDecimal("0")].max
    end

    def hs_montant_total
      # GAR = gardes équivalent HS nuit → même régime UC8/VR7
      @lines.select { |l| l[:type] == :brut }
            .select { |l| l[:code].start_with?("HS") || l[:code] == "GAR" }
            .sum { |l| l[:montant] }
    end

    def taux_hs_nuit
      base_horaire = (tib_montant + (@ir_montant || BigDecimal("0"))) * 12 / BigDecimal("1820")
      (base_horaire * BigDecimal("1.26") * 2).round(2)
    end

    def base_imposable_mensuelle
      deductions_so_far = @lines.select { |l| l[:type] == :deduction }.sum { |l| l[:montant] }
      @brut_lines_total - deductions_so_far
    end

    def failure_result
      Result.new(lines: [], brut_total: BigDecimal("0"), cotisations_total: BigDecimal("0"),
                 net_social: BigDecimal("0"), net_avant_pas: BigDecimal("0"),
                 net_paye: BigDecimal("0"), errors: @errors, warnings: [])
    end
  end
end
