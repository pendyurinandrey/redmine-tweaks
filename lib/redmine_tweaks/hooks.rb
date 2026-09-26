# frozen_string_literal: true

module RedmineTweaks
  class Hooks < Redmine::Hook::ViewListener
    # Texts the JavaScript needs (translated server-side, so no JS changes are needed for a new language)
    I18N_KEYS = {
      edit_description:   :label_tweaks_edit_description,
      discard_changes:    :text_tweaks_discard_changes,
      checklist_unsaved_changes: :text_tweaks_checklist_unsaved_changes
    }.freeze

    # Features on the issue page: "quick edit description" (a pencil next to the description) and
    # "clickable task-list checkboxes". Only the issue page needs the assets.
    def view_layouts_base_html_head(context)
      controller = context[:controller]
      view = context[:hook_caller]
      # "planned time" widget of My page (pure CSS, no scripts)
      if controller.is_a?(MyController) && controller.action_name == 'page'
        return view.stylesheet_link_tag('planned_time', plugin: 'redmine_tweaks')
      end
      return '' unless controller.is_a?(IssuesController) && controller.action_name == 'show'
      return '' unless User.current.logged?

      texts = I18N_KEYS.transform_values { |key| I18n.t(key) }
      view.tag(:meta, name: 'redmine-tweaks', content: texts.to_json) +
        view.stylesheet_link_tag('redmine_tweaks', plugin: 'redmine_tweaks') +
        view.javascript_include_tag('tweaks_common', 'quick_edit_description', 'task_list_toggle', plugin: 'redmine_tweaks')
    end
  end
end
