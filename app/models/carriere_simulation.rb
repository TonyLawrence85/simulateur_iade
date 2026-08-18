class CarriereSimulation < ApplicationRecord
  belongs_to :user

  KINDS = %w[promotion_2e_grade reclassement_ide_iade reclassement_as_ide].freeze

  store_accessor :inputs,
                  # Module A — promotion IADE 1er → 2e grade
                  :echelon_actuel, :mois_echelon_actuel, :mois_debut_cat_a,
                  :periode_exclue, :periode_debut, :periode_fin,
                  # Modules B/C — reclassement IDE→IADE et AS→IDE (champs partagés)
                  :situation_actuelle, :statut_administratif, :grade_source, :echelon_source,
                  :mois_echelon_source, :mois_nomination, :quotite, :zone_paris, :nb_enfants_sft,
                  :dtc_choix, :dtc_montant,
                  # Module B uniquement — NBI IADE et transport (double affichage avec/sans)
                  :nbi_choix, :nbi_points_expert, :wt1_montant

  validates :kind,  presence: true, inclusion: { in: KINDS }
  validates :token, presence: true, uniqueness: true

  with_options if: -> { kind == "promotion_2e_grade" } do
    validates :echelon_actuel, presence: true, inclusion: { in: (1..10).map(&:to_s) }
    validates :mois_echelon_actuel, presence: true, format: { with: /\A\d{4}-\d{2}\z/ }
    validates :mois_debut_cat_a,    presence: true, format: { with: /\A\d{4}-\d{2}\z/ }
  end

  with_options if: -> { kind.in?(%w[reclassement_ide_iade reclassement_as_ide]) } do
    validates :echelon_source, presence: true
    validates :mois_echelon_source, presence: true, format: { with: /\A\d{4}-\d{2}\z/ }
    validates :mois_nomination,     presence: true, format: { with: /\A\d{4}-\d{2}\z/ }
    validate :mois_nomination_apres_mois_echelon_source
  end

  before_validation :generate_token, on: :create
  before_validation :compute_result, on: :create

  scope :recent, -> { order(created_at: :desc) }

  def to_param
    token
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(16)
  end

  def mois_nomination_apres_mois_echelon_source
    return if mois_nomination.blank? || mois_echelon_source.blank?
    return if mois_nomination >= mois_echelon_source

    errors.add(:mois_nomination, "doit être postérieur au mois de l'échelon actuel")
  end

  def compute_result
    calculator = build_calculator
    return unless calculator

    self.result = calculator.call
  rescue StandardError => e
    self.result = { "incomplet" => true, "erreur" => e.message }
  end

  def build_calculator
    args = inputs.symbolize_keys
    case kind
    when "promotion_2e_grade"
      Iade::Promotion2eGradeCalculator.new(**args)
    when "reclassement_ide_iade"
      Iade::ReclassementIdeVersIadeCalculator.new(**args)
    when "reclassement_as_ide"
      Iade::ReclassementAsVersIdeCalculator.new(**args)
    end
  end
end
