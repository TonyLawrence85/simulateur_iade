# frozen_string_literal: true

class AddAbsencesCarriereToSimulationSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :simulation_sessions, :jours_carence,       :integer, default: 0
    add_column :simulation_sessions, :jours_cmo90,         :integer, default: 0
    add_column :simulation_sessions, :jours_cmo50,         :integer, default: 0
    add_column :simulation_sessions, :date_entree_echelon, :date
  end
end
