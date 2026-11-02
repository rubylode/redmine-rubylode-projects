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

module RubylodeProjects
  # Everything the script needs on the projects list, as one JSON block: the weeks of the portfolio chart, the cards of the
  # tiles and bars, and the figures of every sparkline on the page. Worked out on the server, so the script makes no requests
  # and writes everything out as text. Without a summary only the sparklines' part is there.
  #
  # The view is Rails' view context, as for InteractionData.
  class IndexData
    def initialize(view:, issues_path:, summary: nil, spark_data: {}, metrics: nil)
      @view = view
      @issues_path = issues_path
      @summary = summary
      @spark_data = spark_data
      @metrics = metrics || summary&.metrics
    end

    def any? = !@summary.nil? || @spark_data.any?

    def interaction
      return nil unless @summary

      @interaction ||= InteractionData.new(overview: @summary, view: @view, base_path: @issues_path)
    end

    def as_json(*)
      data = { strings: strings }
      data.merge!(weeks: interaction.weeks_as_json, tiles: tiles_json, bars: bars_json) if @summary
      data[:sparks] = sparks_json if @spark_data.any?
      data
    end

    # JSON that is safe inside a script element: <, > and & are written as unicode escapes.
    def to_script_json = ERB::Util.json_escape(JSON.generate(as_json))

    private

    attr_reader :view

    def strings
      InteractionData.strings(view).merge(extra_strings)
    end

    def extra_strings
      %i[quiet_never quiet_since busiest_open open_issues closed_week].to_h do |key|
        [key.to_s.gsub(/_(\w)/) { Regexp.last_match(1).upcase }, view.l(:"rubylode_projects_tip_#{key}")]
      end
    end

    def tiles_json
      @summary.tiles.to_h do |tile|
        [tile.key.to_s, { count: tile.count, url: tile.url, seeAll: (view.l(:rubylode_projects_see_all, count: view.number_with_delimiter(tile.count)) if tile.url),
                          issues: issues_json(tile.preview), projects: projects_json(tile.preview),
                          empty: view.l(%i[projects quiet].include?(tile.preview) ? :rubylode_projects_tip_no_projects : :rubylode_projects_tip_no_issues) }]
      end
    end

    def issues_json(kind)
      return [] if %i[projects quiet].include?(kind)

      @summary.preview_issues(kind).map do |issue|
        { id: issue.id, subject: issue.subject, status: issue.status.name, project: issue.project.name, url: view.issue_path(issue) }
      end
    end

    def projects_json(kind)
      case kind
      when :projects
        @summary.busiest_project_rows.map do |row|
          { name: row.name, url: view.project_path(row.identifier),
            note: view.l(:rubylode_projects_tip_busiest_open, count: view.number_with_delimiter(@metrics.own_figures_of(row.id).open_count)) }
        end
      when :quiet
        @summary.quiet_project_rows.map do |row|
          last = @metrics.last_activity_times[row.id]
          { name: row.name, url: view.project_activity_path(row.identifier),
            note: last ? view.l(:rubylode_projects_tip_quiet_since, ago: view.time_ago_in_words(last)) : view.l(:rubylode_projects_tip_quiet_never) }
        end
      else
        []
      end
    end

    def bars_json
      @summary.bars.to_h do |bar|
        [bar.project_id.to_s, { name: bar.name, open: bar.open_count, overdue: bar.overdue_count, closedWeek: bar.closed_recent_count,
                                percentage: bar.done_percentage, url: bar.url }]
      end
    end

    # The links of a sparkline are put together in the script from a project's list path, a per-week query that is the same
    # for every project, and the subproject filter if the project has subprojects. This keeps the block small: the weekly
    # queries are written out once, not once per project.
    def sparks_json
      first_date = @metrics.buckets.first_date
      bare = IssueListLink.new(base_path: "")
      weeks = Array.new(@metrics.week_count) do |index|
        start = first_date + (index * 7)
        last = [start + 6, @metrics.today].min
        { start: start.iso8601, label: view.l(:rubylode_projects_week_range, first: view.format_date(start), last: view.format_date(last)),
          openedQuery: bare.opened_between(start, last), closedQuery: bare.closed_between(start, last) }
      end
      with = ->(choice) { IssueListLink.new(base_path: "", subprojects: choice).status(:all).delete_prefix(bare.status(:all)) }
      { weeks: weeks, subprojectFilter: { "include" => with.call(:include), "exclude" => with.call(:exclude), "" => "" },
        projects: @spark_data.transform_keys(&:to_s) }
    end
  end
end
