# Seed data for CI (GitHub Actions): a working admin login and one project covering every HTTP smoke test in
# test/*_smoke.sh. Not meant for anything but a throwaway CI container (no idempotency, no safety checks).
#
# Run after `rake db:migrate redmine:plugins:migrate redmine:load_default_data REDMINE_LANG=en`, with ADMIN_PASSWORD set:
#   ADMIN_PASSWORD=... bundle exec rails runner test/ci_seed.rb RAILS_ENV=production
raise 'set ADMIN_PASSWORD' if ENV['ADMIN_PASSWORD'].blank?
ActionMailer::Base.perform_deliveries = false # no SMTP in CI; issue/version creation would otherwise try to send mail

User.current = admin = User.find(1)
admin.password = admin.password_confirmation = ENV['ADMIN_PASSWORD']
admin.must_change_passwd = false
admin.language = 'en'
admin.save!(validate: false)
token = admin.api_token || Token.create!(user: admin, action: 'api')

project = Project.new(identifier: 'ci-test', name: 'CI test')
project.trackers = Tracker.all
project.enabled_module_names = %w[issue_tracking]
project.save!
tracker = project.trackers.first
today = User.current.today

def issue(project, tracker, subject, attrs = {})
  Issue.create!({:project => project, :tracker => tracker, :author => User.current, :subject => subject}.merge(attrs))
end

# test/not_planned_filter_smoke.sh: open issues covering every combination of start/due date, plus a closed one.
issue(project, tracker, 'NP no start', :due_date => today + 1)
issue(project, tracker, 'NP no due', :start_date => today)
issue(project, tracker, 'NP both dates')
issue(project, tracker, 'NP planned', :start_date => today, :due_date => today + 1)
closed_status = IssueStatus.where(:is_closed => true).first
issue(project, tracker, 'NP closed no dates').reload.update_column(:status_id, closed_status.id)

# test/planned_time_smoke.sh and test/roadmap_widget_smoke.sh: an estimated issue due today, an open version with a
# due date (so the widget has at least one bar/version to show) and a closed one (for the "show completed" toggle).
issue(project, tracker, 'PT today', :start_date => today, :due_date => today, :estimated_hours => 3)
Version.create!(:project => project, :name => 'CI open version', :effective_date => today + 10, :status => 'open')
Version.create!(:project => project, :name => 'CI closed version', :effective_date => today - 3, :status => 'closed')

puts "CI seed done. project=#{project.identifier} api_key=#{token.value}"
