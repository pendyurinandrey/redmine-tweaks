# frozen_string_literal: true

# Feature "planned time": the calculation itself (lib/redmine_tweaks/planned_time.rb), tested directly and without any
# HTTP layer. See test/integration/planned_time_test.rb for the block's settings form and rendering.
require_relative '../../../../test/test_helper'

class RedmineTweaks::PlannedTimeTest < ActiveSupport::TestCase
  def setup
    # PlannedTime looks across every project the user can see, and Redmine's core fixtures include public projects
    # with issues deliberately date-shifted to "today" (to exercise date-based features like this one) -- visible,
    # by default, to any logged-in user via the "Non member" role. Both are neutralized the way core's own tests do
    # it, so this project's issues are the only ones the generated user can see and totals below are exact.
    Role.non_member.remove_permission!(:view_issues)
    @project = Project.generate!(:is_public => false)
    @project.trackers = [@tracker = Tracker.generate!]
    @project.save!
    role = Role.generate!(:permissions => [:view_issues, :add_issues])
    User.current = @user = User.generate!
    User.add_to_project(@user, @project, role)
    other_user = User.generate!
    User.add_to_project(other_user, @project, role)
    @today = @user.today

    @same_day          = new_issue('same day, estimated', :start_date => @today, :due_date => @today, :estimated_hours => 3, :assigned_to => @user)
    @same_day_no_est   = new_issue('same day, no estimate', :start_date => @today, :due_date => @today)
    @same_day_zero_est = new_issue('same day, zero estimate', :start_date => @today, :due_date => @today, :estimated_hours => 0)
    @closed            = new_issue('same day, closed', :start_date => @today, :due_date => @today, :estimated_hours => 4)
    @closed.update_column(:status_id, IssueStatus.where(:is_closed => true).first.id)
    @other_assignee    = new_issue('same day, other assignee', :start_date => @today, :due_date => @today,
                                    :estimated_hours => 2, :assigned_to => other_user)
    @multi_day         = new_issue('multi-day, estimated', :start_date => @today, :due_date => @today + 2, :estimated_hours => 6)
  end

  def test_only_same_day_open_estimated_issues_are_summed_across_every_assignee
    today = plans(7).day_list.first
    assert_equal @today, today.date
    # same_day (3h) + other_assignee (2h) = 5h; closed (4h) and multi_day (6h) must not contribute
    assert_equal 5, today.hours
  end

  def test_without_estimate_counts_nil_and_zero_separately_from_the_estimated_ones
    today = plans(7).day_list.first
    assert_equal 2, today.count, 'the two same-day issues that DO have a positive estimate'
    assert_equal 2, today.without_estimate, 'a nil estimate and a zero estimate both count as "without estimate"'
  end

  def test_assignee_filter_restricts_to_that_user
    today = plans(7, :assignee_id => @user.id).day_list.first
    assert_equal 3, today.hours, 'only the current user\'s own estimated issue should be counted'
    assert_equal 1, today.count
  end

  def test_multi_day_issues_are_not_counted_but_are_reported_in_the_note
    pt = RedmineTweaks::PlannedTime.new(@user, {})
    assert_equal 5, pt.day_list.sum(&:hours), 'the multi-day issue\'s 6h must not appear on any day'
    assert_equal 1, pt.multi_day[:count]
    assert_equal 6.0, pt.multi_day[:hours]
  end

  def test_days_is_clamped_to_7_and_14
    assert_equal 7,  RedmineTweaks::PlannedTime.new(@user, {:days => '3'}).days
    assert_equal 14, RedmineTweaks::PlannedTime.new(@user, {:days => '99'}).days
    assert_equal 7,  RedmineTweaks::PlannedTime.new(@user, {:days => 'abc'}).days
    assert_equal 10, RedmineTweaks::PlannedTime.new(@user, {:days => '10'}).days
  end

  def test_norm_is_enabled_by_default_with_a_fallback_of_8_hours
    assert RedmineTweaks::PlannedTime.new(@user, {}).norm_enabled?
    assert_equal 8.0, RedmineTweaks::PlannedTime.new(@user, {}).norm_hours
    assert_not RedmineTweaks::PlannedTime.new(@user, {:norm_enabled => '0'}).norm_enabled?
    assert_equal 6.5, RedmineTweaks::PlannedTime.new(@user, {:norm_hours => '6,5'}).norm_hours, 'a decimal comma must be accepted'
    assert_equal 8.0, RedmineTweaks::PlannedTime.new(@user, {:norm_hours => '-3'}).norm_hours, 'a non-positive value falls back to 8'
  end

  private

  def plans(days, settings = {})
    RedmineTweaks::PlannedTime.new(@user, {:days => days.to_s}.merge(settings))
  end

  def new_issue(subject, attrs = {})
    Issue.generate!({:project => @project, :tracker => @tracker, :author => @user, :subject => subject}.merge(attrs))
  end
end
