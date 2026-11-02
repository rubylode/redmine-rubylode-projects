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

class RubylodeProjectsIssueTotalsTest < ActiveSupport::TestCase
  def tally(name, open_count, closed_count)
    RubylodeProjects::TrackerTally.new(tracker: name, open_count: open_count, closed_count: closed_count)
  end

  test "a tracker tally knows its total and how much of it is done" do
    task = tally("Task", 1073, 4377)
    assert_equal 5450, task.total_count
    assert_equal 80, task.done_percentage
  end

  test "a tracker with no issues is zero percent done" do
    assert_equal 0, tally("Empty", 0, 0).done_percentage
  end

  test "totals add up the trackers" do
    totals = RubylodeProjects::IssueTotals.new([tally("Task", 1073, 4377), tally("Feature", 133, 839), tally("Bug", 3, 446)])
    assert_equal 1209, totals.open_count
    assert_equal 5662, totals.closed_count
    assert_equal 6871, totals.total_count
    assert_equal 82, totals.done_percentage
  end

  test "the open split lists trackers with open issues, most first" do
    totals = RubylodeProjects::IssueTotals.new([tally("Bug", 3, 446), tally("Support", 0, 12), tally("Task", 1073, 4377)])
    assert_equal [["Task", 1073], ["Bug", 3]], totals.open_by_tracker.map { |each_tally| [each_tally.tracker, each_tally.open_count] }
  end

  test "no trackers means zero everywhere" do
    totals = RubylodeProjects::IssueTotals.new([])
    assert_equal [0, 0, 0, 0], [totals.open_count, totals.closed_count, totals.total_count, totals.done_percentage]
    assert_empty totals.open_by_tracker
  end
end
