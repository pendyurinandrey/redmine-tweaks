# frozen_string_literal: true

require_relative 'lib/redmine_tweaks/hooks'

Redmine::Plugin.register :redmine_tweaks do
  name        'Redmine Tweaks'
  description 'Small quality-of-life improvements for Redmine (each one is a separate, self-contained feature)'
  url         'https://github.com/pendyurinandrey/redmine-tweaks'
  author      'Andrey Pendyurin'
  version     '0.1.0'

  requires_redmine version_or_higher: '6.0.0'
end
