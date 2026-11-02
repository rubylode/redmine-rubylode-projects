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

class RubylodeProjectsProjectOverviewTest < ActiveSupport::TestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :enabled_modules, :trackers,
           :projects_trackers, :issue_statuses, :enumerations, :issues

  def overview(user)
    RubylodeProjects::ProjectOverview.new(Project.find(1), user: user)
  end

  test "the SQL for the in-progress-and-urgent list picks the same issues as the rule" do
    [User.find(1), User.find(2), User.anonymous].each do |user|
      project_overview = overview(user)
      rule = project_overview.urgency_rule
      expected = Issue.visible(user).where(Project.find(1).project_condition(Setting.display_subprojects_issues?))
                      .includes(:status, :priority, :tracker).select do |issue|
        rule.listed?(closed: issue.closed?, priority_position: issue.priority.position, status_id: issue.status_id,
                     tracker_default_status_id: issue.tracker.default_status_id)
      end
      assert_equal expected.map(&:id).sort, project_overview.urgent_issues(limit: nil).map(&:id).sort, "for #{user.login.presence || 'anonymous'}"
      assert_equal expected.size, project_overview.urgent_issue_count
    end
  end

  test "the tracker tallies add up to every issue the user can see" do
    user = User.find(2)
    totals = overview(user).totals
    scope = Issue.visible(user).where(Project.find(1).project_condition(Setting.display_subprojects_issues?))
    assert_equal scope.count, totals.total_count
    assert_equal scope.open.count, totals.open_count
  end
end
