class CreateGradeScales < ActiveRecord::Migration[8.1]
  def change
    create_table :grade_scales do |t|
      t.string :grade
      t.integer :echelon
      t.integer :indice_majore
      t.date :date_debut
      t.date :date_fin
      t.string :source

      t.timestamps
    end
  end
end
