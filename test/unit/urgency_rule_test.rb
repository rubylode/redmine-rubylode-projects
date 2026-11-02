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

class RubylodeProjectsUrgencyRuleTest < ActiveSupport::TestCase
  NEW_STATUS = 1
  IN_PROGRESS_STATUS = 2

  # Low 1, Normal 2 (the default), High 3, Urgent 4, Immediate 5.
  def rule
    RubylodeProjects::UrgencyRule.new(priority_positions: [1, 2, 3, 4, 5], default_priority_position: 2)
  end

  def listed?(closed: false, priority_position: 2, status_id: NEW_STATUS)
    rule.listed?(closed: closed, priority_position: priority_position, status_id: status_id, tracker_default_status_id: NEW_STATUS)
  end

  test "a priority above the default one is urgent" do
    assert_equal 2, rule.threshold_position
    assert listed?(priority_position: 3)
    assert listed?(priority_position: 5)
  end

  test "an open issue that has left its tracker's first status is in progress" do
    assert listed?(status_id: IN_PROGRESS_STATUS)
    assert rule.in_progress?(closed: false, status_id: IN_PROGRESS_STATUS, tracker_default_status_id: NEW_STATUS)
  end

  test "a new issue at the default priority or lower is not listed" do
    assert_not listed?
    assert_not listed?(priority_position: 1)
  end

  test "a closed issue is never listed, however urgent" do
    assert_not listed?(closed: true, priority_position: 5, status_id: IN_PROGRESS_STATUS)
  end

  test "without a default priority the middle one is the threshold" do
    rule = RubylodeProjects::UrgencyRule.new(priority_positions: [5, 1, 3, 2, 4], default_priority_position: nil)
    assert_equal 3, rule.threshold_position
    rule = RubylodeProjects::UrgencyRule.new(priority_positions: [1, 2, 3, 4], default_priority_position: nil)
    assert_equal 2, rule.threshold_position
  end

  test "without any priority nothing is urgent by priority" do
    rule = RubylodeProjects::UrgencyRule.new(priority_positions: [], default_priority_position: nil)
    assert_not rule.urgent_priority?(10)
  end
end
