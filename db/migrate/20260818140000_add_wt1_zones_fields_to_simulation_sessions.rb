class AddWt1ZonesFieldsToSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :simulation_sessions, :wt1_a_abonnement, :string
    add_column :simulation_sessions, :wt1_zones, :string
    add_column :simulation_sessions, :wt1_nuit_eligible, :string
  end
end
