# frozen_string_literal: true

class AddPrimesVariablesToSimulationSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :simulation_sessions, :montant_psr,       :decimal, precision: 10, scale: 2
    add_column :simulation_sessions, :jours_absence_psr, :integer, default: 0
    add_column :simulation_sessions, :montant_lsu,       :decimal, precision: 10, scale: 2
    add_column :simulation_sessions, :nb_gardes,         :decimal, precision: 6,  scale: 2
    add_column :simulation_sessions, :heures_par_garde,  :decimal, precision: 4,  scale: 1
  end
end
