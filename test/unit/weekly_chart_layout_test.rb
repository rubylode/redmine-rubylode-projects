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

class RubylodeProjectsWeeklyChartLayoutTest < ActiveSupport::TestCase
  Week = RubylodeProjects::WeeklyBuckets::Week

  def weeks
    [Week.new(start_date: Date.new(2026, 10, 12), opened_count: 4, closed_count: 0),
     Week.new(start_date: Date.new(2026, 10, 19), opened_count: 8, closed_count: 2),
     Week.new(start_date: Date.new(2026, 10, 26), opened_count: 1, closed_count: 6)]
  end

  def layout
    RubylodeProjects::WeeklyChartLayout.new(weeks)
  end

  test "two bars a week, opened then closed" do
    assert_equal 6, layout.bars.size
    assert_equal %i[opened closed opened closed opened closed], layout.bars.map(&:series)
  end

  test "the tallest bar stands as high as its count on the scale" do
    tallest = layout.bars.max_by(&:height)
    assert_equal 8, tallest.count
    assert_in_delta layout.plot_height * 8 / layout.scale.top, tallest.height, 0.01
    assert_in_delta layout.plot_bottom - tallest.height, tallest.y, 0.01
  end

  test "each week has a full-width column that covers its two bars" do
    slots = layout.week_slots
    assert_equal weeks, slots.map(&:week)
    assert_in_delta layout.plot_right - layout.plot_left, slots.sum(&:width), 0.01
    assert_in_delta layout.plot_left, slots.first.x, 0.01
    slots.each do |slot|
      bars = layout.bars.select { |bar| bar.week == slot.week }
      assert bars.all? { |bar| bar.x >= slot.x && bar.x + bar.width <= slot.x + slot.width }
    end
  end

  test "a zero count draws no bar height" do
    assert_equal 0, layout.bars.find { |bar| bar.count.zero? }.height
  end

  test "bars stay inside the plot, left to right in week order" do
    xs = layout.bars.map(&:x)
    assert_equal xs.sort, xs
    assert layout.bars.all? { |bar| bar.x >= layout.plot_left && bar.x + bar.width <= layout.plot_right }
  end

  test "one label per week, centred under its pair of bars, and one grid line per tick" do
    assert_equal %w[W42 W43 W44], layout.week_labels.map(&:text)
    first_pair = layout.bars.first(2)
    assert_in_delta (first_pair.first.x + first_pair.last.x + first_pair.last.width) / 2.0, layout.week_labels.first.x, 0.01
    assert_equal layout.scale.ticks.size, layout.grid_lines.size
    assert_in_delta layout.plot_bottom, layout.grid_lines.first.y, 0.01
  end
end
