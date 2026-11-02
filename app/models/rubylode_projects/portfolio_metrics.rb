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
  # Every issue figure the projects list needs, for one user, in a fixed number of grouped queries however many projects there
  # are: one count per figure grouped by project, two lists of dates for the weekly counts, one list of the projects and
  # Redmine's own last-activity lookup. Nothing is queried until a figure is asked for.
  #
  # Only what the user may see is counted: every issue query goes through Issue.visible, and the projects through
  # Project.visible. A project's figures include its subprojects' when Redmine's "Display subprojects issues on main
  # projects by default" setting is on, the same as the issue list the figure links to (see #figures_for).
  class PortfolioMetrics
    ProjectRow = Data.define(:id, :parent_id, :lft, :rgt, :name, :identifier, :status)
    RECENT_DAYS = 7
    DUE_SOON_DAYS = 7
    QUIET_DAYS = 30

    attr_reader :user, :week_count

    def initialize(user: User.current, week_count: PluginSettings::DEFAULTS["trend_weeks"].to_i, with_subprojects: Setting.display_subprojects_issues?, today: nil)
      @user = user
      @week_count = week_count
      @with_subprojects = with_subprojects
      @today = today
    end

    def with_subprojects? = @with_subprojects

    def today = @today ||= user.today

    def buckets
      @buckets ||= WeeklyBuckets.new(today: today, week_count: week_count)
    end

    # The visible projects, as light rows: the nested set columns tell which project sits under which.
    def project_rows
      @project_rows ||= Project.visible(user).pluck(:id, :parent_id, :lft, :rgt, :name, :identifier, :status)
                               .to_h { |values| [values.first, ProjectRow.new(*values)] }
    end

    # { project_id => ProjectFigures } for the issues of each project alone, subprojects not added.
    def own_figures
      @own_figures ||= begin
        opened_weeks = weekly_counts(opened_dates_by_project, :opened)
        closed_weeks = weekly_counts(closed_dates_by_project, :closed)
        project_ids = [open_counts, total_counts, overdue_counts, due_soon_counts, unassigned_counts, opened_weeks, closed_weeks]
                      .flat_map(&:keys).uniq
        project_ids.to_h do |project_id|
          [project_id, ProjectFigures.new(
            open_count: open_counts.fetch(project_id, 0),
            closed_count: total_counts.fetch(project_id, 0) - open_counts.fetch(project_id, 0),
            overdue_count: overdue_counts.fetch(project_id, 0), due_soon_count: due_soon_counts.fetch(project_id, 0),
            unassigned_count: unassigned_counts.fetch(project_id, 0),
            closed_recent_count: recent_closed_counts.fetch(project_id, 0),
            opened_by_week: opened_weeks.fetch(project_id, empty_weeks), closed_by_week: closed_weeks.fetch(project_id, empty_weeks)
          )]
        end
      end
    end

    # A project's figures the way its issue list counts them: with its subprojects when the setting is on and it has some.
    def figures_for(project)
      with_subprojects? ? subtree_figures_for(project) : own_figures_of(project.id)
    end

    # The project's figures with every project under it, whatever the setting.
    def subtree_figures_for(project)
      row = project_rows[project.id]
      return own_figures_of(project.id) unless row && row.rgt - row.lft > 1

      ids = own_figures.keys.select do |project_id|
        other = project_rows[project_id]
        other && other.lft >= row.lft && other.rgt <= row.rgt
      end
      ProjectFigures.sum(ids.map { |project_id| own_figures[project_id] }, week_count: week_count)
    end

    # The figures of exactly these projects added together, each issue counted once.
    def combined_figures(project_ids)
      ProjectFigures.sum(own_figures.values_at(*project_ids).compact, week_count: week_count)
    end

    def own_figures_of(project_id) = own_figures.fetch(project_id) { ProjectFigures.empty(week_count) }

    # { project_id => Time } of each project's newest activity, from Redmine's own lookup (the one its Last activity column uses).
    def last_activity_times
      @last_activity_times ||= Redmine::Activity::Fetcher.new(user).events(nil, nil, last_by_project: true).to_h
    end

    # The projects among these with no activity for 30 days or more, or none at all, the longest quiet first.
    def quiet_project_ids(project_ids)
      limit = QUIET_DAYS.days.ago
      project_ids.select { |project_id| (last = last_activity_times[project_id]).nil? || last < limit }
                 .sort_by { |project_id| last_activity_times[project_id] || Time.at(0) }
    end

    def visible_issues = Issue.visible(user)

    def time_zone = user.time_zone || Time.zone

    # The first moment the weekly counts need: the Monday of the oldest week.
    def since = buckets.first_date.in_time_zone(time_zone)

    private

    def empty_weeks = Array.new(week_count, 0)

    def project_column = "#{Issue.table_name}.project_id"

    def counts_by_project(scope) = scope.group(project_column).count

    def open_counts = @open_counts ||= counts_by_project(visible_issues.open)

    def total_counts = @total_counts ||= counts_by_project(visible_issues)

    def overdue_counts
      @overdue_counts ||= counts_by_project(visible_issues.open.where("#{Issue.table_name}.due_date < ?", today))
    end

    def due_soon_counts
      @due_soon_counts ||= counts_by_project(visible_issues.open.where(Issue.table_name => { due_date: today..(today + DUE_SOON_DAYS) }))
    end

    def unassigned_counts
      @unassigned_counts ||= counts_by_project(visible_issues.open.where(Issue.table_name => { assigned_to_id: nil }))
    end

    def opened_dates_by_project
      @opened_dates_by_project ||= group_dates(visible_issues.where("#{Issue.table_name}.created_on >= ?", since).pluck(:project_id, :created_on))
    end

    def closed_dates_by_project
      @closed_dates_by_project ||= group_dates(
        visible_issues.joins(:status).where(IssueStatus.table_name => { is_closed: true })
                      .where("#{Issue.table_name}.closed_on >= ?", since).pluck(:project_id, :closed_on)
      )
    end

    def recent_closed_counts
      first_recent_day = today - (RECENT_DAYS - 1)
      @recent_closed_counts ||= closed_dates_by_project.transform_values { |dates| dates.count { |date| date >= first_recent_day } }
    end

    def group_dates(rows)
      rows.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(project_id, time), grouped|
        grouped[project_id] << time.in_time_zone(time_zone).to_date
      end
    end

    # Both lists go through WeeklyBuckets, the same bucketing as the Overview's chart.
    def weekly_counts(dates_by_project, series)
      dates_by_project.transform_values do |dates|
        week_list = series == :opened ? buckets.weeks(opened_dates: dates, closed_dates: []) : buckets.weeks(opened_dates: [], closed_dates: dates)
        week_list.map { |week| series == :opened ? week.opened_count : week.closed_count }
      end
    end
  end
end
