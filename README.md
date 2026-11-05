# Rubylode Projects for Redmine

<p><img src="docs/thumbnail.png" alt="Rubylode Projects plugin" width="160"></p>

[![tests](https://img.shields.io/github/actions/workflow/status/rubylode/redmine-rubylode-projects/tests.yml?branch=main&label=tests)](https://github.com/rubylode/redmine-rubylode-projects/actions/workflows/tests.yml)
[![security](https://img.shields.io/github/actions/workflow/status/rubylode/redmine-rubylode-projects/security.yml?branch=main&label=security)](https://github.com/rubylode/redmine-rubylode-projects/actions/workflows/security.yml)
[![version](https://img.shields.io/github/v/tag/rubylode/redmine-rubylode-projects?sort=semver&label=version)](https://github.com/rubylode/redmine-rubylode-projects/tags)
[![license](https://img.shields.io/github/license/rubylode/redmine-rubylode-projects)](https://github.com/rubylode/redmine-rubylode-projects/blob/main/LICENSE)
![Redmine](https://img.shields.io/badge/Redmine-6.0%20%7C%206.1%20%7C%207.0-b22222)
![Ruby](https://img.shields.io/badge/Ruby-3.3%20%7C%203.4%20%7C%204.0-cc342d)

TL;DR: a project Overview page with counts, a weekly chart and a list of urgent issues, plus a summary, extra columns and
paging for the projects list in [Redmine](https://www.redmine.org).

Status: version 2.1.0, needs Redmine 6.0 or newer. `docs/roadmap/ROADMAP.md` lists what is decided and what is open.
Upgrading from 1.x? Read the 2.0.0 entry in [CHANGELOG.md](CHANGELOG.md) first: three settings keys were renamed.

Contents:

- [Install](#install)
- [Settings](#settings)
- [Where it shows](#where-it-shows)
- [Troubleshooting](#troubleshooting)
- [Tests](#tests)
- [License](#license)

## Install

1. Put the plugin folder in Redmine's `plugins/` directory, named `redmine_rubylode_projects`.
2. Run `bundle exec rake redmine:plugins:migrate RAILS_ENV=production`.
3. If the plugin reads an environment variable, set it where Redmine runs, then restart Redmine. This plugin reads none, so only the restart applies.
4. In Administration, Plugins, open the plugin and choose Configure.

Needs Redmine 6.0 or newer; the tests run on 6.0, 6.1 and 7.0 (`.github/workflows/tests.yml`). The migration only renames settings keys that an older version saved. The plugin adds no table, and removing it (delete the folder, restart) changes nothing in the database.

With Redmine in Docker, put the folder in the directory you mount as `/usr/src/redmine/plugins` (or copy it into the container's `plugins` folder) and keep the name `redmine_rubylode_projects`. Without git, unpack a release archive into `plugins/redmine_rubylode_projects`.

## Settings

Administration, Plugins, Configure. The values are checked when saved: a bad one shows the form again with the problem.

Redmine keeps the settings as one hash in `Setting.plugin_redmine_rubylode_projects`. Missing keys read as the default, so a tool can write only the keys it wants to change. On/off values are the strings `"1"` and `"0"`; `added_columns` is an array.

| Setting | Key | Allowed values | Default |
|---|---|---|---|
| Default projects display | `default_display` | `"list"`, `"board"`, `"redmine"` (Leave to Redmine: Redmine's own "project list display type" setting applies) | `"list"` |
| Show the summary and charts above the list | `show_summary` | `"1"`, `"0"` | `"1"` |
| Columns added to the project list | `added_columns` | any of `"open_issues"`, `"overdue"`, `"closed_week"`, `"percent_done"`, `"trend"`, `"last_activity"`; `[]` for none | `["open_issues", "overdue", "percent_done", "trend"]` |
| Also add the checked columns to saved queries | `add_columns_to_saved_queries` | `"1"`, `"0"` | `"0"` |
| Weeks in the trend | `trend_weeks` | a whole number from 4 to 26 | `"12"` |
| Maximum rows | `maximum_rows` | a whole number from 1 to 100; also the default for the macro and the partial | `"20"` |
| Show the description in the projects table | `projects_table_show_description` | `"1"`, `"0"` | `"1"` |
| Show the done bar in the projects table | `projects_table_show_done_bar` | `"1"`, `"0"` | `"1"` |
| Welcome page (under "Show the block on") | `show_on_welcome_page` | `"1"`, `"0"` | `"0"` |
| Column (under "Show the block on") | `welcome_page_column` | `"left"`, `"right"` | `"right"` |

"Also add the checked columns to saved queries": when on, a saved project query that holds none of this plugin's columns shows the checked ones. The query is not changed, and a query that holds any of them is left alone.

The default display applies only when the address names no `display_type`, no saved query, and the user has not chosen a display earlier in the session.

## Where it shows

- A project's Overview page, in place of Redmine's own blocks.
- The projects list at `/projects`: a summary, extra columns and pages in the board view.
- The welcome page, as the projects table (setting `show_on_welcome_page`).
- Any wiki page, as the `{{projects_table}}` macro.

### The project Overview

A project's Overview page shows a set of cards in place of Redmine's own blocks:

- The project's description as a one-line subtitle under the title, with the whole of it on hover.
- Four tiles: open issues (split by tracker), closed (as a share of all), all issues (and how many subprojects they span),
  and done (a percentage with a bar). Each count links to the matching issue list, and hovering one shows the issues behind it.
- Opened and closed per week, for the last 12 weeks, as a bar chart drawn on the server (inline SVG). Hover, focus or
  tap a week for its figures; click it for the issues.
- By tracker: one bar per tracker with its open and closed counts and the share done, and links to the issue list, the
  summary and the Gantt chart. Hover a tracker for its open, closed and overdue counts; click it for its list.
- In progress and urgent: up to eight open issues that someone has started or that sit above the default priority, with a
  link to all open issues sorted by priority.
- Members grouped by role, the subprojects as chips, and, when the project tracks time, spent and estimated time with
  links to log time, the details and the report.

The cards replace Redmine's description, issue tracking, time tracking, members and subprojects blocks, so nothing
appears twice. News, custom fields and blocks that other plugins add to the page stay. A "Classic overview" link at the
bottom of the cards (`?view=classic`) shows Redmine's own page with every block, and links back.

Redmine's page is rendered as the installed Redmine has it and passed through untouched inside a wrapper. The stylesheet
hides the replaced blocks under the wrapper's class (`display: none`, so screen readers skip them too).

![The Overview page of a demo project: subtitle, four tiles, the weekly chart, the tracker panel, the in-progress-and-urgent list, members, subprojects and time](docs/screenshots/project-overview.png)

The projects list at `/projects` opens in the list view with a summary and charts above it (see [The projects list](#the-projects-list)), and gets pages in the board view. Redmine 7 already pages the list view but puts every
project on one page in the board view. The plugin cuts the board into pages with Redmine's own page links and per-page
choice, which reads the "Objects per page options" setting (Administration, Settings, Display). Filters keep working, and
the list view is left as Redmine has it.

![The board view of the projects list, page 1 of 2](docs/screenshots/projects-board-paginated.png)

![The list view of the projects list, page 1 of 2, which Redmine pages on its own](docs/screenshots/projects-list-paginated.png)

### Interactivity

Charts and tiles show what is behind a number without leaving the page.

![The weekly chart with a week's tooltip and the other weeks dimmed](docs/screenshots/project-overview-week-tooltip.png)

- The weekly chart. Hover a week, tab to it or tap it (the first tap shows the card, the second follows the link) and a
  card gives the week's dates, issues opened, closed and the net change, how many issues were open at the end of that week,
  and the three trackers most issues were opened in. The week's column is highlighted and the others dim. The card links to
  the issues opened that week and the issues closed that week; clicking the column opens the first list. The legend entries
  are buttons that hide and show a series.
- The tiles. Hover or focus a tile and a card lists the five newest issues behind the number (number, subject, status) with
  a "See all N" link. Clicking the tile goes to that list. The done tile lists the closed issues.

![A tile's card with the five newest open issues](docs/screenshots/project-overview-tile-popover.png)

- By tracker. Hover or focus a row for its open, closed and overdue counts and the share done (overdue is open issues past
  their due date). Clicking the row goes to that tracker's issue list.
- Keyboard and screen readers. The weeks are links, so they are in the tab order; the arrow keys move between them and
  Enter opens the list. Escape closes a card. Each week's link carries its figures as its label, and a hidden table repeats
  them with both issue lists for every week (it shows itself when a link in it has focus), so nothing needs the mouse.
  Animations stop under `prefers-reduced-motion`.
- The links are built in one place (`RubylodeProjects::IssueListLink`) in the format Redmine's own filters use
  (`set_filter=1&f[]=created_on&op[created_on]=><&v[created_on][]=...`). Only filter names, whole-number ids and dates go
  into them, all percent-escaped. Subprojects are included or excluded the same way the numbers were counted, with
  Redmine's `subproject_id` filter.
- No extra requests. The figures for all the cards come with the page, in one JSON block, in a fixed number of queries
  however many issues the project has (a test checks that). One small script, `assets/javascripts/overview.js`, plain
  JavaScript with no framework, writes them out as text; without it the page still works, and the weeks and tiles are
  ordinary links.
- Who sees what is the same as everywhere else: the issues in a card go through Redmine's visibility rules.

### The projects list

`/projects` opens in the list view, with a summary above the list and extra columns in it. Redmine's own list is
rendered as the installed Redmine has it; the plugin puts its summary in front and adds columns to Redmine's query.

![The projects list: seven tiles, the weekly chart, where the work is, and the list with the added columns](docs/screenshots/projects-list-summary.png)

- Seven tiles: Projects, Open issues, Closed this week, Overdue, Due in 7 days, Unassigned and No activity in 30 days
  (projects whose last activity is older than that, or that have none). Each issue tile links to the issue list that holds exactly those issues, and hovering or
  focusing it shows the five newest behind the number.
- Opened and closed per week over the projects in the list: the same chart, tooltip and keyboard behavior as a project's
  Overview (one partial and one script serve both).
- Where the work is: open issues per top-level project, the busiest eight, subprojects counted in. Each bar links to
  that project's open issues; hover or focus shows its open, overdue, recently closed and done figures.
- Columns: Open issues, Overdue, Closed (last 7 days), % done (a thin bar) and Trend (a sparkline of issues closed per
  week). Last activity is Redmine's own column.
  - They are ProjectQuery columns, so they appear in the list options, and in the CSV export as plain text (the trend is
    the weekly numbers separated by spaces).
  - Defaults: Redmine's default columns (Name, Identifier and Description in a stock install) plus Open issues, Overdue,
    % done and Trend.
  - A visit that names its own columns keeps exactly those. A saved query keeps its columns too, unless "Also add the
    checked columns to saved queries" is on (see [Settings](#settings)).
  - The new columns cannot be sorted: the figures depend on what the viewer may see, so there is no cheap column to sort by.
- Hover a sparkline for the week's opened and closed counts with links to those issues; the arrow keys move between
  weeks, Escape closes the card, and on a touch screen a tap shows it.

![A sparkline's card with the week's figures and links](docs/screenshots/projects-list-trend-tooltip.png)

![A tile's card with the five newest issues behind the number](docs/screenshots/projects-list-tile-card.png)

What the summary counts. The projects of the list as filtered (every page, not just the one shown), as the viewer may
see them (`Project.visible`, `Issue.visible`). The default filter leaves out closed projects, and archived projects are never
visible; filter the list to show closed projects and they count. Each issue is counted once. A project's own figures include
its subprojects when Redmine's "Display subprojects issues on main projects by default" setting is on, the same as the list
they link to. Weeks run Monday to Sunday in the user's time zone. "Closed this week" is since Monday; the Closed column is
the last seven days. The summary's links filter on the project ids of the list; past 150 projects the links leave that filter
out (the address would be too long) and the page says so, so then a link can list more than its number.

Query count. The summary and the columns add a fixed number of queries however many projects the list holds: grouped
counts, two lists of recent dates, one list of projects and Redmine's own last-activity lookup. A test compares the page
with the plugin on and off for 3 and 30 projects. Redmine's own list adds queries per project, and that does not change.

Back to the board. `/projects?display_type=board` always shows the board. A display named in the address is remembered
for the rest of the session, so the plain Projects link keeps it; a new session starts from the setting. To make the board
the default again, or to follow Redmine's own setting, change "Default projects display" in [Settings](#settings). `?summary=0` hides the
summary for one request. A saved query (including the default query set in Redmine's settings) is shown as it was saved,
unless "Also add the checked columns to saved queries" is on.

Another summary plugin. If `redmine_projects_dashboard` is installed, this plugin shows neither its tiles and charts nor its columns, so
nothing appears twice; the display choice (list or board) still applies. A different plugin id needs a one-line change in
`RubylodeProjects::Coexistence`.

![The board view, still one address away](docs/screenshots/projects-board-paginated.png)

### The projects table

A table of the projects the viewer may see, each with its open and closed issue counts. It does not replace anything: it is a
block you place. It is not added to `/projects`, which already has the summary and the columns.

![The welcome page with the projects table in the right column](docs/screenshots/welcome-projects-table.png)

- Rows. One per project the viewer may see, in Redmine's project tree order: a project, then its subprojects, indented.
  Archived and closed projects are left out. A subproject whose parent the viewer cannot see is listed as a top-level project.
- Columns. Name (a link), description (one line, cut at 140 characters), Open, Closed and, optionally, a thin done bar.
  Done is the share of closed issues, the same figure as the Overview's done tile.
- Counts. Only issues the viewer may see (`Issue.visible`), grouped by project in two queries however many projects
  there are (a test checks the query count with 3 and 30 projects). Each count links to that project's issue list filtered to
  open or closed, built with `IssueListLink`. A row counts its own issues and its links exclude the subprojects, which have
  rows of their own; with `subprojects=false` only top-level projects get a row, and each counts everything under it, with
  links that include the subprojects.
- Accessible. A real table with a caption, `scope` on every header (the project name is the row header), links that name
  the project and the count for screen readers, a visible focus outline, and a done bar that is decoration next to the
  percentage in text.

#### On the welcome page

Check "Welcome page" under "Show the block on" in the plugin settings, and pick the column. It goes in the left or right column through
Redmine's `view_welcome_index_left` and `view_welcome_index_right` hooks, after the welcome text or the news.

#### In a wiki page: the macro

    {{projects_table}}
    {{projects_table(title="Our projects", limit=10, subprojects=false)}}

| Argument | Values | Default |
|---|---|---|
| `title` | the caption (quote it when it holds a comma) | Projects |
| `limit` | a whole number from 1 to 100 | the "Maximum rows" setting |
| `subprojects` | `false` for top-level projects only, each counting everything under it; `true` for the tree | true |

An argument the macro does not know, or a limit or subprojects value it cannot use, shows Redmine's macro error. The macro
is meant for wiki pages (including the welcome text), and its description shows in `{{macro_list}}`.

![A wiki page with the projects macro](docs/screenshots/wiki-projects-table-macro.png)

#### From another plugin or a theme: the partial

    <%= render partial: "rubylode_projects/projects_table", locals: { title: "Our projects", limit: 10, subprojects: false } %>

The partial is `rubylode_projects/projects_table`. Every local is optional:

| Local | Values | Default |
|---|---|---|
| `title` | the caption | Projects |
| `limit` | 1 to 100 | the settings value |
| `subprojects` | true or false | true |
| `show_description` | true or false | the settings value |
| `show_done_bar` | true or false | the settings value |
| `user` | whose view of projects and issues it is | `User.current` |

It renders nothing when the user may see no project, and it adds the plugin's stylesheet to the page head by itself.

### The rules behind the numbers

- Who sees what. Every count and list goes through Redmine's own issue visibility, so private issues, per-tracker
  permissions and roles that see only their own issues are respected. A project without the Issue tracking module, or a
  user who may not view its issues, gets no issue cards; the members and subprojects cards still show. The time card
  follows Redmine's own rules: it shows to users who may view time entries (which needs the Time tracking module), and
  the totals only to those who may see everyone's time.
- Subprojects. Counts include subprojects when Redmine's "Display subprojects issues on main projects by default"
  setting is on (it is by default), so the numbers match the issue lists they link to. With the setting off, they cover
  the project alone.
- Done is the share of issues that are closed, rounded down, so 100% means every issue is closed. It is not Redmine's
  "% done" field.
- The weekly chart counts an issue as opened in the week of its creation date, and as closed in the week of its closing
  date if it is closed now. Weeks run Monday to Sunday in the user's time zone and are labeled with their ISO week number.
- In progress and urgent. An open issue is listed when either its priority sits above the default priority (High,
  Urgent and Immediate in Redmine's default data), or its status is no longer its tracker's default status, which means work
  has started (In Progress, Feedback and Resolved in the default data). Without a default priority, the middle priority
  stands in for it. The list is sorted by priority, highest first, then by the last update.
- Board pages hold whole trees: the per-page number counts top projects, and each comes with all of its subprojects,
  so a subproject is never on a different page from its parent.

The colors and sizes of everything above are CSS custom properties. See [docs/theming.md](docs/theming.md).

## Troubleshooting

- The welcome page shows no table. Check "Welcome page" under "Show the block on" in the plugin settings, and make sure the viewer may see at least one project: the table renders nothing otherwise.
- A saved query shows none of the new columns. That is on purpose: check "Also add the checked columns to saved queries", or pick the columns in the list options.
- The settings page shows the defaults after an upgrade from 1.x. Run the migration (Install, step 2); it moves the three renamed keys.
- The cards replace Redmine's overview blocks by hiding them with CSS. A theme or plugin that restyles those blocks' classes may show or hide them differently; `?view=classic` always shows Redmine's own page.
- The Overview's weekly chart covers 12 weeks and its in-progress list at most eight issues; the projects list's trend weeks are a setting.
- The Open, Overdue, Closed, % done and Trend columns cannot be sorted.
- Board pages hold whole project trees, so a page can be longer than the per-page number when a top project has many subprojects.
- Only English text ships. Labels are in `config/locales/en.yml`, so another language is a locale file away.

## Tests

    bin/test                                                   all unit and integration tests
    bin/test test/integration/project_overview_page_test.rb    one file

They run in a Redmine 7 image with its test gems (`docker/test.Dockerfile`). The numbers (percentages, weekly buckets,
the chart scale and layout, the urgency rule, the board pages, the issue list links, the weekly running totals) are plain
Ruby classes with their own unit tests. Integration tests (`test/integration/overview_interactivity_test.rb`, `projects_summary_test.rb`, `project_columns_test.rb`, `default_display_test.rb`) check the tooltip data, the markup and the query count. I checked the script by hand in Chrome (hover, focus, tap, Escape, click through to a filtered list). That check is not in the repository.

Pull Requests are welcome! Releases are described in [docs/releasing.md](docs/releasing.md).

### Try it

A throwaway Redmine 7 runs from this folder, with the repository mounted as the plugin:

    ruby bin/demo up        start it on http://localhost:3009 and load the demo data
    ruby bin/demo restart   pick up a change to the plugin
    ruby bin/demo reset     wipe it

The demo data (`test/seed.rb`) is made up: 38 projects, one big project called Orchard with 360 issues over 14 weeks, due dates on some open issues, a few issues closed this week and eight people. Sign in as admin / admin, or as `ada.lovelace` (and the others) with `demo-password-1`.

## License

GNU General Public License, version 2 or (at your option) any later version, the same as Redmine. See `LICENSE`.

Copyright (C) 2026  Nick Gorbikoff

No warranty, as the GPL says. The plugin changes how two of Redmine's pages are drawn, so try it on a copy of your tracker before the real one.
