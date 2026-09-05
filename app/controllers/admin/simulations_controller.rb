module Admin
  class SimulationsController < Admin::BaseController
    def index
      @simulations = SimulationSession.includes(:user).recent
    end

    def show
      @simulation = SimulationSession.find_by!(token: params[:id])
    end
  end
end
