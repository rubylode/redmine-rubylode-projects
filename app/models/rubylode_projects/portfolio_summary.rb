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
  # The summary above the project list: what the projects of the list hold together, as one user may see it. The projects
  # are those the list is filtered to (all pages, not just this one), so a name filter narrows the summary too, and the
  # default filter leaves out the closed projects. Archived projects are never visible, so they never count.
  #
  # The figures come from PortfolioMetrics, one issue counted once. Every tile has a link that lists exactly its issues
  # (see #link). The chart gets the same interface as ProjectOverview's (weeks, open totals, chart_layout), so the Overview's
  # weekly chart partial and InteractionData draw and describe it unchanged.
  class PortfolioSummary
    BAR_LIMIT = 8
    PREVIEW_ISSUE_LIMIT = 5
    PREVIEW_PROJECT_LIMIT = 5
    # Past this many projects the issue list link would be too long for an address, so it leaves the project filter out.
    PROJECT_ID_LINK_LIMIT = 150

    Tile = Data.define(:key, :count, :url, :preview)
    Bar = Data.define(:project_id, :name, :identifier, :open_count, :overdue_count, :closed_recent_count, :done_percentage, :share, :url)

    attr_reader :metrics, :project_ids

    # issues_path is the global issue list's path, project_issues_path a lambda from a project identifier to its list's path.
    def initialize(metrics:, project_ids:, issues_path:, project_issues_path:)
      @metrics = metrics
      @project_ids = project_ids.uniq
      @issues_path = issues_path
      @project_issues_path = project_issues_path
    end

    def today = metrics.today

    def project_count = project_ids.size

    def combined = @combined ||= metrics.combined_figures(project_ids)

    # Links to issue lists over exactly this portfolio. The project filter is left out when the list of projects is too long
    # for an address, which makes the list wider than the number; that is the one place link and number can differ.
    def link
      @link ||= IssueListLink.new(base_path: @issues_path, project_ids: (project_ids if project_ids.size <= PROJECT_ID_LINK_LIMIT))
    end

    def project_ids_in_link? = project_ids.size <= PROJECT_ID_LINK_LIMIT

    def first_day_of_week = today.beginning_of_week(:monday)

    def closed_this_week_count = combined.closed_by_week.last.to_i

    def quiet_ids = @quiet_ids ||= metrics.quiet_project_ids(project_ids)

    def tiles
      @tiles ||= [
        Tile.new(key: :projects, count: project_count, url: nil, preview: :projects),
        Tile.new(key: :open, count: combined.open_count, url: link.status(:open), preview: :open),
        Tile.new(key: :closed_week, count: closed_this_week_count, url: link.closed_between(first_day_of_week, today), preview: :closed_week),
        Tile.new(key: :overdue, count: combined.overdue_count, url: link.overdue(today), preview: :overdue),
        Tile.new(key: :due_soon, count: combined.due_soon_count, url: link.due_between(today, today + PortfolioMetrics::DUE_SOON_DAYS), preview: :due_soon),
        Tile.new(key: :unassigned, count: combined.unassigned_count, url: link.unassigned, preview: :unassigned),
        Tile.new(key: :quiet, count: quiet_ids.size, url: nil, preview: :quiet)
      ]
    end

    # The newest (or most urgent) five issues behind a tile: three queries per tile, whatever the portfolio holds.
    def preview_issues(kind)
      scope = metrics.visible_issues.where(project_id: project_ids)
      scope = case kind
              when :open then scope.open.reorder(updated_order)
              when :closed_week
                scope.joins(:status).where(IssueStatus.table_name => { is_closed: true })
                     .where("#{Issue.table_name}.closed_on >= ?", first_day_of_week.in_time_zone(metrics.time_zone))
                     .reorder("#{Issue.table_name}.closed_on DESC, #{Issue.table_name}.id DESC")
              when :overdue then scope.open.where("#{Issue.table_name}.due_date < ?", today).reorder(due_order)
              when :due_soon
                scope.open.where(Issue.table_name => { due_date: today..(today + PortfolioMetrics::DUE_SOON_DAYS) }).reorder(due_order)
              when :unassigned then scope.open.where(Issue.table_name => { assigned_to_id: nil }).reorder(updated_order)
              else return []
              end
      scope.limit(PREVIEW_ISSUE_LIMIT).preload(:status, :project).to_a
    end

    # The projects with the most open issues, for the Projects tile's card.
    def busiest_project_rows
      rows_in_portfolio.sort_by { |row| [-metrics.own_figures_of(row.id).open_count, row.name.downcase] }.first(PREVIEW_PROJECT_LIMIT)
    end

    def quiet_project_rows
      quiet_ids.first(PREVIEW_PROJECT_LIMIT).filter_map { |project_id| metrics.project_rows[project_id] }
    end

    # The top-level projects of the portfolio with the most open issues, each counted with everything under it.
    # A project counts as top-level when no other project of the portfolio is above it.
    def bars
      @bars ||= begin
        figures = top_level_rows.to_h { |row| [row, metrics.subtree_figures_for(row)] }
        busiest = figures.select { |_row, project_figures| project_figures.open_count.positive? }
                         .sort_by { |row, project_figures| [-project_figures.open_count, row.name.downcase] }.first(BAR_LIMIT)
        highest = busiest.map { |_row, project_figures| project_figures.open_count }.max.to_i
        busiest.map { |row, project_figures| bar(row, project_figures, highest) }
      end
    end

    # ---- The weekly chart: the interface InteractionData and the chart partial expect of a ProjectOverview.

    def weeks
      @weeks ||= combined.opened_by_week.each_index.map do |index|
        WeeklyBuckets::Week.new(start_date: metrics.buckets.first_date + (index * 7), opened_count: combined.opened_by_week[index],
                                closed_count: combined.closed_by_week[index])
      end
    end

    def open_totals_at_week_ends
      @open_totals_at_week_ends ||= WeeklyRunningTotals.new(weeks: weeks, open_now: combined.open_count).open_at_week_ends
    end

    def week_end_date(week) = [week.end_date, today].min

    def chart_layout = @chart_layout ||= WeeklyChartLayout.new(weeks)

    def top_trackers_by_week = {}

    def tracker_names = {}

    def issue_list_link(_base_path) = link

    private

    def rows_in_portfolio = project_ids.filter_map { |project_id| metrics.project_rows[project_id] }

    def top_level_rows
      current_end = nil
      rows_in_portfolio.sort_by(&:lft).select do |row|
        top = current_end.nil? || row.lft > current_end
        current_end = row.rgt if top
        top
      end
    end

    def bar(row, project_figures, highest)
      Bar.new(project_id: row.id, name: row.name, identifier: row.identifier, open_count: project_figures.open_count,
              overdue_count: project_figures.overdue_count, closed_recent_count: project_figures.closed_recent_count,
              done_percentage: project_figures.done_percentage, share: highest.zero? ? 0 : (project_figures.open_count * 100.0 / highest).round(1),
              url: IssueListLink.new(base_path: @project_issues_path.call(row.identifier), subprojects: (:include unless row.rgt - row.lft == 1)).status(:open))
    end

    def updated_order = "#{Issue.table_name}.updated_on DESC, #{Issue.table_name}.id DESC"

    def due_order = "#{Issue.table_name}.due_date ASC, #{Issue.table_name}.id ASC"
  end
end
