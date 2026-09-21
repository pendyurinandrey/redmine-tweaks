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

# Feature "calendar weeks": the Calendar block of "My page" shows 1-5 weeks (partial in app/views/redmine_tweaks).
unless Redmine::Helpers::Calendar.include?(RedmineTweaks::CalendarWeeks::CalendarPatch)
  Redmine::Helpers::Calendar.prepend(RedmineTweaks::CalendarWeeks::CalendarPatch)
  MyHelper.prepend(RedmineTweaks::CalendarWeeks::MyHelperPatch)
end
