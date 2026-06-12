class SimulationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_simulation, only: %i[show compare]

  def index
    @simulations = current_user.simulation_sessions.recent.limit(20)
  end

  def new
    defaults = current_user.simulation_defaults
    @simulation = SimulationSession.new(defaults.merge(
                                          mois_paie: Date.today.strftime("%Y-%m")
                                        ))
    @current_step = 0
    @tib_preview  = compute_tib_preview(@simulation)
  end

  def create
    @simulation = current_user.simulation_sessions.new(simulation_params)

    if @simulation.save
      result = @simulation.simulate!

      if result.errors.any?
        flash.now[:alert] = result.errors.join(", ")
        @current_step = 0
        @tib_preview = compute_tib_preview(@simulation)
        render :new, status: :unprocessable_entity
      else
        @simulation.update!(
          result_brut_total: result.brut_total,
          result_cotisations_total: result.cotisations_total,
          result_net_avant_pas: result.net_avant_pas,
          result_net_paye: result.net_paye,
          result_lines: result.lines.map { |l| l.transform_values(&:to_s) }
        )
        redirect_to simulation_path(@simulation), notice: "Simulation calculée avec succès."
      end
    else
      @current_step = 0
      @tib_preview = compute_tib_preview(@simulation)
      flash.now[:alert] = @simulation.errors.full_messages.first
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @result = @simulation.simulate!
  end

  def compare
    @result = @simulation.simulate!

    if request.post?
      @simulation.update!(
        real_lines: params[:real_lines]&.to_unsafe_h&.compact_blank,
        real_brut_total: params.dig(:real, :brut).presence,
        real_net_paye: params.dig(:real, :net).presence
      )
    end

    return unless @simulation.real_lines.present?

    @comparison = Iade::PayslipComparison.compare(
      simulated_result: @result,
      real_lines: @simulation.real_lines,
      real_totals: {
        brut: @simulation.real_brut_total,
        net: @simulation.real_net_paye
      }
    )
  end

  def tib_preview
    grade   = params[:grade] || "grade1"
    echelon = params[:echelon].to_i
    quotite = params[:quotite]&.to_d || BigDecimal("1.0")

    calc = Iade::TibCalculator.new(grade: grade, echelon: echelon, quotite: quotite)
    tib  = calc.compute

    render json: {
      indice_majore: calc.indice_majore,
      tib: tib.to_f.round(2),
      taux_horaire: calc.taux_horaire.to_f.round(4)
    }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_simulation
    @simulation = current_user.simulation_sessions.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to simulations_path, alert: "Simulation introuvable."
  end

  def compute_tib_preview(sim)
    calc = Iade::TibCalculator.new(grade: sim.grade, echelon: sim.echelon, quotite: sim.quotite || 1.0)
    tib  = calc.compute
    { indice_majore: calc.indice_majore, tib: tib, taux_horaire: calc.taux_horaire }
  rescue StandardError
    nil
  end

  def simulation_params
    params.require(:simulation).permit(
      :mois_paie, :statut, :grade, :echelon, :quotite, :type_cycle,
      :departement_code, :commune,
      :nb_enfants_sft, :garde_alternee, :sft_autre_parent,
      :nbi_points, :iss_montant, :dtc_montant, :wt1_montant,
      :taux_pas, :mutuelle,
      :has_prorata, :date_changement, :nature_changement,
      :heures_nuit, :nb_astreintes, :type_astreinte,
      :heures_dimanche, :heures_ferie,
      :tp7_qty, :it7_qty, :dhn_heures,
      :hs_jour_25, :hs_jour_50, :hs_jour_100,
      :hs_nuit_25, :hs_nuit_50, :hs_nuit_100,
      :confirm_decalage
    )
  end
end
