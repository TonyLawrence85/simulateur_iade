class CreateDepartmentZones < ActiveRecord::Migration[8.1]
  def change
    create_table :department_zones do |t|
      t.string :code
      t.string :nom
      t.integer :zone
      t.date :date_debut
      t.date :date_fin

      t.timestamps
    end
  end
end
