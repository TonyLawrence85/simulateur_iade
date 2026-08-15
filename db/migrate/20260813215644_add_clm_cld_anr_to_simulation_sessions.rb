class AddClmCldAnrToSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :simulation_sessions, :jours_clm_cld_plein, :integer, default: 0
    add_column :simulation_sessions, :jours_clm_cld_demi, :integer, default: 0
    add_column :simulation_sessions, :jours_anr, :integer, default: 0
  end
end
