class AddHeuresServiceToSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :simulation_sessions, :heure_debut_service, :string
    add_column :simulation_sessions, :heure_fin_service, :string
  end
end
