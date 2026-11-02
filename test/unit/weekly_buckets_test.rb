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

class RubylodeProjectsWeeklyBucketsTest < ActiveSupport::TestCase
  # A Friday. Its week starts on Monday 2026-10-26, ISO week 44.
  TODAY = Date.new(2026, 10, 30)

  def buckets(week_count: 12)
    RubylodeProjects::WeeklyBuckets.new(today: TODAY, week_count: week_count)
  end

  test "twelve weeks, Monday to Sunday, the last one is the current week" do
    weeks = buckets.weeks(opened_dates: [], closed_dates: [])
    assert_equal 12, weeks.size
    assert_equal Date.new(2026, 10, 26), weeks.last.start_date
    assert_equal Date.new(2026, 11, 1), weeks.last.end_date
    assert_equal Date.new(2026, 8, 10), weeks.first.start_date
    assert_equal 44, weeks.last.number
    assert_equal 33, weeks.first.number
  end

  test "the first day the counts look at is the Monday of the oldest week" do
    assert_equal Date.new(2026, 8, 10), buckets.first_date
    assert_equal Date.new(2026, 10, 19), buckets(week_count: 2).first_date
  end

  test "each date lands in its own week, Sunday with the week before it" do
    opened = [Date.new(2026, 10, 26), Date.new(2026, 10, 30), Date.new(2026, 10, 25)]
    closed = [Date.new(2026, 10, 19)]
    weeks = buckets.weeks(opened_dates: opened, closed_dates: closed)
    assert_equal [2, 0], [weeks.last.opened_count, weeks.last.closed_count]
    assert_equal [1, 1], [weeks[-2].opened_count, weeks[-2].closed_count]
  end

  test "dates before the oldest week or after today are left out" do
    weeks = buckets.weeks(opened_dates: [Date.new(2026, 8, 9), Date.new(2026, 11, 2)], closed_dates: [Date.new(2026, 1, 1)])
    assert_equal 0, weeks.sum(&:opened_count)
    assert_equal 0, weeks.sum(&:closed_count)
  end

  test "the highest count across both series" do
    weeks = buckets.weeks(opened_dates: [TODAY, TODAY], closed_dates: [TODAY, TODAY, TODAY])
    assert_equal 3, RubylodeProjects::WeeklyBuckets.highest_count(weeks)
  end
end
