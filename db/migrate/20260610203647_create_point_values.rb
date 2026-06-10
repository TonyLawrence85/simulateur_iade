class CreatePointValues < ActiveRecord::Migration[8.1]
  def change
    create_table :point_values do |t|
      t.decimal :valeur,            precision: 10, scale: 5, null: false
      t.date    :date_debut,        null: false
      t.date    :date_fin
      t.string  :reference_decret
      t.text    :notes
      t.timestamps
    end

    add_index :point_values, :date_debut
  end
end
