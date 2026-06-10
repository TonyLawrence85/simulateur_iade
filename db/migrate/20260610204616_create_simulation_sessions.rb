class CreateSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :simulation_sessions do |t|
      t.string :mois_paie
      t.string :statut
      t.string :grade
      t.integer :echelon
      t.decimal :quotite
      t.string :departement_code
      t.integer :nb_enfants_sft
      t.integer :nbi_points
      t.decimal :iss_montant
      t.decimal :dtc_montant
      t.decimal :wt1_montant
      t.decimal :taux_pas
      t.decimal :mutuelle
      t.boolean :garde_alternee
      t.decimal :heures_nuit
      t.decimal :heures_dimanche
      t.decimal :heures_ferie
      t.integer :tp7_qty
      t.integer :it7_qty
      t.decimal :dhn_heures
      t.decimal :hs_jour_25
      t.decimal :hs_jour_50
      t.decimal :hs_jour_100
      t.decimal :hs_nuit_25
      t.decimal :hs_nuit_50
      t.decimal :hs_nuit_100
      t.decimal :result_brut_total
      t.decimal :result_cotisations_total
      t.decimal :result_net_avant_pas
      t.decimal :result_net_paye
      t.jsonb :result_lines
      t.decimal :real_brut_total
      t.decimal :real_net_paye
      t.jsonb :real_lines
      t.string :bulletin_file_path
      t.string :token
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
