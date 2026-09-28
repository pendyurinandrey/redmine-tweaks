# frozen_string_literal: true

# Feature "not planned" issue filter (see lib/redmine_tweaks/not_planned_filter.rb): an issue-list filter for issues
# missing a start date or a due date. Ported from the bash/curl version, test/not_planned_filter_smoke.sh, which this
# replaces: same scenarios, but run in-process against Redmine's own test fixtures instead of a live HTTP server.
require_relative '../../../../test/test_helper'

class RedmineTweaks::NotPlannedFilterTest < Redmine::IntegrationTest
  fixtures :trackers, :issue_statuses, :enumerations

  def setup
    # Admin bypasses permissions and issue workflow, so a project of our own (kept apart from the shared fixture
    # projects and their pre-existing issues) is all the test data these scenarios need.
    User.current = @admin = User.find(1)
    @project = Project.create!(:name => 'NP filter test', :identifier => 'np-filter-test')
    @project.trackers = [@tracker = Tracker.find(1)]
    @project.save!
    @today = @admin.today

    @no_start = new_issue('NP no start',   :due_date => @today + 1)
    @no_due   = new_issue('NP no due',     :start_date => @today)
    @neither  = new_issue('NP neither')
    @planned  = new_issue('NP planned',    :start_date => @today, :due_date => @today + 1)
    @closed   = new_issue('NP closed no dates')
    @closed.reload.update_column(:status_id, IssueStatus.where(:is_closed => true).first.id)
  end

  def teardown
    User.current = nil
  end

  def test_available_filter_is_registered
    query = IssueQuery.new(:project => @project)
    assert query.available_filters.key?('not_planned'), 'the "not_planned" filter should be offered on the issue list'
  end

  def test_yes_matches_issues_missing_either_date
    ids = not_planned_issue_ids('=', ['1'])
    assert_includes ids, @no_start.id
    assert_includes ids, @no_due.id
    assert_includes ids, @neither.id
    assert_includes ids, @closed.id
    assert_not_includes ids, @planned.id
  end

  def test_no_matches_issues_with_both_dates
    ids = not_planned_issue_ids('=', ['0'])
    assert_includes ids, @planned.id
    assert_not_includes ids, @no_start.id
    assert_not_includes ids, @no_due.id
    assert_not_includes ids, @neither.id
    assert_not_includes ids, @closed.id
  end

  def test_yes_and_no_partition_every_issue_with_no_overlap
    yes = not_planned_issue_ids('=', ['1'])
    no  = not_planned_issue_ids('=', ['0'])
    all = [@no_start, @no_due, @neither, @planned, @closed].map(&:id)

    assert_equal [], yes & no, 'an issue must not be counted as both planned and not planned'
    assert_equal all.sort, (yes + no).sort, 'every issue in the project must fall on exactly one side'
  end

  def test_combines_with_status_filter_as_usual_and
    open_ids = not_planned_issue_ids('=', ['1'], 'status_id' => ['o'])
    assert_not_includes open_ids, @closed.id, 'a closed issue must be excluded once Status = open is also applied'

    any_ids = not_planned_issue_ids('=', ['1'], 'status_id' => ['*'])
    assert_includes any_ids, @closed.id
  end

  private

  # Builds an IssueQuery the way the issue list controller would from request params, and returns the matching ids.
  # extra_filters: {field => [operator, values]} (status_id needs operator "o"/"*", not "=").
  def not_planned_issue_ids(operator, values, extra_filters = {})
    query = IssueQuery.new(:project => @project, :name => '_')
    query.filters = {} # a fresh Query defaults to Status = open; these scenarios care about every status unless asked
    query.add_filter('not_planned', operator, values)
    extra_filters.each { |field, v| query.add_filter(field, v.first, [v[1] || '']) }
    query.issues.map(&:id)
  end

  def new_issue(subject, attrs = {})
    Issue.create!({:project => @project, :tracker => @tracker, :author => @admin, :subject => subject}.merge(attrs))
  end
end
