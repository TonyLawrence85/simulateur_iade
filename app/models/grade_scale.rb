class GradeScale < ApplicationRecord
  GRADES = %w[grade1 grade2].freeze

  # Grade 1 : 10 échelons / Grade 2 : 8 échelons (grille vérifiée 18/04/2026)
  MAX_ECHELON = { "grade1" => 10, "grade2" => 8 }.freeze

  validates :grade,         presence: true, inclusion: { in: GRADES }
  validates :indice_majore, presence: true, numericality: { greater_than: 0 }
  validates :date_debut,    presence: true
  validate  :echelon_in_range

  scope :active_at, lambda { |date = Date.today|
    where("date_debut <= ?", date)
      .where("date_fin IS NULL OR date_fin >= ?", date)
      .order(date_debut: :desc)
  }

  def self.indice_for(grade:, echelon:, date: Date.today)
    active_at(date).find_by(grade: grade, echelon: echelon)&.indice_majore
  end

  private

  def echelon_in_range
    return if grade.blank? || echelon.blank?

    max = MAX_ECHELON[grade] || 11
    return if echelon.between?(1, max)

    errors.add(:echelon, "doit être entre 1 et #{max} pour #{grade}")
  end
end
