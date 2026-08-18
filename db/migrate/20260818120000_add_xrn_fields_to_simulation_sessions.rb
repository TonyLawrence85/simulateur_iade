class AddXrnFieldsToSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :simulation_sessions, :xrn_eligible, :string
    add_column :simulation_sessions, :xrn_nb_nuits, :integer
  end
end
