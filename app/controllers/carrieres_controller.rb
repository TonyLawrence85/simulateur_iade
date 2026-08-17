class CarrieresController < ApplicationController
  before_action :authenticate_user!
  before_action :set_carriere_simulation, only: [:show]

  KIND_LABELS = {
    "promotion_2e_grade"    => "Promotion IADE 1er → 2e grade",
    "reclassement_ide_iade" => "Reclassement IDE → IADE",
    "reclassement_as_ide"   => "Reclassement Aide-soignant → IDE"
  }.freeze

  NEW_TEMPLATE_BY_KIND = {
    "promotion_2e_grade"    => :new_promotion,
    "reclassement_ide_iade" => :new_reclassement_ide,
    "reclassement_as_ide"   => :new_reclassement_as
  }.freeze

  PARAMS_BY_KIND = {
    "promotion_2e_grade" => %i[echelon_actuel mois_echelon_actuel mois_debut_cat_a
                                periode_exclue periode_debut periode_fin],
    "reclassement_ide_iade" => %i[situation_actuelle grade_source echelon_source mois_echelon_source
                                   mois_nomination zone_paris nb_enfants_sft dtc_choix dtc_montant],
    "reclassement_as_ide" => %i[situation_actuelle statut_administratif grade_source echelon_source
                                 mois_echelon_source mois_nomination zone_paris nb_enfants_sft dtc_choix dtc_montant]
  }.freeze

  def index
    @carriere_simulations = current_user.carriere_simulations.recent.limit(50)
  end

  def show; end

  def new_promotion
    @carriere_simulation = CarriereSimulation.new(kind: "promotion_2e_grade")
  end

  def new_reclassement_ide
    @carriere_simulation = CarriereSimulation.new(kind: "reclassement_ide_iade")
  end

  def new_reclassement_as
    @carriere_simulation = CarriereSimulation.new(kind: "reclassement_as_ide")
  end

  def create
    kind = params[:kind].to_s
    unless CarriereSimulation::KINDS.include?(kind)
      redirect_to carrieres_path, alert: "Type de simulation inconnu." and return
    end

    @carriere_simulation = current_user.carriere_simulations.new(kind: kind, inputs: carriere_params(kind))

    if @carriere_simulation.save
      redirect_to carriere_path(@carriere_simulation), notice: "Simulation calculée."
    else
      flash.now[:alert] = @carriere_simulation.errors.full_messages.join(" · ")
      render NEW_TEMPLATE_BY_KIND.fetch(kind), status: :unprocessable_entity
    end
  end

  private

  def carriere_params(kind)
    params.require(:carriere_simulation).permit(PARAMS_BY_KIND.fetch(kind, [])).to_h
  end

  def set_carriere_simulation
    @carriere_simulation = current_user.carriere_simulations.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to carrieres_path, alert: "Simulation introuvable."
  end
end
