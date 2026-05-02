class ApplicationController < ActionController::Base
     before_action :configure_permitted_parameters, if: :devise_controller?
     before_action :http_basic_authenticate
  protected

  def after_sign_in_path_for(resource)
    root_path
  end


  
  private
# ✅ サイト認証（HTTPベーシック認証）
def http_basic_authenticate
  authenticate_or_request_with_http_basic("Restricted Area") do |user, pass|
    ActiveSupport::SecurityUtils.secure_compare(user.to_s, ENV.fetch("BASIC_AUTH_USER", "test")) &&
      ActiveSupport::SecurityUtils.secure_compare(pass.to_s, ENV.fetch("BASIC_AUTH_PASSWORD", "testpass2"))
  end
end
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :occupation, :age, :avatar, :authority_answer])
  end
end
