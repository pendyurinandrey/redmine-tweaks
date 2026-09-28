# redmine-tweaks — context for Claude

Repository: `pendyurinandrey/redmine-tweaks`. A Redmine plugin, `redmine_tweaks` — small, independent UI
improvements (each feature is its own file/partial, no core patches except a few documented extension points — see
README "Compatibility notes"). The local stand for manual checking is `personal-infra/Redmine/local/redmine.sh`
(`TWEAKS_DEV_DIR=…`), but it is not needed for the tests described here.

## Mandatory rules when working on this code

- **Run the existing test suite before considering a change done.** Even when only one feature was touched — several
  features share the same helpers (`RedmineTweaks::*`), and a regression in one can silently break another. Running
  the whole suite takes seconds (see "How to run the tests" below); always worth it.
- **Every new feature or bug fix must come with a test.** Not "nice to have" — a change without a test on the new
  logic is not considered finished. Even a pure CSS/markup feature with no branching logic needs at least one
  integration test confirming the element is actually on the page (see the template below) — markup breaks silently
  more often than it seems like it would.
- Write the test in the same change, not "later, as a separate commit" — otherwise it very likely never happens.

## How to run the tests

```bash
node --test test/*.test.js                                        # JS logic (test/*.test.js), no dependencies
RAILS_ENV=test bundle exec rake redmine:plugins:test NAME=redmine_tweaks   # the whole Ruby suite (test/unit, test/integration)
```

The second command needs a Redmine 6 checkout with this repository symlinked or copied into `plugins/redmine_tweaks`,
a test database (`RAILS_ENV=test bundle exec rake db:migrate redmine:plugins:migrate`), and the full gem set (the
official `redmine:6` image ships without the `test` group: `bundle config set without ''` before `bundle install`,
plus `build-essential` for native gems). This is exactly how `.github/workflows/test.yml` (job `ruby-tests`) does
it — copy its steps if you need to reproduce the setup.

Running a single file: `bundle exec rails test plugins/redmine_tweaks/test/integration/<name>_test.rb`.

## How to write tests for this plugin

Ruby tests for this plugin are ordinary Rails/Minitest tests under `test/{unit,functional,integration}/*_test.rb`,
run by Redmine core's own `redmine:plugins:test` task (nothing custom to run them is needed). This is the **correct
way**, in place of the curl/grep-over-HTML bash scripts the plugin used to be covered by (see git history) — these
tests run in-process, with no live server, no race between HTTP requests, and no fragile HTML scraping.

### Structure: unit vs integration

- **`test/unit/<feature>_test.rb`** (`< ActiveSupport::TestCase`) — for features with non-trivial calculation logic
  (`RedmineTweaks::PlannedTime`, `RedmineTweaks::RoadmapWidget`, etc.): test the class directly, no HTTP. Faster,
  easier to debug, easier to write exact assertions for.
- **`test/integration/<feature>_test.rb`** (`< Redmine::IntegrationTest`) — for what the user actually sees: the
  block's settings form, the fact that a filter/widget is registered, rendering, links, response codes, redirects
  (`get`/`post`, `assert_select`, `assert_response`, `assert_redirected_to`).
- If a feature has its own calculation class, cover the calculation with a unit test and the rendering/HTTP wiring
  with a separate, shorter integration test (see `planned_time`/`roadmap_widget` as the template: logic and the
  HTTP layer live in different files).

### The required file template

```ruby
# frozen_string_literal: true

# Feature "<name>" (see lib/redmine_tweaks/<file>.rb): <one line on what the feature does>.
require_relative '../../../../test/test_helper'

class RedmineTweaks::<Name>Test < Redmine::IntegrationTest   # or ActiveSupport::TestCase for a unit test
  def setup
    ...
  end

  def test_<a_specific_scenario>
    ...
  end
end
```

