class GradeScale < ApplicationRecord
  GRADES   = %w[grade1 grade2].freeze
  ECHELONS = (1..11).to_a.freeze

  validates :grade,         presence: true, inclusion: { in: GRADES }
  validates :echelon,       presence: true, inclusion: { in: ECHELONS }
  validates :indice_majore, presence: true, numericality: { greater_than: 0 }
  validates :date_debut,    presence: true

  scope :active_at, lambda { |date = Date.today|
    where("date_debut <= ?", date)
      .where("date_fin IS NULL OR date_fin >= ?", date)
      .order(date_debut: :desc)
  }

  def self.indice_for(grade:, echelon:, date: Date.today)
    active_at(date).find_by(grade: grade, echelon: echelon)&.indice_majore
  end
end
