# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.1.0] - 2026-11-05

No change to what the plugin does. This release carries the documentation and the build.

### Changed

- The workflows use the current versions of the GitHub actions, and Dependabot sends one grouped update a month instead of one pull request per action.
- The version number is no longer asserted exactly by the tests, so a release does not need a test edit.

## [2.0.0] - 2026-11-04

The plugin follows the Rubylode plugin standard: one settings class, one locale root and the standard names for the welcome
page settings. Three saved settings keys change names; a migration moves their values.

### Changed

- Settings key `welcome_projects_table` is now `show_on_welcome_page`. Its label is "Welcome page", under the heading
  "Show the block on".
- Settings key `welcome_projects_table_column` is now `welcome_page_column`. Its label is "Column", a visible select with
  Left and Right next to the Welcome page box.
- Settings key `projects_table_limit` is now `maximum_rows`. Its label is "Maximum rows".
- `RubylodeProjects::PluginSettings` is now `RubylodeProjects::Settings`, the single reader of the settings. Code in another
  plugin or a theme that calls it must use the new name. Its methods `welcome_table_shown?`, `welcome_table_column` and
  `table_limit` are now `show_on_welcome_page?`, `welcome_page_column` and `maximum_rows`.
- The strings moved from flat `rubylode_projects_*` keys to one root, `rubylode_projects`, with `settings.<key>.label` and
  `settings.<key>.hint` for each setting. A theme or plugin that overrides the old keys must move its overrides.
- The macro `{{projects_table}}`, the partial `rubylode_projects/projects_table` and every other settings key keep their names.
- Wording: the weekly chart is "Opened and closed per week" everywhere, the Quiet tile is "No activity in 30 days", the
  checkbox hints say "checked" instead of "ticked", the trend hint names the summary chart and the Trend column, and the
  macro errors end with a full stop. Spelling is en-US.
- The description on Administration, Plugins now lists the summary, the extra columns and the projects table.

### Added

- Migration `001_rename_settings_keys_to_the_rubylode_standard`: moves the saved values of `welcome_projects_table`,
  `welcome_projects_table_column` and `projects_table_limit` to `show_on_welcome_page`, `welcome_page_column` and
  `maximum_rows`. It writes nothing when the settings were never saved. Rolling it back (`rake redmine:plugins:migrate
  NAME=redmine_rubylode_projects VERSION=0`) moves them back.
- Tests for the migration in both directions, for the locale layout and for the Welcome page and Column fields.

### Fixed

- The % done cell of a project without issues showed an en dash. It now says "No issues".

### Upgrading from 1.x

1. Back up the database, or at least note the three settings above.
2. Put the new plugin folder in place and run `bundle exec rake redmine:plugins:migrate RAILS_ENV=production`.
3. Restart Redmine, then open Administration, Plugins, Configure and check the Welcome page, Column and Maximum rows values.
4. If you write the settings from a deployment tool, rename the three keys there. An old key left in the hash is ignored.
5. If you override the plugin's strings or call `PluginSettings`, use the new names above.

## [1.3.1] - 2026-11-04

### Changed

- A test expected the previous version number and failed in CI. No change for users.

## [1.3.0] - 2026-11-04

### Changed

- Runs on Redmine 6.0 and newer. The plugin's own tests pass unchanged on those versions; no code changed.

## [1.2.1] - 2026-11-03

### Added

- A Rubylode thumbnail at the top of the README.

## [1.2.0] - 2026-11-02

### Added

- A setting, "Also add them to saved queries" (key `add_columns_to_saved_queries`, off by default). When on, a saved project
  query that holds none of the plugin's columns shows the ticked ones. It is applied when the page is built; the query is
  never written to, so turning the setting off brings back what was saved. A query that holds any of the columns, a visit
  that picks its own columns and API requests are left as they are.
- A table of every setting key, its allowed values and its default in the README, for tools that write the settings.

### Fixed

- A saved project query, such as one made before the plugin was installed, never showed the plugin's columns. It can now.

## [1.1.0] - 2026-11-02

### Added

- A projects table: one row per project the viewer may see (subprojects indented under their parents), with the name, a
  one-line description, open and closed issue counts that link to the filtered issue lists, and an optional done bar.
  Counts include only issues the viewer may see and use a fixed number of grouped queries. Archived and closed projects
  are left out.
- The `{{projects_table}}` wiki macro, with `title=`, `limit=` and `subprojects=false`.
- The table on the welcome page, in the left or right column (off by default).
- The partial `rubylode_projects/projects_table`, with the locals `title`, `limit`, `subprojects`, `show_description`,
  `show_done_bar` and `user`, for other plugins and themes.
- Settings for the welcome page table: on or off, its column, rows (1 to 100, default 20), the description and the done
  bar. The defaults change nothing for an existing install.
- `--rubylode-projects-table-*` custom properties for the table (listed in the README).

## [1.0.0] - 2026-11-02

### Added

- First stable release: a project Overview with counts, a weekly chart and what is urgent, and a summary, extra columns and a board view for the projects list.
- The name, author and version match the redmine.org listing, and the plugin shows its project address on Administration, Plugins.

