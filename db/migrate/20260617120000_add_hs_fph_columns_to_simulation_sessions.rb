class AddHsFphColumnsToSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :simulation_sessions, :hs_jour,    :decimal
    add_column :simulation_sessions, :hs_nuit,    :decimal
    add_column :simulation_sessions, :hs_dim_jf,  :decimal
  end
end
