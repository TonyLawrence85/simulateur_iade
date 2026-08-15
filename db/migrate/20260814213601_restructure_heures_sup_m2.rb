class RestructureHeuresSupM2 < ActiveRecord::Migration[8.1]
  def change
    add_column :simulation_sessions, :hs_m2_nuit,     :decimal
    add_column :simulation_sessions, :hs_m2_dimanche, :decimal
    add_column :simulation_sessions, :hs_m2_ferie,    :decimal
    add_column :simulation_sessions, :hs_m2_jour,     :decimal
    add_column :simulation_sessions, :tp7_heures,     :decimal
    add_column :simulation_sessions, :tp8_heures,     :decimal

    remove_column :simulation_sessions, :tp7_qty,    :integer
    remove_column :simulation_sessions, :it7_qty,    :integer
    remove_column :simulation_sessions, :dhn_heures, :decimal
    remove_column :simulation_sessions, :hs_jour,    :decimal
    remove_column :simulation_sessions, :hs_nuit,    :decimal
    remove_column :simulation_sessions, :hs_dim_jf,  :decimal
  end
end
