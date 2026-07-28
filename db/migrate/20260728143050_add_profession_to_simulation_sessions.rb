class AddProfessionToSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :simulation_sessions, :profession, :string, default: "iade", null: false
  end
end
