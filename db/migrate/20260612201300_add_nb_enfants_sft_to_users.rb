class AddNbEnfantsSftToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :nb_enfants_sft, :integer, default: 0
  end
end
