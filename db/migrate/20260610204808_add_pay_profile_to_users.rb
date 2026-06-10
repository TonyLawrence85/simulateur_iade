class AddPayProfileToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :grade, :string
    add_column :users, :echelon, :integer
    add_column :users, :quotite, :decimal
    add_column :users, :departement_code, :string
    add_column :users, :statut, :string
    add_column :users, :nbi_points, :integer
    add_column :users, :iss_montant, :decimal
    add_column :users, :dtc_montant, :decimal
    add_column :users, :wt1_montant, :decimal
    add_column :users, :taux_pas, :decimal
    add_column :users, :mutuelle, :decimal
    add_column :users, :garde_alternee, :boolean
    add_column :users, :type_cycle, :string
  end
end
