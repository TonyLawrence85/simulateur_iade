class ApplicationController < ActionController::Base
  CANONICAL_HOST = "www.verifie-paie-soignant.fr"

  before_action :redirect_to_canonical_host
  before_action :authenticate_user!

  private

  def redirect_to_canonical_host
    return unless Rails.env.production?
    return if request.host == CANONICAL_HOST

    redirect_to "https://#{CANONICAL_HOST}#{request.fullpath}",
                status: :moved_permanently, allow_other_host: true
  end
end
