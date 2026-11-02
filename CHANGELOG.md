# Changelog

All notable changes to this plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.0.0] - 2026-11-02

First stable release. A project Overview with counts, a weekly chart and what is urgent, and a summary, extra columns and a board view for the projects list.
Its name, author and version are ready to list on redmine.org, and the plugin now shows its project address on Administration, Plugins.

## [0.5.1] - 2026-11-02

### Fixed

- The test that compares Redmine's own rendering of a hostile project description with the plugin's page failed on the
  newest gems that Redmine installs from a fresh checkout, because they write `<` and `>` inside an attribute as entities. The
  check that the sample is in the compared part now accepts both forms; the comparison itself is unchanged. No change to the
  plugin's behaviour.

## [0.5.0] - 2026-11-02

### Added

- The projects list opens in the list view by default, with a summary above it: seven tiles (Projects, Open issues, Closed this
  week, Overdue, Due in 7 days, Unassigned, Quiet 30+ days), the Overview's opened-against-closed chart over the projects in
  the list, and "Where the work is", open issues per top-level project. Everything counts what the viewer may see; tiles
  and bars link to the exact issue lists and show cards on hover and focus.
- Open issues, Overdue, Closed (last 7 days), % done and Trend columns for the project list, as ProjectQuery columns that
  work in the list options and the CSV export. The Trend sparkline shows each week's opened and closed with links.
- Plugin settings: default projects display (list, board, leave to Redmine), the summary on or off, the columns added, and
  the weeks in the trend (4 to 26), validated on save.
- `?summary=0` hides the summary for one request; `?display_type=board` always gives the board, and a display named in the
  address is remembered for the session.
- Redmine's own setting is followed when the default display is left to Redmine; saved queries are untouched.
- `IssueListLink` builds overdue, due-date, unassigned and several-project links.
- Custom properties for the summary, bars, progress bar and sparkline (listed in the README).
- Demo data with due dates and issues closed this week.

### Changed

- The Overview's script is also loaded on the projects list. The weekly chart partial takes an optional note, so both pages use it.
- If a plugin with its own projects summary is installed (`redmine_projects_dashboard`), this plugin adds neither tiles nor columns.

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
  sitting above them, so nothing shows twice. Redmine's page is passed through untouched and the stylesheet hides those
  blocks; news, custom fields and other plugins' blocks stay.
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
