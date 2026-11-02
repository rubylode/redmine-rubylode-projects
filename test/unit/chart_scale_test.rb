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

class RubylodeProjectsChartScaleTest < ActiveSupport::TestCase
  test "round ticks that reach past the highest value" do
    assert_equal [0, 50, 100, 150, 200], RubylodeProjects::ChartScale.new(180).ticks
    assert_equal [0, 2, 4, 6, 8], RubylodeProjects::ChartScale.new(7).ticks
    assert_equal [0, 10, 20, 30], RubylodeProjects::ChartScale.new(23).ticks
  end

  test "a count axis never gets a fractional tick" do
    assert_equal [0, 1, 2], RubylodeProjects::ChartScale.new(2).ticks
    assert_equal [0, 1], RubylodeProjects::ChartScale.new(1).ticks
  end

  test "an empty chart still has an axis" do
    scale = RubylodeProjects::ChartScale.new(0)
    assert_equal [0, 1], scale.ticks
    assert_equal 1, scale.top
  end

  test "an exact round maximum is the top tick" do
    assert_equal 100, RubylodeProjects::ChartScale.new(100).top
  end
end