The `require_relative` path is always the same (4 levels up from `plugins/redmine_tweaks/test/{unit,integration}/`
to core's `test/test_helper.rb`) — don't change it when moving a test between `unit` and `integration`.

### Test data: factories, not core fixtures

Don't rely on core's existing fixtures (`Project.find(1)`, `User.find(2)`, etc.) — they exist for Redmine's own test
suite and could change at any time. Use the helpers from `test/object_helpers.rb` instead, already available
(`Redmine::IntegrationTest`/`ActiveSupport::TestCase` pull in `test_helper.rb`, which pulls in `ObjectHelpers`):

```ruby
User.generate!(:password => '…', :password_confirmation => '…')
Project.generate!(:is_public => false)
Tracker.generate!
Issue.generate!(:project => project, :tracker => tracker, :author => user, :subject => '…', :estimated_hours => 3)
Version.generate!(:project => project, :name => '…', :effective_date => Date.today + 5, :status => 'open')
Role.generate!(:permissions => [:view_issues, :manage_versions])
User.add_to_project(user, project, role)
```

`fixtures :all` is still loaded at the `ActiveSupport::TestCase` level regardless (that's set by core's own
`test_helper.rb`; it cannot be turned off for a single file) — but your own test data doesn't need to use it, only
avoid colliding with it.

### Pitfall: core fixtures are visible to any user once a feature looks across several projects

Core's fixtures include public projects (`eCookbook` etc.) with issues and versions whose dates are **deliberately
shifted relative to today** (confirmed by observation — a fixture issue routinely lands right around "today", so
that Redmine's own date-based features have something to exercise in its own tests). A public project is visible to
**any** user by default via the "Non member" role's `view_issues` permission — even a user just created with
`User.generate!`, with no membership at all. Any feature that looks not at one specific project but at "everything
the user can see" (`RedmineTweaks::PlannedTime`, `RedmineTweaks::RoadmapWidget`) will, in a test, pick up a mix of
its own test data and these fixtures — exact assertions on sums/counts then break at random.

Fixed the same way core's own tests fix it (see `test/unit/issue_test.rb` in Redmine):

```ruby
Role.non_member.remove_permission!(:view_issues)   # in setup, no need to restore — the test's transaction rolls it back
@project = Project.generate!(:is_public => false)  # + explicit membership for the test user
```

Features scoped to one project (like `not_planned_filter`) don't hit this — there, `IssueQuery.new(:project => @project, …)` is already enough.

### Another pitfall: `Issue.create!(...).update_column(...)` chained in one line

`update_column` includes `lock_version` in its `WHERE` clause, and a just-created (`Issue.create!`) in-memory object
may not know about a `lock_version` bump that happened via a raw-SQL side effect of the nested-set callback
(`acts_as_nested_set`) — `update_column` then silently does nothing (returns `false`, no exception). `Issue.generate!`
from `object_helpers.rb` already calls `.reload` itself, so creating through the factory avoids this. If you create
an `Issue` by hand (`Issue.create!`) and immediately change its status via `update_column`, `.reload` first:

```ruby
issue.reload.update_column(:status_id, IssueStatus.where(:is_closed => true).first.id)
```

### Other practical notes

- CSRF protection is disabled in the test environment (`config/environments/test.rb`) — no need to extract tokens,
  `post`/`get` work as-is.
- Log a user in inside an integration test with `log_user(login, password)` (from `Redmine::IntegrationTest`), not a
  manual `POST` to `/login`.
- Add a "My page" block with `post '/my/add_block', :params => {:block => 'name'}`; change its settings with
  `post '/my/page', :params => {:settings => {:name => {...}}}, :xhr => true`.
- A fresh `IssueQuery.new` already has a default filter of `status_id = "open"` (not an empty filter set!) — if a
  test needs to see issues of every status, clear it explicitly: `query.filters = {}` before adding your own filters.
- `assert_select 'selector', N, "message"` takes three positional arguments (selector, expected count/content,
  message); `assert_select 'selector', "message"` without a count is **not** "selector + message" — the second
  argument is read as the expected content. For a message with no count check, pass `:count => N` explicitly, or
  just leave the message as a comment instead.
