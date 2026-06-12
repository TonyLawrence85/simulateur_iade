class PointValue < ApplicationRecord
  validates :valeur,     presence: true, numericality: { greater_than: 0 }
  validates :date_debut, presence: true

  scope :active_at, lambda { |date = Date.today|
    where("date_debut <= ?", date)
      .where("date_fin IS NULL OR date_fin >= ?", date)
      .order(date_debut: :desc)
  }

  def self.current
    active_at.first
  end
end
