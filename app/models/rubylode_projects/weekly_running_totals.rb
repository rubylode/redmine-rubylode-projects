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
  # How many issues were open at the end of each week. The last week ends today, so its figure is the open count now;
  # each earlier week is worked out backwards: undo what the later week opened, add back what it closed.
  class WeeklyRunningTotals
    def initialize(weeks:, open_now:)
      @weeks = weeks
      @open_now = open_now
    end

    # One figure per week, in the order of the weeks.
    def open_at_week_ends
      running = @open_now
      @weeks.reverse.map do |week|
        at_end_of_week = running
        running = running - week.opened_count + week.closed_count
        at_end_of_week
      end.reverse
    end
  end
end
