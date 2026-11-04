# Roadmap

## Goal

Improve the project views of Redmine: the project Overview page of one project, and the projects list at `/projects`.

## Requirements

The reference for the Overview page is a mock-up kept outside this repository. What it shows, top to bottom:

- A title with a one-line subtitle, and the bookmark and more-actions buttons on the right
- A row of four tiles: open issues (with the split by tracker), closed (with the share of all), all issues (with the number of
  subprojects it spans), and done (a percentage with a progress bar)
- A chart of issues opened against closed per week, with a legend; it reads the project's own issues, subprojects included
- A "By tracker" panel: one bar per tracker with open and closed counts and the percentage done, and links to the issue list,
  the summary and the Gantt
- An "In progress and urgent" list: ticket number, status chip, subject and tracker, with a link to all
- A Members panel grouped by role, and a Subprojects panel of chips
- Everything as light cards on a soft background, in whatever theme is active

The projects list at `/projects` needs pagination. It currently shows every project on one page.

## Decisions

- Replace, with the classic page one click away (0.3.0; 0.2.0 added the cards above Redmine's blocks instead). The
  page matches the mock-up: the cards stand in for Redmine's description, issue tracking, time tracking, members and
  subprojects blocks, so nothing shows twice. News, custom fields and blocks other plugins add on the page's hooks stay.
  A "Classic overview" link (`?view=classic`) shows Redmine's own page with every block, and links back.
- How the blocks are replaced. The plugin's `projects/show` renders Redmine's own template from Redmine's view folder,
  so a change to it in a later Redmine 7 release still shows. The output is never parsed or rewritten (a security review
  ruled out re-serialising it: user-written descriptions can change meaning in a parse and write round trip). It goes
  through untouched inside a wrapper; the cards are put in after the first heading; the wrapper's
  `rubylode-projects-cards-shown` class lets the stylesheet hide the replaced blocks with `display: none`. A test checks
  the output is byte for byte Redmine's own. The title, bookmark and actions menu are Redmine's.
- Subtitle. The project's description, as plain text on one line (cut with an ellipsis), the whole of it on hover;
  nothing when the description is empty.
- Time tracking moves to a compact card beside members and subprojects, with Redmine's own rules: shown when the user
  may view time entries, totals only for those who may see everyone's time, links to log time, details and report. The
  classic page has Redmine's block too.
- Theming. Every color and size is a `--rubylode-projects-*` property with its default in `:where(:root)`, so a
  theme's value always wins. The README lists them.
- **The weekly chart is a query at page load**, nothing is stored: two queries over the last 12 weeks of visible issues,
  bucketed in Ruby in the user's time zone. Closed means closed now, in the week of `closed_on`.
- Urgent is: open, and either a priority above the default priority, or a status other than the tracker's default
  status (work has started). The rule is `UrgencyRule`; the SQL the page runs is tested against it.
- Done is the closed share of all issues, rounded down, not Redmine's "% done" field.
- **Counts follow Redmine's "display subprojects issues" setting**, so they match the issue lists the cards link to.
- Pagination. Redmine 7 already pages the list view (with the per-page choice from the "Objects per page options"
  setting), so the plugin leaves it alone. The board view had no pages; the plugin adds them with Redmine's own page links.
  A board page holds whole trees, so the per-page number counts top projects and a subproject stays on its parent's page.
- Redmine 6.0 and newer (1.3.0), tested on 6.0, 6.1 and 7.0 (7.0.2 and 7.0-stable) in CI.

- The projects list opens in the list view with a summary (0.5.0). Settings choose the default display (list, board,
  leave to Redmine), whether the summary shows, the columns added and the trend weeks. The choice applies only to a plain
  visit: an explicit `display_type`, a saved query and a display chosen earlier in the session are left alone.
- Figures in grouped queries. One count per figure grouped by project, two lists of recent dates, one list of projects
  and Redmine's last-activity lookup: a fixed number of queries however many projects there are. A project's figures include
  its subprojects with Redmine's setting, so they match the list they link to.
- **The new columns are not sortable**, because the figures depend on the viewer's permissions.
- Coexistence. With another summary plugin installed, this one adds no tiles and no columns; `?summary=0` hides the summary once.

## Open questions

- Should the project list's columns be sortable (a per-viewer sort would need a visibility-aware subquery)?
- Should the "No activity in 30 days" tile link somewhere (the projects list has no last-activity filter)?
- Should the Overview's weeks (12) and the in-progress length also be settings?
- Should the choice of the classic page be remembered per user, instead of a link each time?
- Should the in-progress statuses be a setting? Today "Resolved" and "Feedback" count as in progress in the default data.
- Is eight the right length for the in-progress-and-urgent list, and should it say when more are hidden beyond the count?
- Should a board page count top projects (as now) or projects? A top project with many subprojects makes a long page.
- Is a 12-week window right for every project, or should it be a choice on the page?

## Done

- 0.1.0: the skeleton. The plugin registers, marks the projects page with a placeholder and loads one stylesheet.
- 0.2.0: the Overview cards (tiles, weekly chart, by tracker, in progress and urgent, members, subprojects), pages for the
  board view of the projects list, a seeded demo Redmine and README screenshots.
- 0.3.0: the cards replace Redmine's duplicate blocks, with a classic-overview link; the description as subtitle; a time
  card; every color and size a `--rubylode-projects-*` property.
- 0.4.0: an interactive Overview: a tooltip for every week of the chart, cards behind the tiles and the tracker rows, legend
  toggles, keyboard and screen reader support, in one JSON block and a fixed number of queries.
- 0.5.0: the projects list opens in the list view with a summary (tiles, portfolio chart, where the work is), five new columns with a
  sparkline, plugin settings, and coexistence with another summary plugin.
- 0.5.1: a test fix for newer gems; no change for users.
- 1.0.0: first stable release; the name, author and version match the redmine.org listing.
- 1.1.0: the projects table (welcome page, `{{projects_table}}` macro and partial) and its settings.
- 1.2.0: the setting to add the checked columns to saved queries; a table of the settings keys.
- 1.3.0: runs on Redmine 6.0 and newer.
- 1.3.1: a test fix; no change for users.
- 2.0.0: the Rubylode plugin standard: one settings class (`RubylodeProjects::Settings`), one locale root, three renamed settings keys with a migration.
