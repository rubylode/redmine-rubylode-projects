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
  # Everything the Overview cards show for one project, as one user may see it. Nothing is queried until a card asks.
  #
  # Issues are counted through Issue.visible, so private issues, per-tracker permissions and "own issues only" roles are
  # respected. Subprojects are included when Redmine's "Display subprojects issues on main projects by default" setting is
  # on (the default), so the numbers match the issue list the cards link to.
  class ProjectOverview
    WEEK_COUNT = 12
    URGENT_LIST_LIMIT = 8
    PREVIEW_ISSUE_LIMIT = 5

    attr_reader :project, :user

    def initialize(project, user: User.current, today: nil)
      @project = project
      @user = user
      @today = today
    end

    def issue_cards?
      project.module_enabled?(:issue_tracking) && user.allowed_to?(:view_issues, project)
    end

    def with_subprojects? = Setting.display_subprojects_issues?

    def gantt? = user.allowed_to?(:view_gantt, project)

    def tracker_tallies
      @tracker_tallies ||= begin
        counts = visible_issues.joins(:status).group(:tracker_id, "#{IssueStatus.table_name}.is_closed").count
        closed = ->(value) { ActiveModel::Type::Boolean.new.cast(value) }
        project.rolled_up_trackers(with_subprojects?).visible(user).map do |tracker|
          open_count = counts.sum { |(tracker_id, is_closed), count| tracker_id == tracker.id && !closed.(is_closed) ? count : 0 }
          closed_count = counts.sum { |(tracker_id, is_closed), count| tracker_id == tracker.id && closed.(is_closed) ? count : 0 }
          TrackerTally.new(tracker: tracker, open_count: open_count, closed_count: closed_count)
        end
      end
    end

    def totals
      @totals ||= IssueTotals.new(tracker_tallies)
    end

    # How many subprojects the counts reach into: the visible descendants, or none when subprojects are left out.
    def subproject_count
      @subproject_count ||= with_subprojects? ? project.descendants.visible(user).count : 0
    end

    def weeks
      @weeks ||= begin
        buckets = WeeklyBuckets.new(today: today, week_count: WEEK_COUNT)
        since = buckets.first_date.in_time_zone(time_zone)
        opened_rows = visible_issues.where("#{Issue.table_name}.created_on >= ?", since).pluck(:created_on, :tracker_id)
        closed_times = visible_issues.joins(:status).where(IssueStatus.table_name => { is_closed: true })
                                     .where("#{Issue.table_name}.closed_on >= ?", since).pluck(:closed_on)
        @opened_by_tracker = opened_rows.map { |created_on, tracker_id| [to_date(created_on), tracker_id] }
        buckets.weeks(opened_dates: @opened_by_tracker.map(&:first), closed_dates: to_dates(closed_times))
      end
    end

    # How many issues were open at the end of each week, in the order of weeks.
    def open_totals_at_week_ends
      @open_totals_at_week_ends ||= WeeklyRunningTotals.new(weeks: weeks, open_now: totals.open_count).open_at_week_ends
    end

    # { Monday => [[tracker_id, count], ...] }: the biggest trackers among the issues opened in each week.
    def top_trackers_by_week
      weeks
      @top_trackers_by_week ||= WeeklyTrackerBreakdown.new(opened: @opened_by_tracker, today: today, week_count: WEEK_COUNT).top_trackers_by_week
    end

    # { tracker_id => name } for the trackers named in top_trackers_by_week: one query, however many weeks.
    def tracker_names
      @tracker_names ||= Tracker.where(id: top_trackers_by_week.values.flatten(1).map(&:first).uniq).pluck(:id, :name).to_h
    end

    # { tracker_id => number } of open issues past their due date.
    def overdue_counts
      @overdue_counts ||= visible_issues.open.where("#{Issue.table_name}.due_date < ?", today).group(:tracker_id).count
    end

    # The newest issues behind each tile, for its popover: :open, :closed or :all. Five at most; one query, and one more to
    # load the statuses, per tile.
    def preview_issues(kind)
      scope = case kind
              when :open then visible_issues.open.reorder(recently_updated_order)
              when :closed
                visible_issues.joins(:status).where(IssueStatus.table_name => { is_closed: true })
                              .reorder("#{Issue.table_name}.closed_on DESC, #{Issue.table_name}.id DESC")
              else visible_issues.reorder(recently_updated_order)
              end
      scope.limit(PREVIEW_ISSUE_LIMIT).preload(:status).to_a
    end

    # Links to the issue list, with the subprojects counted the way the numbers were. A project without subprojects leaves
    # the filter out.
    def issue_list_link(base_path)
      subprojects = project.leaf? ? nil : (with_subprojects? ? :include : :exclude)
      IssueListLink.new(base_path: base_path, subprojects: subprojects)
    end

    # The last day a week covers: its Sunday, or today in the current week.
    def week_end_date(week) = [week.end_date, today].min

    def chart_layout
      @chart_layout ||= WeeklyChartLayout.new(weeks)
    end

    def urgency_rule
      @urgency_rule ||= UrgencyRule.new(priority_positions: IssuePriority.active.pluck(:position),
                                        default_priority_position: IssuePriority.default&.position)
    end

    def urgent_issues(limit: URGENT_LIST_LIMIT)
      urgent_issue_scope
        .reorder("#{IssuePriority.table_name}.position DESC, #{Issue.table_name}.updated_on DESC, #{Issue.table_name}.id DESC")
        .limit(limit).preload(:status, :tracker, :priority).to_a
    end

    def urgent_issue_count
      @urgent_issue_count ||= urgent_issue_scope.count
    end

    def in_progress?(issue)
      urgency_rule.in_progress?(closed: issue.closed?, status_id: issue.status_id, tracker_default_status_id: issue.tracker.default_status_id)
    end

    def urgent_priority?(issue) = urgency_rule.urgent_priority?(issue.priority.position)

    # Roles in Redmine's order, each with its members sorted by name, the same as Redmine's own members box.
    def members_by_role
      @members_by_role ||= project.principals_by_role.sort_by { |role, _principals| role }.map { |role, principals| [role, principals.sort] }
    end

    def subprojects
      @subprojects ||= project.children.visible(user).sort_by(&:lft)
    end

    # The time card stands in for Redmine's time tracking block, with the same rules: shown when the user may view time
    # entries (which needs the time tracking module), totals only when the user may see everyone's time.
    def time_card? = user.allowed_to?(:view_time_entries, project)

    def time_totals? = user.allowed_to_view_all_time_entries?(project)

    def log_time? = user.allowed_to?(:log_time, project)

    def spent_hours
      @spent_hours ||= TimeEntry.visible(user).where(project.project_condition(with_subprojects?)).sum(:hours).to_f
    end

    def estimated_hours
      @estimated_hours ||= visible_issues.sum(:estimated_hours).to_f
    end

    private

    def today = @today ||= user.today

    def time_zone = user.time_zone || Time.zone

    def to_dates(times) = times.map { |time| to_date(time) }

    def to_date(time) = time.in_time_zone(time_zone).to_date

    def recently_updated_order = "#{Issue.table_name}.updated_on DESC, #{Issue.table_name}.id DESC"

    def visible_issues
      Issue.visible(user).where(project.project_condition(with_subprojects?))
    end

    # The rule from UrgencyRule, as SQL: open, and either above the threshold priority or past the tracker's first status.
    def urgent_issue_scope
      threshold = urgency_rule.threshold_position
      priority_condition = threshold ? "#{IssuePriority.table_name}.position > #{threshold.to_i}" : "1 = 0"
      visible_issues.open.joins(:priority, :tracker)
                    .where("#{priority_condition} OR #{Issue.table_name}.status_id <> #{Tracker.table_name}.default_status_id")
    end
  end
end
