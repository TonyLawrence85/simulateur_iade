class AddHeuresWeekendGardeToSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :simulation_sessions, :heures_weekend_garde, :decimal
  end
end
