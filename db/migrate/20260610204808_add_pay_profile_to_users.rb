class AddPayProfileToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :grade,            :string,  default: "grade1"
    add_column :users, :echelon,          :integer, default: 1
    add_column :users, :quotite,          :decimal, precision: 5, scale: 2, default: 1.0
    add_column :users, :departement_code, :string,  default: "75"
    add_column :users, :statut,           :string,  default: "titulaire"
    add_column :users, :nbi_points,       :integer, default: 0
    add_column :users, :iss_montant,      :decimal, precision: 10, scale: 2
    add_column :users, :dtc_montant,      :decimal, precision: 10, scale: 2
    add_column :users, :wt1_montant,      :decimal, precision: 10, scale: 2
    add_column :users, :taux_pas,         :decimal, precision: 5,  scale: 2
    add_column :users, :mutuelle,         :decimal, precision: 10, scale: 2
    add_column :users, :garde_alternee,   :boolean, default: false
    add_column :users, :type_cycle,       :string,  default: "7h36"
    add_column :users, :nb_enfants_sft,   :integer, default: 0
  end
end
