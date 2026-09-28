# frozen_string_literal: true

# Feature "operational plan" widget for "My page": open versions across every visible project (not one project's own
# Roadmap), sorted by due date, using the core "versions/overview" partial for each. The view is
# app/views/my/blocks/_roadmap.html.erb (Redmine registers every partial there as a My page block).
module RedmineTweaks
  class RoadmapWidget
    attr_reader :project_id

    # settings: the block's settings hash (values are strings, keys may be symbols or strings)
    def initialize(user, settings)
      settings = (settings || {}).to_h.symbolize_keys
      @user = user
      @project_id = settings[:project_id].presence&.to_i
      @show_completed = settings[:show_completed].to_s == '1'
    end

    def show_completed?
      @show_completed
    end

    # Projects that have at least one version visible to the user (open or completed): the choices for the filter
    def projects
      @projects ||= Project.where(id: Version.visible(@user).select(:project_id)).sorted.to_a
    end

    def versions
      @versions ||= begin
        scope = Version.visible(@user).includes(:project)
        scope = show_completed? ? scope : scope.open
        scope = scope.where(project_id: project_id) if project_id
        # NULLS LAST on every supported database: a version without a due date sorts after every dated one
        scope.to_a.sort_by {|v| [v.effective_date ? 0 : 1, v.effective_date || v.created_on, v.name]}
      end
    end
  end
end
