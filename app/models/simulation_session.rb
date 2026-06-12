class SimulationSession < ApplicationRecord
  belongs_to :user

  STATUTS = %w[titulaire stagiaire contractuel].freeze
  GRADES  = %w[grade1 grade2].freeze

  validates :mois_paie,        presence: true, format: { with: /\A\d{4}-\d{2}\z/ }
  validates :statut,           presence: true, inclusion: { in: STATUTS }
  validates :grade,            presence: true, inclusion: { in: GRADES }
  validates :echelon,          presence: true, inclusion: { in: 1..11 }
  validates :quotite,          presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 1 }
  validates :departement_code, presence: true
  validates :taux_pas,         numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :token,            presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  scope :recent, -> { order(created_at: :desc) }

  def simulate!
    Iade::PayslipCalculator.call(simulation_params)
  end

  def simulation_params
    attributes.symbolize_keys.slice(
      :mois_paie, :statut, :grade, :echelon, :quotite,
      :departement_code, :nb_enfants_sft, :nbi_points,
      :iss_montant, :dtc_montant, :wt1_montant,
      :taux_pas, :mutuelle, :garde_alternee,
      :heures_nuit, :heures_dimanche, :heures_ferie,
      :tp7_qty, :it7_qty, :dhn_heures,
      :hs_jour_25, :hs_jour_50, :hs_jour_100,
      :hs_nuit_25, :hs_nuit_50, :hs_nuit_100
    )
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(16)
  end
end
