class SimulationSession < ApplicationRecord
  belongs_to :user
  has_one_attached :bulletin_pdf

  STATUTS     = %w[titulaire stagiaire contractuel].freeze
  GRADES      = %w[grade1 grade2 as_grade1 as_grade2 ide_grade1 ide_grade2].freeze
  PROFESSIONS = %w[iade ide as].freeze

  validates :mois_paie,        presence: true, format: { with: /\A\d{4}-\d{2}\z/ }
  validates :profession,       presence: true, inclusion: { in: PROFESSIONS }
  validates :statut,           presence: true, inclusion: { in: STATUTS }
  validates :grade,            presence: true, inclusion: { in: GRADES }
  validates :echelon,          presence: true, inclusion: { in: 1..11 }
  validates :quotite,          presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 1 }
  validates :departement_code, presence: true
  validates :taux_pas,          numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :confirm_decalage,  acceptance: { accept: ["1", true] }
  validates :token,             presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  scope :recent, -> { order(created_at: :desc) }

  def simulate!
    Iade::PayslipCalculator.call(simulation_params)
  end

  def simulation_params
    attributes.symbolize_keys.slice(
      :mois_paie, :profession, :statut, :grade, :echelon, :quotite,
      :departement_code, :nb_enfants_sft, :nbi_points,
      :iss_montant, :dtc_montant, :wt1_montant,
      :taux_pas, :mutuelle, :garde_alternee,
      :heures_nuit, :heures_dimanche, :heures_ferie,
      :tp7_qty, :it7_qty, :dhn_heures,
      :hs_jour, :hs_nuit, :hs_dim_jf,
      :montant_psr, :jours_absence_psr, :montant_lsu,
      :nb_gardes, :heures_par_garde,
      :jours_carence, :jours_cmo90, :jours_cmo50,
      :date_entree_echelon,
      :heure_debut_service, :heure_fin_service,
      :nb_matins, :nb_apres_midi, :nb_soirs,
      :type_navigo, :navigo_montant_annuel,
      :simulate_fmd, :fmd_mode, :fmd_jours_annee
    )
  end

  def to_param
    token
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(16)
  end
end
