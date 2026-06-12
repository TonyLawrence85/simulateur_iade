# frozen_string_literal: true

module Iade
  class PayslipCalculator
    Result = Struct.new(:lines, :brut_total, :cotisations_total, :net_social,
                        :net_avant_pas, :net_paye, :errors, :warnings, keyword_init: true)

    REQUIRED = %i[mois_paie statut grade echelon quotite departement_code
                  nb_enfants_sft nbi_points iss_montant taux_pas].freeze

    def self.call(params)
      new(params).call
    end

    def initialize(params)
      @p = params.with_indifferent_access
      @lines = []
      @errors = []
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

    def build_brut_lines
      add_tib
      add_cti
      add_prime_veil
      add_prime_iade
      add_indemnite_residence
      add_nbi
      add_ir_nbi
      add_sft
      add_iss
      add_dtc
      add_wt1
      add_jma
      add_dim_jf
      add_tp7_it7_dhn
      add_heures_sup
    end

    def add_tib
      tib = tib_calculator.compute
      add_line(code: "BT0", label: "TR. MENS. REEL (TIB)", category: :fixe_calc, montant: tib,
               detail: "IM #{tib_calculator.indice_majore} × #{Iade::TibCalculator::VALEUR_POINT} × #{quotite_pct}")
    end

    def add_cti
      add_line(code: "CW1", label: "COMPL. TRAITEMENT (CTI/Ségur)", category: :auto,
               montant: Iade::AutoPrimesCalculator::CTI_MONTANT, detail: "Montant forfaitaire")
    end

    def add_prime_veil
      add_line(code: "LP1", label: "PRIME INFIRMIERE (Veil)", category: :auto,
               montant: Iade::AutoPrimesCalculator::PRIME_VEIL, detail: "Prime fixe")
    end

    def add_prime_iade
      add_line(code: "LPN", label: "PRIME SP INF ANEST (IADE)", category: :auto,
               montant: Iade::AutoPrimesCalculator.prime_iade(quotite), detail: "Prime × quotité")
    end

    def add_indemnite_residence
      ir = Iade::IrCalculator.new(tib: tib_montant, departement_code: @p[:departement_code]).compute
      add_line(code: "BR0", label: "IND. DE RESIDENCE", category: :fixe_calc,
               montant: ir[:montant], detail: "Zone #{ir[:zone]} (#{ir[:taux_pct]}%)")
      @ir_zone = ir[:zone]
    end

    def add_nbi
      return if nbi_points.zero?

      montant = Iade::NbiCalculator.new(points: nbi_points).montant
      add_line(code: "KB1", label: "BONIFICATION IND. (NBI)", category: :fixe_calc,
               montant: montant, detail: "#{nbi_points} pts")
    end

    def add_ir_nbi
      return if nbi_points.zero?

      nbi_m  = Iade::NbiCalculator.new(points: nbi_points).montant
      ir_nbi = Iade::IrCalculator.new(tib: nbi_m, departement_code: @p[:departement_code]).compute
      add_line(code: "KR0", label: "IND. RESID. N.B.I.", category: :fixe_calc,
               montant: ir_nbi[:montant], detail: "IR sur NBI")
    end

    def add_sft
      sft = Iade::SftCalculator.new(nb_enfants: nb_enfants, tib: tib_montant,
                                    garde_alternee: @p[:garde_alternee]).compute
      add_line(code: "CS0", label: "S.F.T. PERCU", category: :fixe_calc,
               montant: sft, detail: "#{nb_enfants} enfant(s)")
    end

    def add_iss
      montant = BigDecimal(@p[:iss_montant].to_s)
      add_line(code: "IS1", label: "IND. SPEC.SUJETION (ISS)", category: :profile,
               montant: montant, detail: "Profil bulletin")
    end

    def add_dtc
      return if @p[:dtc_montant].blank? || @p[:dtc_montant].to_f.zero?

      add_line(code: "DTC", label: "IND COMP CSG", category: :profile,
               montant: BigDecimal(@p[:dtc_montant].to_s), detail: "Profil bulletin")
    end

    def add_wt1
      return if @p[:wt1_montant].blank? || @p[:wt1_montant].to_f.zero?

      add_line(code: "WT1", label: "REMBOUR. TRANSPORT", category: :profile,
               montant: BigDecimal(@p[:wt1_montant].to_s), detail: "50% abonnement")
    end

    def add_jma
      heures = @p[:heures_nuit].to_f
      return if heures.zero?

      montant = Iade::PlanningCalculator.indemnite_nuit(heures: heures, tib_mensuel: tib_montant)
      add_line(code: "JMA", label: "IND. NUIT MAJOREE", category: :var_m,
               montant: montant, detail: "#{heures}h nuit", pay_lag: :mois_m)
    end

    def add_dim_jf
      h_dim = @p[:heures_dimanche].to_f
      h_ferie = @p[:heures_ferie].to_f
      return if h_dim.zero? && h_ferie.zero?

      montant = Iade::PlanningCalculator.dimanche_ferie(heures_dim: h_dim, heures_ferie: h_ferie,
                                                        tib_mensuel: tib_montant)
      add_line(code: "DIM/JF", label: "IND. DIM. & JOURS FERIES", category: :var_m1,
               montant: montant, detail: "#{h_dim}h dim + #{h_ferie}h fériés (M-1)", pay_lag: :mois_m1)
      @warnings << "DIM/JF : vérifier que vous avez saisi l'activité de M-1" if montant.positive?
    end

    def add_tp7_it7_dhn
      tp7 = @p[:tp7_qty].to_i
      it7 = @p[:it7_qty].to_i
      dhn = @p[:dhn_heures].to_f
      return if tp7.zero? && it7.zero? && dhn.zero?

      montant = Iade::PlanningCalculator.rappels_m2(tp7_qty: tp7, it7_qty: it7, dhn_heures: dhn,
                                                    tib_mensuel: tib_montant)
      add_line(code: "TP7/IT7/DHN", label: "RAPPELS TP7/IT7/DHN", category: :var_m2,
               montant: montant, detail: "Activité M-2", pay_lag: :mois_m2)
      @warnings << "TP7/IT7/DHN : vérifier l'activité de M-2" if montant.positive?
    end

    def add_heures_sup
      result = Iade::HeuresSupCalculator.new(
        hs_jour_25: @p[:hs_jour_25].to_f, hs_jour_50: @p[:hs_jour_50].to_f, hs_jour_100: @p[:hs_jour_100].to_f,
        hs_nuit_25: @p[:hs_nuit_25].to_f, hs_nuit_50: @p[:hs_nuit_50].to_f, hs_nuit_100: @p[:hs_nuit_100].to_f,
        tib_mensuel: tib_montant
      ).compute
      return if result[:total].zero?

      result[:lines].each do |hs|
        add_line(code: hs[:code], label: hs[:label], category: :var_m, montant: hs[:montant], detail: hs[:detail])
      end
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
      assiette_cnracl = tib_montant + Iade::AutoPrimesCalculator::CTI_MONTANT

      add_deduction(code: "RCN", label: "CNRACL RETRAITE",
                    montant: Iade::CotisationsCalculator.cnracl(assiette: assiette_cnracl),
                    detail: "11,10% × (TIB + CTI)")

      if nbi_points.positive?
        nbi_m = Iade::NbiCalculator.new(points: nbi_points).montant
        add_deduction(code: "RCB", label: "CNRACL – N.B.I.",
                      montant: Iade::CotisationsCalculator.cnracl(assiette: nbi_m), detail: "11,10% × NBI")
      end

      add_deduction(code: "RAF", label: "RETRAITE ADD.TITU. (RAFP)",
                    montant: Iade::CotisationsCalculator.rafp(assiette_primes: brut_primes_total),
                    detail: "5% plafonné (titulaires uniquement)")
    end

    def add_retraite_ircantec
      assiette = tib_montant + Iade::AutoPrimesCalculator::CTI_MONTANT + brut_primes_total

      add_deduction(code: "RET", label: "RETRAITE IRCANTEC",
                    montant: Iade::CotisationsCalculator.ircantec(assiette: assiette),
                    detail: "4,01% tranche A (contractuel)")
    end

    def build_deduction_lines # rubocop:disable Metrics/MethodLength
      add_retraite_principale

      base_csg = Iade::CotisationsCalculator.base_csg(brut_total: @brut_lines_total)

      add_deduction(code: "UCB", label: "C.S.G. ET R.D.S.",
                    montant: Iade::CotisationsCalculator.csg_crds(base_csg: base_csg), detail: "2,90%")

      add_deduction(code: "UCX", label: "CSG MALADIE TITUL.",
                    montant: Iade::CotisationsCalculator.csg_maladie(base_csg: base_csg), detail: "6,80%")

      hs_total = hs_montant_total
      if hs_total.positive?
        add_deduction(code: "UC8", label: "CSG SUR TTA OU HS",
                      montant: Iade::CotisationsCalculator.csg_hs(assiette_hs: hs_total), detail: "9,20%")
        add_deduction(code: "VR7", label: "REDUC COTIS SUR HS",
                      montant: -Iade::CotisationsCalculator.reduction_hs(assiette_hs: hs_total), detail: "Crédit")
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
      @lines.reject { |l| l[:type] == :deduction }
      deduct_lines = @lines.select { |l| l[:type] == :deduction }

      @brut_total        = @brut_lines_total
      @cotisations_total = deduct_lines.sum { |l| l[:montant] }
      @net_social        = @brut_total - @cotisations_total

      pas_montant    = deduct_lines.find { |l| l[:code] == "Q60" }&.dig(:montant) || BigDecimal("0")
      mutuelle       = BigDecimal(@p[:mutuelle].to_s.presence || "0")
      @net_avant_pas = @brut_total - (@cotisations_total - pas_montant)
      @net_paye      = @net_avant_pas - pas_montant - mutuelle
    end

    # ---------------- HELPERS ----------------

    def add_line(code:, label:, category:, montant:, detail: nil, pay_lag: nil)
      @lines << { code: code, label: label, category: category, montant: montant.to_d.round(2),
                  detail: detail, pay_lag: pay_lag, type: :brut }
    end

    def add_deduction(code:, label:, montant:, detail: nil)
      @lines << { code: code, label: label, category: :deduction, montant: montant.to_d.round(2),
                  detail: detail, type: :deduction }
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

    def brut_primes_total
      codes = %w[CW1 LP1 LPN IS1 JMA DIM/JF TP7/IT7/DHN]
      @lines.select { |l| codes.include?(l[:code]) && l[:type] == :brut }.sum { |l| l[:montant] }
    end

    def hs_montant_total
      @lines.select { |l| l[:code].start_with?("HS") && l[:type] == :brut }.sum { |l| l[:montant] }
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
