class AddPlanningMensuelToSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :simulation_sessions, :nb_matins, :integer
    add_column :simulation_sessions, :nb_apres_midi, :integer
    add_column :simulation_sessions, :nb_soirs, :integer
  end
end