## [0.5.1] - 2026-11-02

### Fixed

- The test that compares Redmine's rendering of a hostile project description with the plugin's page failed on the newest
  gems, which write `<` and `>` inside an attribute as entities. The check now accepts both forms. The plugin's
  behaviour is unchanged.

## [0.5.0] - 2026-11-02

### Added

- The projects list opens in the list view by default, with a summary above it.
- The summary has seven tiles (Projects, Open issues, Closed this week, Overdue, Due in 7 days, Unassigned, Quiet 30+ days).
- The summary has the Overview's opened-against-closed chart over the projects in the list, and "Where the work is", open
  issues per top-level project.
- Everything in the summary counts what the viewer may see. Tiles and bars link to the matching issue lists and show cards on
  hover and focus.
- Open issues, Overdue, Closed (last 7 days), % done and Trend columns for the project list, as ProjectQuery columns that
  work in the list options and the CSV export. The Trend sparkline shows each week's opened and closed with links.
- Plugin settings: default projects display (list, board, leave to Redmine), the summary on or off, the columns added, and
  the weeks in the trend (4 to 26), validated on save.
- `?summary=0` hides the summary for one request; `?display_type=board` always gives the board, and a display named in the
  address is remembered for the session.
- Redmine's own display setting is followed when the default display is left to Redmine. Saved queries are untouched.
- `IssueListLink` builds overdue, due-date, unassigned and several-project links.
- Custom properties for the summary, bars, progress bar and sparkline (listed in the README).
- Demo data with due dates and issues closed this week.

### Changed

- The Overview's script now loads on the projects list too. The weekly chart partial takes an optional note, so both pages use it.
- With a plugin that has its own projects summary installed (`redmine_projects_dashboard`), this plugin adds neither tiles nor columns.

## [0.4.0] - 2026-11-01

### Added

- Hover, focus or tap a week of the chart for a card with the dates, opened, closed, net change, the open total at the end of
  the week and the three trackers most opened; the column is highlighted and the others dim. The card links to the issues
  opened and the issues closed that week, and clicking the column opens the first list.
- The chart legend entries hide and show a series.
- Tiles show a card with the five newest issues behind the number and a "See all N" link; clicking a tile goes to its list.
  The done tile now links to the closed issues.
- Tracker rows show open, closed and overdue counts and the share done on hover or focus; clicking a row goes to that
  tracker's issue list (all statuses, so it matches the counts).
- `RubylodeProjects::IssueListLink` builds every issue list link in Redmine's filter format, with the subproject filter
  matching how the numbers were counted.
- Keyboard and screen reader support: the weeks are links with their figures as the label, arrow keys move between them,
  Escape closes a card, and the hidden table gives every week's figures and both issue lists. `prefers-reduced-motion`
  stops the animations.
- Custom properties for the tooltips: `--rubylode-projects-tooltip-background`, `-tooltip-text-color`,
  `-tooltip-border-color`, `-tooltip-shadow`, `-tooltip-minimum-width`, `-tooltip-maximum-width`, `-highlight-color` and
  `-dim-opacity`.

### Changed

- The chart's weeks are links, and the bars no longer have the browser's own `title` tooltips.
- The data behind the cards comes with the page in one JSON block, in a fixed number of queries; the new script is
  `assets/javascripts/overview.js`, plain JavaScript, loaded on the Overview only.

## [0.3.0] - 2026-11-01

### Added

- The project's description as a one-line subtitle under the Overview title, with the whole of it on hover.
- A time card with spent and estimated time and the log time, details and report links, when the project tracks time.
- A "Classic overview" link (`?view=classic`) to Redmine's own Overview page, and a link back to the cards.

### Changed

- The cards replace Redmine's description, issue tracking, time tracking, members and subprojects blocks instead of
  sitting above them. Redmine's page is passed through untouched and the stylesheet hides those blocks. News, custom
  fields and other plugins' blocks stay.
- Every colour and size is a `--rubylode-projects-*` custom property with its default in `:where(:root)`; the README
  lists them under Theming. The 0.2.0 `--rubylode-overview-*` names are gone.

### Fixed

- The board view is paged for clients that send `Accept: */*`.

## [0.2.0] - 2026-10-31

### Added

- Overview cards on a project's Overview page, between the title and Redmine's own blocks: open, closed, all and done
  tiles; opened against closed per week for the last 12 weeks as an inline SVG chart; a by-tracker panel with links to the
  issue list, the summary and the Gantt chart; an in-progress-and-urgent list; members by role; subprojects as chips.
- Pages for the board view of the projects list, using Redmine's own page links and per-page setting. A page holds whole
  project trees.
- Every colour and size of the cards is a CSS custom property, so a theme can restyle them.
- A demo Redmine with made-up data (`bin/demo`, `test/seed.rb`) and screenshots in the README.

### Changed

- `bin/test` runs the unit tests as well as the integration tests.

### Removed

- The placeholder line on the projects list.

## [0.1.0] - 2026-10-31

### Added

- The skeleton: the plugin registers, adds a placeholder line and a stylesheet to the projects index, and has an integration test for both.
