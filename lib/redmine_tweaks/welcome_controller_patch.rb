# frozen_string_literal: true

module RedmineTweaks
  # Feature "start page": a logged-in user who opens the home page (`/`, the "Home" link of the top menu) is sent to "My page".
  #
  # The callback is added to WelcomeController, so it runs after Redmine's own filters (login requirement, password change,
  # two-factor activation, localization): those still decide first. Anonymous visitors (when the site allows them) keep
  # the ordinary home page. The `robots` action is not touched.
  module WelcomeControllerPatch
    def self.prepended(base)
      base.before_action :redirect_home_to_my_page, only: :index
    end

    private

    def redirect_home_to_my_page
      redirect_to my_page_path if User.current.logged?
    end
  end
end
