class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :simulation_sessions, dependent: :destroy

  def simulation_defaults # rubocop:disable Metrics/MethodLength,Metrics/PerceivedComplexity
    {
      grade: grade || "grade1",
      echelon: echelon          || 1,
      quotite: quotite          || 1.0,
      departement_code: departement_code || "75",
      nb_enfants_sft: self.nb_enfants_sft || 0, # rubocop:disable Style/RedundantSelf
      nbi_points: nbi_points || 0,
      iss_montant: iss_montant,
      dtc_montant: dtc_montant,
      wt1_montant: wt1_montant,
      taux_pas: taux_pas,
      mutuelle: mutuelle,
      statut: statut || "titulaire",
      garde_alternee: garde_alternee || false,
      type_cycle: type_cycle || "7h36"
    }
  end
end
