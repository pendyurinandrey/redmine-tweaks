# frozen_string_literal: true

# Feature "operational plan" widget: the data behind it (lib/redmine_tweaks/roadmap_widget.rb), tested directly.
# See test/integration/roadmap_widget_test.rb for the block's settings form and rendering.
require_relative '../../../../test/test_helper'

class RedmineTweaks::RoadmapWidgetTest < ActiveSupport::TestCase
  def setup
    # Isolated from Redmine's own public fixture projects/versions the same way test/unit/planned_time_test.rb is;
    # this widget also looks across every project the user can see.
    Role.non_member.remove_permission!(:view_issues)
    role = Role.generate!(:permissions => [:view_issues])
    User.current = @user = User.generate!

    @project_a = Project.generate!(:is_public => false, :name => 'Alpha')
    @project_b = Project.generate!(:is_public => false, :name => 'Beta')
    [@project_a, @project_b].each { |p| User.add_to_project(@user, p, role) }
    @today = @user.today

    @near   = Version.generate!(:project => @project_a, :name => 'A near',   :effective_date => @today + 5,  :status => 'open')
    @far    = Version.generate!(:project => @project_b, :name => 'B far',    :effective_date => @today + 20, :status => 'open')
    @nodate = Version.generate!(:project => @project_a, :name => 'A nodate', :status => 'open')
    @done   = Version.generate!(:project => @project_b, :name => 'B done',   :effective_date => @today - 3,  :status => 'closed')
  end

  def widget(settings = {})
    RedmineTweaks::RoadmapWidget.new(@user, settings)
  end

  def test_open_versions_only_by_default
    ids = widget.versions.map(&:id)
    assert_includes ids, @near.id
    assert_includes ids, @far.id
    assert_includes ids, @nodate.id
    assert_not_includes ids, @done.id
  end

  def test_show_completed_includes_closed_versions_too
    ids = widget(:show_completed => '1').versions.map(&:id)
    assert_includes ids, @done.id
  end

  def test_sorted_by_due_date_ascending_with_no_date_last
    names = widget(:show_completed => '1').versions.map(&:name)
    assert_equal ['B done', 'A near', 'B far', 'A nodate'], names
  end

  def test_project_filter_restricts_to_that_project_s_own_versions
    ids = widget(:project_id => @project_a.id, :show_completed => '1').versions.map(&:id)
    assert_equal [@near.id, @nodate.id].sort, ids.sort
  end

  def test_projects_lists_only_projects_that_have_a_visible_version
    other = Project.generate!(:is_public => false)
    User.add_to_project(@user, other, Role.generate!(:permissions => [:view_issues]))
    assert_not_includes widget.projects.map(&:id), other.id, 'a project with no versions should not be offered in the filter'
    assert_includes widget.projects.map(&:id), @project_a.id
  end
end
