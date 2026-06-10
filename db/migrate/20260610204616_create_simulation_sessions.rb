class CreateSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :simulation_sessions do |t|
      t.string  :mois_paie,          null: false
      t.string  :statut,             null: false, default: "titulaire"
      t.string  :grade,              null: false, default: "grade1"
      t.integer :echelon,            null: false, default: 1
      t.decimal :quotite,            precision: 5,  scale: 2, null: false, default: 1.0
      t.string  :departement_code,   null: false, default: "75"
      t.integer :nb_enfants_sft,     default: 0
      t.integer :nbi_points,         default: 0
      t.decimal :iss_montant,        precision: 10, scale: 2
      t.decimal :dtc_montant,        precision: 10, scale: 2
      t.decimal :wt1_montant,        precision: 10, scale: 2
      t.decimal :taux_pas,           precision: 5,  scale: 2
      t.decimal :mutuelle,           precision: 10, scale: 2
      t.boolean :garde_alternee,     default: false
      t.string  :type_cycle,         default: "7h36"

      # Variables planning
      t.decimal :heures_nuit,        precision: 6, scale: 2, default: 0
      t.decimal :heures_dimanche,    precision: 6, scale: 2, default: 0
      t.decimal :heures_ferie,       precision: 6, scale: 2, default: 0
      t.integer :tp7_qty,            default: 0
      t.integer :it7_qty,            default: 0
      t.decimal :dhn_heures,         precision: 6, scale: 2, default: 0

      # Heures supplémentaires
      t.decimal :hs_jour_25,         precision: 6, scale: 2, default: 0
      t.decimal :hs_jour_50,         precision: 6, scale: 2, default: 0
      t.decimal :hs_jour_100,        precision: 6, scale: 2, default: 0
      t.decimal :hs_nuit_25,         precision: 6, scale: 2, default: 0
      t.decimal :hs_nuit_50,         precision: 6, scale: 2, default: 0
      t.decimal :hs_nuit_100,        precision: 6, scale: 2, default: 0

      # Résultats calculés
      t.decimal :result_brut_total,        precision: 10, scale: 2
      t.decimal :result_cotisations_total,  precision: 10, scale: 2
      t.decimal :result_net_avant_pas,      precision: 10, scale: 2
      t.decimal :result_net_paye,           precision: 10, scale: 2
      t.jsonb   :result_lines

      # Bulletin réel (comparaison)
      t.decimal :real_brut_total,    precision: 10, scale: 2
      t.decimal :real_net_paye,      precision: 10, scale: 2
      t.jsonb   :real_lines
      t.string  :bulletin_file_path

      # Relation utilisateur
      t.references :user, foreign_key: true

      # Token anonyme pour les URLs
      t.string :token, null: false

      t.timestamps
    end

    add_index :simulation_sessions, :token,      unique: true
    add_index :simulation_sessions, :mois_paie
    add_index :simulation_sessions, :created_at
  end
end
