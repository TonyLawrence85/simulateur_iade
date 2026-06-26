# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_20_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "department_zones", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.date "date_debut"
    t.date "date_fin"
    t.string "nom"
    t.datetime "updated_at", null: false
    t.integer "zone"
  end

  create_table "grade_scales", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_debut"
    t.date "date_fin"
    t.integer "echelon"
    t.string "grade"
    t.integer "indice_majore"
    t.string "source"
    t.datetime "updated_at", null: false
  end

  create_table "point_values", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_debut"
    t.date "date_fin"
    t.text "notes"
    t.string "reference_decret"
    t.datetime "updated_at", null: false
    t.decimal "valeur"
  end

  create_table "simulation_sessions", force: :cascade do |t|
    t.string "bulletin_file_path"
    t.boolean "confirm_decalage"
    t.datetime "created_at", null: false
    t.date "date_entree_echelon"
    t.string "departement_code"
    t.decimal "dhn_heures"
    t.decimal "dtc_montant"
    t.integer "echelon"
    t.boolean "garde_alternee"
    t.string "grade"
    t.decimal "heures_dimanche"
    t.decimal "heures_ferie"
    t.decimal "heures_nuit"
    t.decimal "heures_par_garde", precision: 4, scale: 1
    t.decimal "hs_dim_jf"
    t.decimal "hs_jour"
    t.decimal "hs_jour_100"
    t.decimal "hs_jour_25"
    t.decimal "hs_jour_50"
    t.decimal "hs_nuit"
    t.decimal "hs_nuit_100"
    t.decimal "hs_nuit_25"
    t.decimal "hs_nuit_50"
    t.decimal "iss_montant"
    t.integer "it7_qty"
    t.integer "jours_absence_psr", default: 0
    t.integer "jours_carence", default: 0
    t.integer "jours_cmo50", default: 0
    t.integer "jours_cmo90", default: 0
    t.string "mois_paie"
    t.decimal "montant_lsu", precision: 10, scale: 2
    t.decimal "montant_psr", precision: 10, scale: 2
    t.decimal "mutuelle"
    t.integer "nb_enfants_sft"
    t.decimal "nb_gardes", precision: 6, scale: 2
    t.integer "nbi_points"
    t.decimal "quotite"
    t.decimal "real_brut_total"
    t.jsonb "real_lines"
    t.decimal "real_net_paye"
    t.decimal "result_brut_total"
    t.decimal "result_cotisations_total"
    t.jsonb "result_lines"
    t.decimal "result_net_avant_pas"
    t.decimal "result_net_paye"
    t.string "statut"
    t.decimal "taux_pas"
    t.string "token"
    t.integer "tp7_qty"
    t.string "type_cycle"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.decimal "wt1_montant"
    t.index ["user_id"], name: "index_simulation_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "departement_code"
    t.decimal "dtc_montant"
    t.integer "echelon"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.boolean "garde_alternee"
    t.string "grade"
    t.decimal "iss_montant"
    t.decimal "mutuelle"
    t.integer "nb_enfants_sft"
    t.integer "nbi_points"
    t.decimal "quotite"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "statut"
    t.decimal "taux_pas"
    t.string "type_cycle"
    t.datetime "updated_at", null: false
    t.decimal "wt1_montant"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "simulation_sessions", "users"
end
