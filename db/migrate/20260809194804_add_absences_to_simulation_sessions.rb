class AddAbsencesToSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :simulation_sessions, :absences, :jsonb, default: [], null: false
  end
end
