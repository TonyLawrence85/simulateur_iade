class CreatePointValues < ActiveRecord::Migration[8.1]
  def change
    create_table :point_values do |t|
      t.decimal :valeur
      t.date :date_debut
      t.date :date_fin
      t.string :reference_decret
      t.text :notes

      t.timestamps
    end
  end
end
