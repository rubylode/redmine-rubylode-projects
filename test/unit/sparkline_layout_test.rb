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

require_relative "../test_helper"

class RubylodeProjectsSparklineLayoutTest < ActiveSupport::TestCase
  def layout(values) = RubylodeProjects::SparklineLayout.new(values)

  test "the highest week touches the top padding and zero sits on the bottom" do
    points = layout([0, 4, 2]).points
    assert_in_delta 3.0, points[1].y, 0.001
    assert_in_delta 23.0, points[0].y, 0.001
    assert_in_delta 13.0, points[2].y, 0.001
  end

  test "the weeks are spread from the left padding to the right padding" do
    points = layout([1, 1, 1, 1]).points
    assert_in_delta 3.0, points.first.x, 0.001
    assert_in_delta 93.0, points.last.x, 0.001
    assert_in_delta 33.0, points[1].x, 0.001
  end

  test "all zeros is a flat line at the bottom, not a division by zero" do
    assert_equal [23.0], layout([0, 0, 0]).points.map(&:y).uniq
  end

  test "one value is centered and no values is empty" do
    assert_in_delta 48.0, layout([5]).points.first.x, 0.001
    assert_empty layout([]).points
    assert_equal "", layout([]).area_path
  end

  test "the line and area strings carry every point" do
    sparkline = layout([1, 2])
    assert_equal 2, sparkline.line_points.split.size
    assert_match(/\AM3\.0,23 L3\.0,13\.0 L93\.0,3\.0 L93\.0,23 Z\z/, sparkline.area_path)
  end

  test "values are read as whole numbers" do
    assert_equal [1, 0, 3], layout(["1", nil, 3]).values
  end
end
