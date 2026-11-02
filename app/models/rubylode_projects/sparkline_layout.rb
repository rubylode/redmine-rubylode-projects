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
  # The points of a small line chart in the units of its SVG view box, so the numbers can be tested without a browser.
  # One value per week, oldest first; the line fills the box, with the highest value at the top (a flat zero line sits at the
  # bottom). The view only draws what this computes.
  class SparklineLayout
    WIDTH = 96
    HEIGHT = 26
    PADDING = 3

    Point = Data.define(:x, :y, :value)

    attr_reader :values

    def initialize(values)
      @values = values.map(&:to_i)
    end

    def width = WIDTH

    def height = HEIGHT

    def points
      @points ||= values.each_with_index.map { |value, index| Point.new(x: x_for(index), y: y_for(value), value: value) }
    end

    # "x,y x,y ..." for a polyline.
    def line_points
      points.map { |point| "#{point.x.round(2)},#{point.y.round(2)}" }.join(" ")
    end

    # The same line closed down to the bottom edge, for the faint area under it.
    def area_path
      return "" if points.empty?

      base = HEIGHT - PADDING
      "M#{points.first.x.round(2)},#{base} " + points.map { |point| "L#{point.x.round(2)},#{point.y.round(2)}" }.join(" ") +
        " L#{points.last.x.round(2)},#{base} Z"
    end

    def highest_value = [values.max.to_i, 1].max

    private

    def x_for(index)
      return WIDTH / 2.0 if values.size <= 1

      PADDING + ((WIDTH - (2 * PADDING)).to_f * index / (values.size - 1))
    end

    def y_for(value) = (HEIGHT - PADDING) - ((HEIGHT - (2 * PADDING)).to_f * value / highest_value)
  end
end
