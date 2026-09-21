# frozen_string_literal: true

require_relative 'lib/redmine_tweaks/hooks'

Redmine::Plugin.register :redmine_tweaks do
  name        'Redmine Tweaks'
  description 'Small quality-of-life improvements for Redmine (each one is a separate, self-contained feature)'
  url         'https://github.com/pendyurinandrey/redmine-tweaks'
  author      'Andrey Pendyurin'
  version     '0.2.0'

  requires_redmine version_or_higher: '6.0.0'
end

# Feature "start page": `/` opens "My page" for logged-in users.
# Redmine executes every plugin's init.rb inside its own `to_prepare` callback (and again after each code reload in
# development), so the patch is applied right here; a nested `to_prepare` would never run.
unless WelcomeController.include?(RedmineTweaks::WelcomeControllerPatch)
  WelcomeController.prepend(RedmineTweaks::WelcomeControllerPatch)
end
