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

require_relative "../test_helper"

class RubylodeProjectsWeeklyRunningTotalsTest < ActiveSupport::TestCase
  Week = RubylodeProjects::WeeklyBuckets::Week

  def week(day, opened, closed) = Week.new(start_date: Date.new(2026, 10, day), opened_count: opened, closed_count: closed)

  test "the last week ends with the open count now, earlier weeks are worked out backwards" do
    weeks = [week(5, 4, 1), week(12, 2, 2), week(19, 0, 3), week(26, 5, 0)]
    # End of week 4: 10. End of week 3: 10 - 5 + 0 = 5. Week 2: 5 - 0 + 3 = 8. Week 1: 8 - 2 + 2 = 8.
    assert_equal [8, 8, 5, 10], RubylodeProjects::WeeklyRunningTotals.new(weeks: weeks, open_now: 10).open_at_week_ends
  end

  test "an empty window gives no figures" do
    assert_equal [], RubylodeProjects::WeeklyRunningTotals.new(weeks: [], open_now: 3).open_at_week_ends
  end

  test "weeks with nothing in them repeat the figure" do
    weeks = [week(5, 0, 0), week(12, 0, 0)]
    assert_equal [7, 7], RubylodeProjects::WeeklyRunningTotals.new(weeks: weeks, open_now: 7).open_at_week_ends
  end
end
