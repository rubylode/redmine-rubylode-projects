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

class RubylodeProjectsPercentageTest < ActiveSupport::TestCase
  test "a whole percent, rounded down" do
    assert_equal 82, RubylodeProjects::Percentage.of(5662, 6871)
    assert_equal 99, RubylodeProjects::Percentage.of(446, 449)
  end

  test "100 only when every one is counted" do
    assert_equal 99, RubylodeProjects::Percentage.of(999, 1000)
    assert_equal 100, RubylodeProjects::Percentage.of(1000, 1000)
  end

  test "nothing out of nothing is zero, not an error" do
    assert_equal 0, RubylodeProjects::Percentage.of(0, 0)
    assert_equal 0, RubylodeProjects::Percentage.of(0, nil)
  end
end
