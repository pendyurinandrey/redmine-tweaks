# frozen_string_literal: true

# Feature "operational plan": the block's settings form, rendering and links. Ported from
# test/roadmap_widget_smoke.sh, which this replaces. The filtering/sorting itself is unit-tested in
# test/unit/roadmap_widget_test.rb.
require_relative '../../../../test/test_helper'

class RedmineTweaks::RoadmapWidgetIntegrationTest < Redmine::IntegrationTest
  def setup
    Role.non_member.remove_permission!(:view_issues)
    role = Role.generate!(:permissions => [:view_issues, :manage_versions])
    @user = User.generate!(:password => 'Roadmap-Test-2026', :password_confirmation => 'Roadmap-Test-2026')
    User.current = @user
    @project = Project.generate!(:is_public => false)
    User.add_to_project(@user, @project, role)
    @open   = Version.generate!(:project => @project, :name => 'Open version',   :effective_date => @user.today + 5, :status => 'open')
    @closed = Version.generate!(:project => @project, :name => 'Closed version', :status => 'closed')
    @project.trackers = [tracker = Tracker.generate!]
    @project.save!
    Issue.generate!(:project => @project, :tracker => tracker, :author => @user, :fixed_version => @open, :estimated_hours => 5)
    closed_issue = Issue.generate!(:project => @project, :tracker => tracker, :author => @user, :fixed_version => @open, :estimated_hours => 8)
    closed_issue.update_column(:status_id, IssueStatus.where(:is_closed => true).first.id)
    User.current = nil

    log_user(@user.login, 'Roadmap-Test-2026')
    post '/my/add_block', :params => {:block => 'roadmap'}
  end

  def test_the_block_and_its_settings_form_are_on_my_page
    get '/my/page'
    assert_select '#block-roadmap'
    assert_select '#roadmap-settings'
    assert_select '#roadmap-project option', :text => @project.name
  end

  def test_open_versions_shown_by_default_closed_only_with_show_completed
    get '/my/page'
    assert_select '.version-article', 1
    assert_select '.badge-status-closed', 0

    save_settings(:show_completed => '1')
    get '/my/page'
    assert_select '.version-article', 2
    assert_select '.badge-status-closed', 1
  end

  def test_shows_the_estimated_open_hours_next_to_the_closed_open_counts
    get '/my/page'
    assert_select '.rt-roadmap-estimate', :text => /5(\.0|,0)? h/, :count => 1

    User.current = @user
    Version.generate!(:project => @project, :name => 'No issues', :status => 'open')
    User.current = nil
    get '/my/page'
    assert_select '.rt-roadmap-estimate', :text => /0 h/
  end

  def test_a_version_s_own_link_opens
    get '/my/page'
    link = css_select('.version-article a[href^="/versions/"]').first['href']
    get link
    assert_response :success
  end

  private

  def save_settings(settings)
    post '/my/page', :params => {:settings => {:roadmap => settings}}, :xhr => true
    assert_response :success
  end
end
