class FixMigrationsDefaults < ActiveRecord::Migration[8.1]
  def change
    # --- Index manquants ---
    add_index :grade_scales, [:grade, :echelon, :date_debut],
              unique: true, name: "idx_grade_scales_unique"
    add_index :department_zones, [:code, :date_debut],
              unique: true, name: "idx_department_zones_unique"
    add_index :simulation_sessions, :token,      unique: true
    add_index :simulation_sessions, :mois_paie
    add_index :point_values, :date_debut

    # --- Valeurs par défaut simulation_sessions ---
    change_column_default :simulation_sessions, :statut,           "titulaire"
    change_column_default :simulation_sessions, :grade,            "grade1"
    change_column_default :simulation_sessions, :echelon,          1
    change_column_default :simulation_sessions, :quotite,          1.0
    change_column_default :simulation_sessions, :departement_code, "75"
    change_column_default :simulation_sessions, :nb_enfants_sft,   0
    change_column_default :simulation_sessions, :nbi_points,       0
    change_column_default :simulation_sessions, :garde_alternee,   false
    change_column_default :simulation_sessions, :tp7_qty,          0
    change_column_default :simulation_sessions, :it7_qty,          0

    # --- Contraintes null: false sur simulation_sessions ---
    change_column_null :simulation_sessions, :mois_paie,         false
    change_column_null :simulation_sessions, :token,             false
    change_column_null :simulation_sessions, :grade,             false
    change_column_null :simulation_sessions, :echelon,           false
    change_column_null :simulation_sessions, :quotite,           false
    change_column_null :simulation_sessions, :departement_code,  false

    # --- Colonne manquante sur users ---
    add_column :users, :nb_enfants_sft, :integer, default: 0

    # --- Valeurs par défaut users ---
    change_column_default :users, :grade,            "grade1"
    change_column_default :users, :echelon,          1
    change_column_default :users, :quotite,          1.0
    change_column_default :users, :departement_code, "75"
    change_column_default :users, :statut,           "titulaire"
    change_column_default :users, :nbi_points,       0
    change_column_default :users, :garde_alternee,   false
    change_column_default :users, :type_cycle,       "7h36"

    # --- Précision decimale sur valeur du point ---
    change_column :point_values, :valeur, :decimal, precision: 10, scale: 5, null: false
  end
end
