class AddPrimesTutoratToSimulationSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :simulation_sessions, :montant_primes_diverses, :decimal, precision: 10, scale: 2

    add_column :simulation_sessions, :ft1_mode,     :string
    add_column :simulation_sessions, :ft1_montant,  :decimal, precision: 10, scale: 2
    add_column :simulation_sessions, :ft1_semaines, :integer

    add_column :simulation_sessions, :ft9_actif,   :boolean, default: false
    add_column :simulation_sessions, :ft9_montant, :decimal, precision: 10, scale: 2
  end
end
