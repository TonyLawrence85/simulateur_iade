class AddConfirmDecalageToSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :simulation_sessions, :confirm_decalage, :boolean, default: false
  end
end
