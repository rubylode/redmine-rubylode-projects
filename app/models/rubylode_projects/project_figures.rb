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
  # The issue figures of one project, or of several added together: what the list columns, the tiles and the sparklines show.
  # The weekly arrays hold one count per week, oldest first, the same weeks for everyone (see PortfolioMetrics).
  ProjectFigures = Data.define(:open_count, :closed_count, :overdue_count, :due_soon_count, :unassigned_count,
                               :closed_recent_count, :opened_by_week, :closed_by_week) do
    def self.empty(week_count)
      new(open_count: 0, closed_count: 0, overdue_count: 0, due_soon_count: 0, unassigned_count: 0, closed_recent_count: 0,
          opened_by_week: Array.new(week_count, 0), closed_by_week: Array.new(week_count, 0))
    end

    def self.sum(figures_list, week_count:)
      figures_list.inject(empty(week_count)) { |total, figures| total + figures }
    end

    def +(other)
      with(open_count: open_count + other.open_count, closed_count: closed_count + other.closed_count,
           overdue_count: overdue_count + other.overdue_count, due_soon_count: due_soon_count + other.due_soon_count,
           unassigned_count: unassigned_count + other.unassigned_count,
           closed_recent_count: closed_recent_count + other.closed_recent_count,
           opened_by_week: opened_by_week.zip(other.opened_by_week).map(&:sum),
           closed_by_week: closed_by_week.zip(other.closed_by_week).map(&:sum))
    end

    def total_count = open_count + closed_count

    # The share of issues that are closed, rounded down, as on the Overview.
    def done_percentage = Percentage.of(closed_count, total_count)
  end
end
