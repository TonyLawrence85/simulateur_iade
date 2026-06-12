class DepartmentZone < ApplicationRecord
  validates :code,       presence: true
  validates :nom,        presence: true
  validates :zone,       presence: true, inclusion: { in: [1, 2, 3] }
  validates :date_debut, presence: true

  scope :active_at, lambda { |date = Date.today|
    where("date_debut <= ?", date)
      .where("date_fin IS NULL OR date_fin >= ?", date)
  }

  def self.zone_for(departement_code, date: Date.today)
    active_at(date).find_by(code: departement_code)&.zone || 3
  end
end
