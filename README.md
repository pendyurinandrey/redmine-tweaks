# Redmine Tweaks

Small quality-of-life improvements for Redmine. Every improvement is a separate, self-contained feature (its own JS/CSS,
no core patches), so the plugin can grow without becoming hard to maintain.

Requires Redmine 6.0 or newer. Tested on Redmine 6.1.4 with the default set of plugins and the [Opale](https://github.com/gagnieray/opale) theme, on desktop and phone widths.

## Features

### Quick edit description

On an issue page a **pencil** appears next to the **Description** label. One click opens Redmine's edit form, expands the
description editor (normally hidden behind a second "Edit" link), scrolls to it and puts the cursor at the end of the text.
Issues without a description get a slim "Description ✎" row so a description can be added the same way.

* Nothing is re-implemented: saving, preview, attachments, the version lock and the history are Redmine's own.
* The pencil is shown **only to users who may edit the description** (the editor exists in the page only for them).
* **Leaving the edit mode**
  * **Esc** in a text field of the form: closes the form and restores the saved values; if something was changed, it asks first
    (`Discard the unsaved changes?`). Esc is ignored while the @-mention menu is open (it closes the menu first).
  * Redmine's own **Cancel** link: hides the form and keeps what was typed (as before).
  * **Ctrl/Cmd+Enter** in any text area saves (this is Redmine core behavior).
* Localized: English and Russian (`config/locales`); the texts reach the script from the server, other languages need only a YAML file.

### Clickable checkboxes in the description

Task lists in the description (`- [ ] item` / `- [x] item`, CommonMark) are rendered by Redmine as **disabled** checkboxes, so ticking an
item means opening the editor, changing `[ ]` to `[x]` by hand and saving. With this feature the checkboxes are **clickable** for users who may
edit the description: a click flips that marker in the source and submits Redmine's own issue form (the reader stays at the same scroll position).

* It is a normal update: the version lock is checked, the history gets a "Description updated" entry (**every toggle adds one**), notifications work as usual.
* Only CommonMark text is supported (Textile has no task lists in Redmine).
* **Safe by construction** — a checkbox stays disabled, exactly as in stock Redmine, when
  * the user may not edit the description;
  * the number of `[ ]`/`[x]` markers found in the description source differs from the number of rendered checkboxes, or a state disagrees
    (for example checkboxes produced by an `{{include}}` macro or unusual code blocks) — the mapping would not be trustworthy;
  * at click time the issue form has other unsaved changes (a typed comment must not be sent by accident): the click is reverted with a hint.
* Markers inside fenced code blocks and inline code are ignored, exactly as Redmine does not render them as checkboxes.
* Localized (English, Russian) like the other messages.

### Start page: "My page"

By default `/` shows Redmine's "Home" page, which on a fresh installation is only a generic welcome text. With this feature a **logged-in user who opens `/`
(or the "Home" link) is redirected to "My page"** (`/my/page`); logging in already lands there in stock Redmine, so the two now agree.

* Anonymous visitors are not affected: with *Authentication required* they get the login page as before, on a site that allows anonymous access they see the normal home page.
* Users who must change their password first are still sent to the password form (Redmine checks that before the redirect).
* `robots.txt`, the API and every other route are untouched; only `WelcomeController#index` gets a `before_action`.
* The column order of the blocks on "My page" is a built-in Redmine setting (block menu → *Options* → *Selected columns*), nothing to install for that.

### Calendar block: 1 to 5 weeks

The **Calendar** block of "My page" shows only the current week. With this feature the block gets an **Options** (gear) button with a **Date range** selector: **1 to 5 weeks**,
starting with the current week (the default is still 1 week, so nothing changes until you choose). The choice is stored per user in the block settings, exactly like the other
blocks' settings (for example the number of days of the "Spent time" block).

* Idea and the original core patch: [Redmine issue #26525](https://www.redmine.org/issues/26525). It is re-implemented as a plugin patch instead of a core patch, so it survives upgrades and needs no rebuilding of Redmine.
* Values outside 1..5 are clamped; issues are selected for the whole displayed period and follow the usual visibility rules.
* Localized (English, Russian).

### "Not planned" issue filter

Redmine's own filters can only be ANDed together, so "start date is blank OR due date is blank" cannot be built from two ordinary
filters. This feature adds a single **Not planned** filter (Issues → Filters → *Add filter*) with values **Yes**/**No**: *Yes* matches
issues where the start date, the due date, or both are missing; *No* matches issues where both are set.

* Implemented the way Redmine's own core implements similar cases (`is_private`, `parent_id`, …): a "virtual" filter field
  (`IssueQuery#initialize_available_filters` + `#sql_for_not_planned_field`), not a change to how filters are combined in general —
  so it needs no changes anywhere else and combines with every other filter (Status, Project, …) exactly as usual.
* Works wherever `IssueQuery` does: the issue list, a project's issue list, the REST API (`/issues.json?...&f[]=not_planned&op[not_planned]=%3D&v[not_planned][]=1`).
* Can be saved as a query like any other filter combination (for example together with Status = open) for one-click reuse.
* Localized (English, Russian).

### "Planned time" widget for My page

A new **Planned time** block (My page → *Add*) draws a bar chart, one bar per day, starting with **today**: **7 days by default, 7 to 14 selectable** in the block's *Options*.
A bar is the sum of *Estimated time* of the open issues whose **start date and due date both equal that day** (issues without an estimate, or with 0, add nothing).

* **Hover** (or keyboard focus) shows a tooltip: the date, planned hours as a plain decimal (e.g. `5.5 h`), the number of issues, how many issues have **no estimate**, and by how much the day is over the norm.
* **Click** a bar to open the issue list of that day (open issues with that start and due date, the assignee filter included).
* **Options:** days (7-14), **assignee** (all by default, or one user), and an optional **daily norm line** (on by default, 8 hours, any value up to 24; untick to hide it). Days over the norm are drawn in red.
* Only each issue's **own** estimate is summed (parents and subtasks are not added together). Closed issues and issues you cannot see are ignored. All days are treated as working days.
* **Multi-day issues are not counted** (a start date different from the due date): the widget shows a note with how many such issues with an estimate fall into the period and their hours, so nothing disappears silently. Split them into one-day subtasks.
* Pure server-rendered HTML/CSS: no scripts, no chart library. It is a Redmine "additional block": any partial in a plugin's `app/views/my/blocks/` becomes a My page block, so nothing is patched.
* Localized (English, Russian).

## Installation

The repository is called `redmine-tweaks`, but the plugin directory **must be named exactly `redmine_tweaks`** (that is the plugin id), so give the target directory explicitly:

```bash
cd /path/to/redmine/plugins
git clone --branch v0.4.0 https://github.com/pendyurinandrey/redmine-tweaks.git redmine_tweaks
cd /path/to/redmine && bundle exec rake redmine:plugins:migrate RAILS_ENV=production   # the plugin has no migrations; safe to run
```

In a Docker image:

```dockerfile
RUN git clone --depth 1 --branch v0.4.0 https://github.com/pendyurinandrey/redmine-tweaks.git plugins/redmine_tweaks \
    && rm -rf plugins/redmine_tweaks/.git
```

Restart Redmine. Plugin JS/CSS is copied to the public assets on start; after changing them restart again and hard-refresh the browser.
No configuration and no permissions are needed. To remove the plugin, delete the directory and restart.

## Compatibility notes

The scripts rely on a few internal identifiers of Redmine's issue page: `#update`, `#issue-form`, `#issue_description`,
`#issue_description_and_toolbar`, `#issue_description_wiki`, `.description`, the global `showAndScrollTo()`, and on the markup of task lists
(`input.task-list-item-checkbox`). The start page feature adds a `before_action` to `WelcomeController#index`. The calendar feature **replaces** `MyHelper#render_calendar_block`
(a copy of the core method plus the number of weeks; the core partial `my/blocks/_calendar` is no longer used) and wraps `Redmine::Helpers::Calendar#initialize`.
The "Not planned" filter adds an `IssueQuery` filter field (`initialize_available_filters`, `sql_for_not_planned_field`) — a documented, stable Redmine extension point,
not a patch of `Query#statement` itself. They have been stable for many releases, but after a major Redmine upgrade compare `render_calendar_block` with the plugin's copy and run the manual checklist below once.

## Development and manual test checklist

Any Redmine 6 works; the project's local stand mounts the working copy (`TWEAKS_DEV_DIR=/path/to/redmine-tweaks ./redmine.sh up`,
then `./redmine.sh restart` after changes). Checklist (as a user with the *Member*-like role, then as a user who cannot edit issues):

1. Issue with a description: the pencil is next to **Description**; a click opens the form, the editor is expanded, the caret is at the end.
2. Type something, press **Esc** → confirmation; *Cancel* keeps the text, *OK* restores the saved text and closes the form.
3. No changes, press **Esc** → closes without a question; the pencil takes the focus.
4. **Cancel** link of the form still works (keeps the typed text); the pencil opens the form again with that text.
5. **Ctrl/Cmd+Enter** saves; the description changes and appears in the history.
6. Issue **without a description**: the "Description ✎" row exists and works.
7. Links and task-list checkboxes inside the description behave as before (the pencil does not affect them).
8. A user who can comment but not edit: **no pencil**.
9. Narrow (phone) width and the Opale theme: the pencil is visible and tappable.
10. Task lists (a description with nested items, a numbered item, a fenced code block containing `- [ ] text`): the checkboxes are clickable; a click
    saves, the page returns to the same scroll position, the right item changed, the history has "Description updated".
11. Type a comment in the form, then click a checkbox: the click is reverted with a hint and nothing is sent.
12. A user who may not edit the description, and a description whose markers cannot be mapped (an indented code block with `- [ ]`): the checkboxes stay disabled.
13. Logged in, open `/`: you land on "My page". Logged out: the login page (or the home page if anonymous access is allowed).

14. The Calendar block on "My page" has a gear button; choosing 3 weeks and saving shows three week rows without a page reload; an issue due in the third week appears only then.
    Removing and adding the block again keeps working.

15. Issues → *Add filter* → **Not planned** appears; **Yes** shows issues missing a start date or a due date, **No** shows the rest; combines with Status as usual (AND).
16. My page → *Add* → **Planned time**: bars for today and the next 6 days; with issues whose start and due date are the same day, the bar height and the tooltip match their estimates; a closed issue, an issue of another assignee (when one is chosen) and a multi-day issue do not change the bars (the last one shows in the note); a click opens that day's issue list.

HTTP-level checks for a running instance (use a test account): `test/start_page_smoke.sh <base_url> <login> <password>` (item 13), `test/calendar_weeks_smoke.sh <base_url> <login> <password>` (item 14),
`test/not_planned_filter_smoke.sh <base_url> <api_key> <project>` (item 15, needs a project with a mix of planned/unplanned/closed issues and an API key) and `test/planned_time_smoke.sh <base_url> <login> <password>` (item 16, structure and settings only; the numbers depend on your data).

Unit tests for the parsing logic (no dependencies, Node 18+): `node --test test/*.test.js`.

## License

[MIT](LICENSE).
