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

class RubylodeProjectsWeeklyTrackerBreakdownTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 10, 30)
  CURRENT_MONDAY = Date.new(2026, 10, 26)

  def breakdown(opened, limit: 3, week_count: 4)
    RubylodeProjects::WeeklyTrackerBreakdown.new(opened: opened, today: TODAY, week_count: week_count, limit: limit).top_trackers_by_week
  end

  test "every week of the window has an entry, empty when nothing was opened" do
    result = breakdown([])
    assert_equal 4, result.size
    assert_equal [Date.new(2026, 10, 5), Date.new(2026, 10, 12), Date.new(2026, 10, 19), CURRENT_MONDAY], result.keys
    assert result.values.all?(&:empty?)
  end

  test "the biggest trackers come first, ties by tracker id, cut at the limit" do
    opened = [[Date.new(2026, 10, 27), 2], [Date.new(2026, 10, 28), 2], [Date.new(2026, 10, 28), 1], [Date.new(2026, 10, 29), 3],
              [Date.new(2026, 10, 29), 4], [Date.new(2026, 10, 30), 4]]
    assert_equal [[2, 2], [4, 2], [1, 1]], breakdown(opened).fetch(CURRENT_MONDAY)
    assert_equal [[2, 2]], breakdown(opened, limit: 1).fetch(CURRENT_MONDAY)
  end

  test "dates before the window and after today are ignored" do
    opened = [[Date.new(2026, 9, 1), 1], [Date.new(2026, 10, 31), 1]]
    assert breakdown(opened).values.all?(&:empty?)
  end

  test "weeks run Monday to Sunday" do
    opened = [[Date.new(2026, 10, 18), 5], [Date.new(2026, 10, 19), 6]]
    result = breakdown(opened)
    assert_equal [[5, 1]], result.fetch(Date.new(2026, 10, 12))
    assert_equal [[6, 1]], result.fetch(Date.new(2026, 10, 19))
  end
end
