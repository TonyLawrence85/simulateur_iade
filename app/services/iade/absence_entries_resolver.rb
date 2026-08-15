# frozen_string_literal: true

module Iade
  # Traduit une liste d'absences saisies (type, dates, réponses) en jours de carence /
  # CMO 90% / CMO 50% / CLM-CLD / ANR, en ne retenant que les jours qui tombent dans le
  # mois simulé.
  #
  # Règles confirmées (Service Public + cahier de spécifications AP-HP) :
  # - Maladie ordinaire (nouvel arrêt) : 1 jour de carence puis 90% (3 mois) puis 50% (9 mois).
  #   Pas de carence en cas de prolongation, ni en cas de reprise ≤ 48h suivie d'un nouvel
  #   arrêt lié à la même affection.
  # - Congé maternité / paternité / congé pathologique lié à la grossesse : maintien à 100%,
  #   aucune retenue.
  # - Accident de service / accident de trajet / maladie professionnelle : relèvent du CITIS.
  #   Maintien à 100% (traitement, indemnité de résidence, SFT) UNIQUEMENT si l'imputabilité
  #   au service est reconnue. Tant que la reconnaissance est en attente (ou refusée), l'agent
  #   est traité provisoirement comme en maladie ordinaire (carence + CMO 90%), à régulariser
  #   une fois la décision connue.
  # - CLM (congé longue maladie) : jours 1-365 à plein traitement (TIB/IR/SFT 100%, primes 0%),
  #   au-delà (jusqu'à 3 ans) à demi-traitement (TIB/IR/SFT 50%, primes 0%). Pas de carence.
  # - CLD (congé longue durée) : jours 1-1825 (5 ans) à plein traitement, au-delà (jusqu'à
  #   8 ans) à demi-traitement. Mêmes règles de primes/carence que le CLM.
  # - Absence non rémunérée (ANR) : retenue intégrale sur la rémunération brute totale
  #   = brut mensuel / jours calendaires du mois × jours d'absence.
  # - Autre absence : règle pas encore intégrée (0 retenue, jours comptabilisés à part pour
  #   rester visibles à l'utilisateur).
  class AbsenceEntriesResolver
    TYPES = [
      ["maladie_ordinaire", "Maladie ordinaire", :maladie_ordinaire],
      ["prolongation_maladie_ordinaire", "Prolongation d'un arrêt maladie ordinaire", :maladie_ordinaire],
      ["conge_maternite", "Congé maternité", :maintenu_100],
      ["conge_paternite", "Congé paternité", :maintenu_100],
      ["conge_pathologique_grossesse", "Congé pathologique lié à la grossesse", :maintenu_100],
      ["accident_service", "Accident de service / accident de travail", :imputabilite],
      ["accident_trajet", "Accident de trajet", :imputabilite],
      ["maladie_professionnelle", "Maladie professionnelle", :imputabilite],
      ["clm", "Congé longue maladie (CLM)", :longue_maladie],
      ["cld", "Congé longue durée (CLD)", :longue_maladie],
      ["absence_non_remuneree", "Absence non rémunérée", :anr],
      ["autre", "Autre absence", :non_calcule]
    ].freeze

    FAMILY_BY_TYPE = TYPES.to_h { |key, _label, family| [key, family] }.freeze

    NO_CARENCE_CONTINUATIONS = %w[prolongation reprise_48h].freeze

    # Seuil (en jours) du palier plein traitement → demi-traitement, pour affichage seulement :
    # la réponse de l'utilisateur ("palier") fait foi, on ne recalcule pas de date pivot.
    PALIER_SEUIL_JOURS = { "clm" => 365, "cld" => 1825 }.freeze

    Result = Struct.new(
      :jours_carence, :jours_cmo90, :jours_cmo50,
      :jours_clm_cld_plein, :jours_clm_cld_demi, :jours_anr,
      :jours_maintenus_100, :jours_non_calcules, :jours_total,
      keyword_init: true
    )

    def self.select_options
      TYPES.map { |key, label, family| [label, key, { data: { family: family } }] }
    end

    def initialize(absences:, mois_paie:)
      @absences  = Array(absences).filter_map { |entry| normalize(entry) }
      @mois_paie = mois_paie
    end

    def call
      totals = Hash.new(0)
      @absences.each { |entry| accumulate(entry, totals) } if month_start

      Result.new(
        jours_carence: totals[:carence],
        jours_cmo90: totals[:cmo90],
        jours_cmo50: totals[:cmo50],
        jours_clm_cld_plein: totals[:clm_cld_plein],
        jours_clm_cld_demi: totals[:clm_cld_demi],
        jours_anr: totals[:anr],
        jours_maintenus_100: totals[:maintenus_100],
        jours_non_calcules: totals[:non_calcules],
        jours_total: totals.values.sum
      )
    end

    private

    def normalize(entry)
      return entry.symbolize_keys if entry.is_a?(Hash)
      return entry.to_unsafe_h.symbolize_keys if entry.respond_to?(:to_unsafe_h)

      nil
    end

    def month_start
      return @month_start if defined?(@month_start)

      @month_start = @mois_paie.present? ? Date.strptime(@mois_paie.to_s, "%Y-%m") : nil
    rescue ArgumentError
      @month_start = nil
    end

    def month_end
      month_start.end_of_month
    end

    def accumulate(entry, totals) # rubocop:disable Metrics/MethodLength
      debut, fin = parse_dates(entry)
      return unless debut && fin && fin >= debut

      clip_debut = [debut, month_start].max
      clip_fin   = [fin, month_end].min
      return if clip_fin < clip_debut

      jours_in_month = (clip_fin - clip_debut).to_i + 1
      family = FAMILY_BY_TYPE[entry[:type].to_s]

      case family
      when :maladie_ordinaire
        accumulate_maladie_ordinaire(entry, debut, jours_in_month, totals)
      when :imputabilite
        accumulate_imputabilite(entry, debut, jours_in_month, totals)
      when :longue_maladie
        accumulate_longue_maladie(entry, jours_in_month, totals)
      when :anr
        totals[:anr] += jours_in_month
      when :maintenu_100
        totals[:maintenus_100] += jours_in_month
      else
        totals[:non_calcules] += jours_in_month
      end
    end

    # Tant que l'imputabilité au service n'est pas reconnue ("oui"), on traite provisoirement
    # l'absence comme un nouvel arrêt maladie ordinaire (carence + 90%).
    def accumulate_imputabilite(entry, debut, jours_in_month, totals)
      if entry[:imputabilite_service].to_s == "oui"
        totals[:maintenus_100] += jours_in_month
      else
        provisoire = entry.merge(continuation: "nouvel_arret", compteur_90j_depasse: "non")
        accumulate_maladie_ordinaire(provisoire, debut, jours_in_month, totals)
      end
    end

    def accumulate_maladie_ordinaire(entry, debut, jours_in_month, totals)
      continuation = entry[:type].to_s == "prolongation_maladie_ordinaire" ? "prolongation" : entry[:continuation].to_s
      carence_applies = NO_CARENCE_CONTINUATIONS.exclude?(continuation)
      carence_days = carence_applies && debut >= month_start ? [1, jours_in_month].min : 0
      remaining = jours_in_month - carence_days

      totals[:carence] += carence_days
      if entry[:compteur_90j_depasse].to_s == "oui"
        totals[:cmo50] += remaining
      else
        totals[:cmo90] += remaining
      end
    end

    # Pas de jour de carence pour le CLM/CLD. Par défaut ("je ne sais pas"), on suppose le
    # palier demi-traitement (hypothèse basse) plutôt que le palier plein traitement, pour ne
    # pas surestimer le net estimé.
    def accumulate_longue_maladie(entry, jours_in_month, totals)
      if entry[:palier].to_s == "plein"
        totals[:clm_cld_plein] += jours_in_month
      else
        totals[:clm_cld_demi] += jours_in_month
      end
    end

    def parse_dates(entry)
      [parse_date(entry[:date_debut]), parse_date(entry[:date_fin])]
    end

    def parse_date(value)
      return nil if value.blank?
      return value if value.is_a?(Date)

      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
