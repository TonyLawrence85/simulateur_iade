class AddNavigoFmdToSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :simulation_sessions, :type_navigo,            :string,  default: "mensuel"
    add_column :simulation_sessions, :navigo_montant_annuel,  :decimal, precision: 8, scale: 2
    add_column :simulation_sessions, :simulate_fmd,           :boolean, default: false
    add_column :simulation_sessions, :fmd_mode,               :string
    add_column :simulation_sessions, :fmd_jours_annee,        :integer
  end
end
