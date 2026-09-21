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

## Installation

The repository is called `redmine-tweaks`, but the plugin directory **must be named exactly `redmine_tweaks`** (that is the plugin id), so give the target directory explicitly:

```bash
cd /path/to/redmine/plugins
git clone --branch v0.2.0 https://github.com/pendyurinandrey/redmine-tweaks.git redmine_tweaks
cd /path/to/redmine && bundle exec rake redmine:plugins:migrate RAILS_ENV=production   # the plugin has no migrations; safe to run
```

In a Docker image:

```dockerfile
RUN git clone --depth 1 --branch v0.2.0 https://github.com/pendyurinandrey/redmine-tweaks.git plugins/redmine_tweaks \
    && rm -rf plugins/redmine_tweaks/.git
```

Restart Redmine. Plugin JS/CSS is copied to the public assets on start; after changing them restart again and hard-refresh the browser.
No configuration and no permissions are needed. To remove the plugin, delete the directory and restart.

## Compatibility notes

The scripts rely on a few internal identifiers of Redmine's issue page: `#update`, `#issue-form`, `#issue_description`,
`#issue_description_and_toolbar`, `#issue_description_wiki`, `.description`, the global `showAndScrollTo()`, and on the markup of task lists
(`input.task-list-item-checkbox`). They have been stable for many releases, but after a
major Redmine upgrade run the manual checklist below once.

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

An HTTP-level check of item 13 for a running instance: `test/start_page_smoke.sh <base_url> <login> <password>`.

Unit tests for the parsing logic (no dependencies, Node 18+): `node --test test/*.test.js`.

## License

[MIT](LICENSE).
