# frozen_string_literal: true

module RedmineTweaks
  class Hooks < Redmine::Hook::ViewListener
    # Texts the JavaScript needs (translated server-side, so no JS changes are needed for a new language)
    I18N_KEYS = {
      edit_description:   :label_tweaks_edit_description,
      discard_changes:    :text_tweaks_discard_changes
    }.freeze

    # Feature "quick edit description": a pencil next to the description on the issue page.
    # Only the issue page needs the assets.
    def view_layouts_base_html_head(context)
      controller = context[:controller]
      return '' unless controller.is_a?(IssuesController) && controller.action_name == 'show'
      return '' unless User.current.logged?

      view = context[:hook_caller]
      texts = I18N_KEYS.transform_values { |key| I18n.t(key) }
      view.tag(:meta, name: 'redmine-tweaks', content: texts.to_json) +
        view.stylesheet_link_tag('redmine_tweaks', plugin: 'redmine_tweaks') +
        view.javascript_include_tag('redmine_tweaks', plugin: 'redmine_tweaks')
    end
  end
end
