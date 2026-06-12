class AddTypeCycleToSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :simulation_sessions, :type_cycle, :string, default: "7h36"
  end
end
