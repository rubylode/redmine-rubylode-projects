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
  # Where everything goes in the opened-against-closed bar chart, in the units of the SVG view box.
  # The view only draws what this computes, so the numbers can be tested without a browser.
  class WeeklyChartLayout
    Bar = Data.define(:series, :week, :count, :x, :y, :width, :height)
    Label = Data.define(:text, :x, :y)
    GridLine = Data.define(:value, :y)
    Slot = Data.define(:week, :x, :width)

    WIDTH = 720
    HEIGHT = 260
    MARGIN_LEFT = 40
    MARGIN_RIGHT = 8
    MARGIN_TOP = 10
    MARGIN_BOTTOM = 26
    BAR_SHARE_OF_SLOT = 0.34
    GAP_BETWEEN_PAIR = 3

    attr_reader :weeks

    def initialize(weeks)
      @weeks = weeks
    end

    def width = WIDTH

    def height = HEIGHT

    def plot_left = MARGIN_LEFT

    def plot_right = WIDTH - MARGIN_RIGHT

    def plot_top = MARGIN_TOP

    def plot_bottom = HEIGHT - MARGIN_BOTTOM

    def plot_height = plot_bottom - plot_top

    def scale
      @scale ||= ChartScale.new(WeeklyBuckets.highest_count(weeks))
    end

    def bars
      @bars ||= weeks.each_with_index.flat_map do |week, index|
        left = slot_center(index) - bar_width - (GAP_BETWEEN_PAIR / 2.0)
        [bar(:opened, week, week.opened_count, left),
         bar(:closed, week, week.closed_count, left + bar_width + GAP_BETWEEN_PAIR)]
      end
    end

    def week_labels
      weeks.each_with_index.map { |week, index| Label.new(text: "W#{week.number}", x: slot_center(index), y: HEIGHT - 8) }
    end

    # The full-height column of each week, which the hover highlight and the click target cover.
    def week_slots
      weeks.each_with_index.map { |week, index| Slot.new(week: week, x: plot_left + (slot_width * index), width: slot_width) }
    end

    def grid_lines
      scale.ticks.map { |tick| GridLine.new(value: tick, y: y_for(tick)) }
    end

    private

    def slot_width = (plot_right - plot_left).to_f / [weeks.size, 1].max

    def slot_center(index) = plot_left + (slot_width * index) + (slot_width / 2)

    def bar_width = slot_width * BAR_SHARE_OF_SLOT

    def y_for(value) = plot_bottom - bar_height_for(value)

    def bar_height_for(count) = plot_height * count.to_f / scale.top

    def bar(series, week, count, x)
      Bar.new(series: series, week: week, count: count, x: x, y: y_for(count), width: bar_width, height: bar_height_for(count))
    end
  end
end
