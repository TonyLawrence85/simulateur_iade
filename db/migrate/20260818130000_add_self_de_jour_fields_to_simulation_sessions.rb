class AddSelfDeJourFieldsToSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :simulation_sessions, :self_repas_eligible, :string
    add_column :simulation_sessions, :self_nb_repas, :integer
  end
end
