# frozen_string_literal: true

module Iade
  # Moteur de projection de carrière partagé par les calculators de reclassement
  # (IDE→IADE, AS→IDE) et de promotion (IADE 1er→2e grade).
  module CarriereProjectionCalculator
    ProjectionResult = Struct.new(:echelon, :date_entree_echelon, :anciennete_mois, keyword_init: true)
    ClassementResult = Struct.new(:echelon, :indice_majore, :depasse, keyword_init: true)

    # Avance virtuellement l'échelon depuis (echelon_connu, date_connue) jusqu'à
    # date_cible en appliquant les durées réglementaires. Retourne l'échelon atteint,
    # sa date d'entrée, et l'ancienneté (en mois) dans cet échelon à date_cible.
    def self.project_to_date(grade:, echelon_connu:, date_connue:, date_cible:)
      durees = Iade::DureesEchelon.for_grade(grade)
      echelon = echelon_connu.to_i
      date_entree = date_connue

      loop do
        duree = durees[echelon]
        break if duree.nil? # échelon terminal : pas d'avancement possible

        date_prochain = date_entree >> duree
        break if date_prochain > date_cible

        echelon += 1
        date_entree = date_prochain
      end

      ProjectionResult.new(
        echelon: echelon,
        date_entree_echelon: date_entree,
        anciennete_mois: months_between(date_entree, date_cible)
      )
    end

    # Retrouve/estime la date d'entrée dans un échelon cible différent de l'échelon
    # connu, en remontant (échelon cible plus bas) ou en projetant (plus haut) via les
    # mêmes durées réglementaires. Approximation : suppose un avancement à cadence
    # standard, sans interruption (temps partiel, disponibilité...).
    def self.date_entree_echelon_estime(grade:, echelon_connu:, date_connue:, echelon_cible:)
      echelon_connu = echelon_connu.to_i
      return date_connue if echelon_cible == echelon_connu

      durees = Iade::DureesEchelon.for_grade(grade)

      if echelon_cible > echelon_connu
        date = date_connue
        (echelon_connu...echelon_cible).each do |echelon|
          duree = durees[echelon]
          return nil if duree.nil? # échelon terminal atteint avant la cible

          date += duree.months
        end
        date
      else
        date = date_connue
        (echelon_cible...echelon_connu).to_a.reverse_each do |echelon|
          duree = durees[echelon]
          return nil if duree.nil?

          date -= duree.months
        end
        date
      end
    end

    # Classe indice_source dans grade_cible : premier échelon dont l'indice majoré est
    # >= indice_source. Si aucun échelon ne convient (indice_source dépasse même le
    # dernier échelon), retourne le dernier échelon avec depasse: true.
    def self.classer_par_indice(grade_cible:, indice_source:, date:)
      max_echelon = GradeScale::MAX_ECHELON[grade_cible] || 11
      dernier = nil

      (1..max_echelon).each do |echelon|
        im = GradeScale.indice_for(grade: grade_cible, echelon: echelon, date: date)
        next unless im

        dernier = ClassementResult.new(echelon: echelon, indice_majore: im, depasse: false)
        return dernier if im >= indice_source
      end

      return nil unless dernier

      ClassementResult.new(echelon: dernier.echelon, indice_majore: dernier.indice_majore, depasse: true)
    end

    def self.months_between(from, to)
      (to.year - from.year) * 12 + (to.month - from.month)
    end
  end
end
