# frozen_string_literal: true

module Iade
  # Coût informatif du restaurant du personnel (self de jour) — dispositif séparé du
  # ticket restaurant de nuit (XRN). Ne modifie jamais le net de paie simulé : le
  # bulletin IADE de référence (juillet 2026) ne comporte aucune ligne de self de jour
  # (fiche corrective codeur 17/08/2026, fiche 2).
  class SelfDeJourCalculator
    Result = Struct.new(:nb_repas, :indice_majore, :tarif_unitaire, :cout_estime,
                        :date_effet_table, :warning, keyword_init: true)

    # Table AP-HP de référence — note D2023-285, effet 01/03/2023. Paramétrable par
    # date d'effet : ajouter une entrée ici dès qu'une note plus récente est versée
    # au projet plutôt que de remplacer cette table (fiche 2, "Attention 2026").
    TARIFS = {
      Date.new(2023, 3, 1) => [
        { max: 353, tarif: BigDecimal("2.82") },
        { max: 379, tarif: BigDecimal("3.48") },
        { max: 463, tarif: BigDecimal("4.36") },
        { max: 534, tarif: BigDecimal("5.28") },
        { max: 642, tarif: BigDecimal("6.26") },
        { max: nil, tarif: BigDecimal("7.36") }
      ]
    }.freeze

    def self.call(nb_repas:, indice_majore:, mois_paie: nil)
      new(nb_repas: nb_repas, indice_majore: indice_majore, mois_paie: mois_paie).call
    end

    def initialize(nb_repas:, indice_majore:, mois_paie: nil)
      @nb_repas      = nb_repas.to_i
      @indice_majore = indice_majore.to_i
      @mois_paie     = parse_mois(mois_paie)
    end

    def call
      table_date, bareme = tarifs_pour_date
      tarif = tranche(bareme)
      cout  = (@nb_repas * tarif).round(2)

      Result.new(
        nb_repas: @nb_repas, indice_majore: @indice_majore,
        tarif_unitaire: tarif, cout_estime: cout,
        date_effet_table: table_date, warning: warning_for(table_date)
      )
    end

    private

    # Table la plus récente dont la date d'effet précède (ou égale) le mois simulé —
    # à défaut, la plus ancienne connue.
    def tarifs_pour_date
      dates = TARIFS.keys.sort
      applicable = @mois_paie ? dates.select { |d| d <= @mois_paie }.max : dates.max
      applicable ||= dates.min
      [applicable, TARIFS.fetch(applicable)]
    end

    def tranche(bareme)
      ligne = bareme.find { |l| l[:max].nil? || @indice_majore <= l[:max] }
      ligne[:tarif]
    end

    # Avertit plutôt que de présenter un tarif d'une année antérieure comme exact pour
    # l'année simulée (checklist fiche 6 : "un tarif de self non validé pour l'année
    # simulée déclenche un avertissement, pas un faux calcul exact").
    def warning_for(table_date)
      return nil unless @mois_paie && @mois_paie.year > table_date.year

      "Aucun barème officiel #{@mois_paie.year} versé au projet — tarif informatif calculé " \
        "sur la dernière note connue (D2023-285, en vigueur depuis #{table_date.strftime('%d/%m/%Y')}). " \
        "À vérifier auprès de votre établissement."
    end

    def parse_mois(mois_paie)
      Date.strptime(mois_paie.to_s, "%Y-%m") if mois_paie.present?
    rescue ArgumentError
      nil
    end
  end
end
