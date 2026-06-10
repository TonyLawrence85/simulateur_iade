class CreateGradeScales < ActiveRecord::Migration[8.1]
  def change
    create_table :grade_scales do |t|
      t.string  :grade,         null: false
      t.integer :echelon,       null: false
      t.integer :indice_majore, null: false
      t.date    :date_debut,    null: false
      t.date    :date_fin
      t.string  :source
      t.timestamps
    end

    add_index :grade_scales, [:grade, :echelon, :date_debut], unique: true,
              name: "idx_grade_scales_unique"
  end
end
