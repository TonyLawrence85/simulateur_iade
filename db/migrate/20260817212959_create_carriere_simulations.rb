class CreateCarriereSimulations < ActiveRecord::Migration[8.1]
  def change
    create_table :carriere_simulations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.string :kind,  null: false
      t.jsonb  :inputs, null: false, default: {}
      t.jsonb  :result

      t.timestamps
    end

    add_index :carriere_simulations, :token, unique: true
    add_index :carriere_simulations, %i[user_id kind]
  end
end
