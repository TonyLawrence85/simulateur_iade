class CreateDepartmentZones < ActiveRecord::Migration[8.1]
  def change
    create_table :department_zones do |t|
      t.string  :code,       null: false, limit: 3
      t.string  :nom,        null: false
      t.integer :zone,       null: false
      t.date    :date_debut, null: false
      t.date    :date_fin
      t.timestamps
    end

    add_index :department_zones, [:code, :date_debut], unique: true
  end
end
