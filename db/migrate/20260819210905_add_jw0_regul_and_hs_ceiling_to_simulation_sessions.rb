class AddJw0RegulAndHsCeilingToSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :simulation_sessions, :jw0_regul_heures, :decimal
    add_column :simulation_sessions, :cumul_hs_brut_anterieur, :decimal
  end
end
