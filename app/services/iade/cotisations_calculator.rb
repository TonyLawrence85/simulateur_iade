# frozen_string_literal: true

module Iade
  module CotisationsCalculator
    TAUX_CNRACL          = BigDecimal("0.1110")
    TAUX_RAFP            = BigDecimal("0.0500")
    TAUX_CSG_CRDS        = BigDecimal("0.0290")
    TAUX_CSG_MALADIE     = BigDecimal("0.0680")
    TAUX_CSG_HS          = BigDecimal("0.0680")
    ABATTEMENT_FRAIS_PRO = BigDecimal("0.0175")
    TAUX_IRCANTEC_T1 = BigDecimal("0.0401") # 4,01% — tranche A (part salariale)

    def self.cnracl(assiette:)
      (BigDecimal(assiette.to_s) * TAUX_CNRACL).round(2)
    end

    def self.ircantec(assiette:)
      (BigDecimal(assiette.to_s) * TAUX_IRCANTEC_T1).round(2)
    end

    def self.rafp(assiette_primes:, tib_annuel: nil)
      if tib_annuel
        plafond_annuel    = BigDecimal(tib_annuel.to_s) * BigDecimal("0.20")
        assiette_annuelle = [BigDecimal(assiette_primes.to_s) * 12, plafond_annuel].min
        (assiette_annuelle / 12 * TAUX_RAFP).round(2)
      else
        (BigDecimal(assiette_primes.to_s) * TAUX_RAFP).round(2)
      end
    end

    def self.base_csg(brut_total:, abattement: ABATTEMENT_FRAIS_PRO)
      brut  = BigDecimal(brut_total.to_s)
      abatt = BigDecimal(abattement.to_s)
      (brut * (1 - abatt)).round(2)
    end

    def self.csg_crds(base_csg:)
      (BigDecimal(base_csg.to_s) * TAUX_CSG_CRDS).round(2)
    end

    def self.csg_maladie(base_csg:)
      (BigDecimal(base_csg.to_s) * TAUX_CSG_MALADIE).round(2)
    end

    def self.csg_hs(assiette_hs:)
      (BigDecimal(assiette_hs.to_s) * TAUX_CSG_HS).round(2)
    end

    def self.pas(base_imposable:, taux:)
      (BigDecimal(base_imposable.to_s) * BigDecimal(taux.to_s)).round(2)
    end
  end
end
