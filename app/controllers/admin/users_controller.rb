module Admin
  class UsersController < Admin::BaseController
    def index
      @users = User.left_joins(:simulation_sessions)
                    .select("users.*, COUNT(simulation_sessions.id) AS simulations_count")
                    .group("users.id")
                    .order(:email)
    end

    def toggle_admin
      user = User.find(params[:id])

      if user == current_user
        redirect_to admin_users_path, alert: "Vous ne pouvez pas modifier vos propres droits admin."
        return
      end

      user.update!(admin: !user.admin?)
      notice = user.admin? ? "#{user.email} est désormais administrateur." : "#{user.email} n'est plus administrateur."
      redirect_to admin_users_path, notice: notice
    end
  end
end
