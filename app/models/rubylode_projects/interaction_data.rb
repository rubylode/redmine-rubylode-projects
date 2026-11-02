# Rubylode Projects: a better projects list, for Redmine
# Copyright (C) 2026  Nick Gorbikoff
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module RubylodeProjects
  # Everything the Overview's script needs for its tooltips and popovers, worked out on the server so the page makes no
  # further requests: the weeks of the chart, the issues behind each tile, the figures of each tracker and the words to show.
  # It goes into the page as one JSON block (see the overview partial); the script only writes it out as text.
  #
  # The view is Rails' view context: it supplies the user's date format, translations and paths.
  class InteractionData
    WeekDetail = Struct.new(:week, :label, :net, :open_total, :top_trackers, :opened_url, :closed_url, :summary, keyword_init: true)

    # base_path is the issue list the links start from; without it, the overview's project's own list. The projects list passes the
    # global one, with a PortfolioSummary standing in for the overview.
    def initialize(overview:, view:, base_path: nil)
      @overview = overview
      @view = view
      @base_path = base_path
    end

    def weeks
      @weeks ||= overview.weeks.each_with_index.map { |week, index| week_detail(week, overview.open_totals_at_week_ends.fetch(index)) }
    end

    def weeks_as_json = weeks.map { |detail| week_json(detail) }

    def as_json(*)
      { weeks: weeks_as_json, tiles: tiles_json, trackers: trackers_json, strings: strings }
    end

    def self.strings(view)
      %i[open opened closed net open_total top_trackers opened_link closed_link overdue done no_issues].to_h do |key|
        [key.to_s.gsub(/_(\w)/) { Regexp.last_match(1).upcase }, view.l(:"rubylode_projects_tip_#{key}")]
      end
    end

    def strings = self.class.strings(view)

    # JSON that is safe inside a script element: <, > and & are written as unicode escapes.
    def to_script_json = ERB::Util.json_escape(JSON.generate(as_json))

    private

    attr_reader :overview, :view

    def link = @link ||= overview.issue_list_link(@base_path || view.project_issues_path(overview.project))

    def week_detail(week, open_total)
      last_day = overview.week_end_date(week)
      net = week.opened_count - week.closed_count
      label = view.l(:rubylode_projects_week_range, first: view.format_date(week.start_date), last: view.format_date(last_day))
      WeekDetail.new(
        week: week, label: label, net: net, open_total: open_total,
        top_trackers: overview.top_trackers_by_week.fetch(week.start_date, []).map { |tracker_id, count| [overview.tracker_names[tracker_id], count] },
        opened_url: link.opened_between(week.start_date, last_day), closed_url: link.closed_between(week.start_date, last_day),
        summary: view.l(:rubylode_projects_week_summary, label: label, opened: week.opened_count, closed: week.closed_count,
                                                          net: signed(net), open_total: open_total)
      )
    end

    def signed(number) = number.positive? ? "+#{number}" : number.to_s

    def week_json(detail)
      { start: detail.week.start_date.iso8601, label: detail.label, opened: detail.week.opened_count, closed: detail.week.closed_count,
        net: detail.net, openTotal: detail.open_total, openedUrl: detail.opened_url, closedUrl: detail.closed_url,
        topTrackers: detail.top_trackers.select(&:first).map { |name, count| { name: name, count: count } } }
    end

    def tiles_json
      totals = overview.totals
      { "open" => tile_json(:open, totals.open_count, link.status(:open)),
        "closed" => tile_json(:closed, totals.closed_count, link.status(:closed)),
        "all" => tile_json(:all, totals.total_count, link.status(:all)),
        "done" => tile_json(:closed, totals.closed_count, link.status(:closed)) }
    end

    def tile_json(kind, count, url)
      { count: count, url: url, seeAll: view.l(:rubylode_projects_see_all, count: view.number_with_delimiter(count)),
        issues: preview_issues(kind).map { |issue| { id: issue.id, subject: issue.subject, status: issue.status.name, url: view.issue_path(issue) } } }
    end

    def preview_issues(kind) = (@preview_issues ||= {})[kind] ||= overview.preview_issues(kind)

    def trackers_json
      overview.tracker_tallies.to_h do |tally|
        [tally.tracker.id.to_s, { name: tally.tracker.name, open: tally.open_count, closed: tally.closed_count,
                                  overdue: overview.overdue_counts.fetch(tally.tracker.id, 0), percentage: tally.done_percentage,
                                  url: link.tracker(tally.tracker.id) }]
      end
    end
  end
end
