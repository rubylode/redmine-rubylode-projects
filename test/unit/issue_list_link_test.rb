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

class RubylodeProjectsIssueListLinkTest < ActiveSupport::TestCase
  BASE = "/projects/shop/issues"

  def link(subprojects: nil) = RubylodeProjects::IssueListLink.new(base_path: BASE, subprojects: subprojects)

  def parameters(url) = Rack::Utils.parse_nested_query(url.split("?", 2).last)

  test "an open, closed or any status filter" do
    assert_equal "#{BASE}?set_filter=1&f[]=status_id&op[status_id]=o", link.status(:open)
    assert_equal "#{BASE}?set_filter=1&f[]=status_id&op[status_id]=c", link.status(:closed)
    assert_equal "#{BASE}?set_filter=1&f[]=status_id&op[status_id]=%2A", link.status(:all)
  end

  test "an unknown status is refused" do
    assert_raises(KeyError) { link.status("o&x=1") }
  end

  test "a tracker filter holds the tracker id and the status" do
    url = link.tracker(3, status: :open)
    assert_equal "#{BASE}?set_filter=1&f[]=status_id&op[status_id]=o&f[]=tracker_id&op[tracker_id]=%3D&v[tracker_id][]=3", url
    assert_equal({ "set_filter" => "1", "f" => %w[status_id tracker_id], "op" => { "status_id" => "o", "tracker_id" => "=" },
                   "v" => { "tracker_id" => ["3"] } }, parameters(url))
  end

  test "a tracker id that is not a number is refused" do
    assert_raises(ArgumentError) { link.tracker("3&evil=1") }
    assert_raises(TypeError) { link.tracker(nil) }
  end

  test "opened between filters on the creation date over any status" do
    url = link.opened_between(Date.new(2026, 10, 19), Date.new(2026, 10, 25))
    assert_equal({ "set_filter" => "1", "f" => %w[status_id created_on], "op" => { "status_id" => "*", "created_on" => "><" },
                   "v" => { "created_on" => %w[2026-10-19 2026-10-25] } }, parameters(url))
    assert_includes url, "f[]=created_on&op[created_on]=%3E%3C&v[created_on][]=2026-10-19&v[created_on][]=2026-10-25"
  end

  test "closed between filters on the closing date over any status" do
    url = link.closed_between(Date.new(2026, 12, 28), Date.new(2027, 1, 3))
    assert_equal %w[2026-12-28 2027-01-03], parameters(url).dig("v", "closed_on")
    assert_equal "><", parameters(url).dig("op", "closed_on")
  end

  test "a date range may span a year end and a single day" do
    url = link.opened_between(Date.new(2026, 12, 28), Date.new(2026, 12, 28))
    assert_equal %w[2026-12-28 2026-12-28], parameters(url).dig("v", "created_on")
  end

  test "only dates are accepted as dates" do
    assert_raises(ArgumentError) { link.opened_between("2026-10-19", Date.new(2026, 10, 25)) }
    assert_raises(ArgumentError) { link.closed_between(Date.new(2026, 10, 19), "2026-10-25&x=1") }
  end

  test "subprojects included or excluded add the subproject filter" do
    assert_equal "*", parameters(link(subprojects: :include).status(:open)).dig("op", "subproject_id")
    assert_equal "!*", parameters(link(subprojects: :exclude).status(:open)).dig("op", "subproject_id")
    assert_includes link(subprojects: :include).tracker(2), "&f[]=subproject_id&op[subproject_id]=%2A"
    assert_includes link(subprojects: :exclude).opened_between(Date.new(2026, 1, 1), Date.new(2026, 1, 7)), "&op[subproject_id]=%21%2A"
  end

  test "no subproject choice leaves the filter out" do
    refute_includes link.status(:open), "subproject_id"
  end

  test "an unknown subproject choice is refused" do
    assert_raises(KeyError) { link(subprojects: :everything).status(:open) }
  end

  test "the query holds no unescaped characters and a single question mark" do
    url = link(subprojects: :include).tracker(7, status: :closed)
    assert_equal 1, url.count("?")
    refute_match(/[<>"' ]/, url)
  end
test "overdue means open and due on or before yesterday" do
  query = parameters(link.overdue(Date.new(2026, 11, 2)))
  assert_equal %w[status_id due_date], query["f"]
  assert_equal "o", query.dig("op", "status_id")
  assert_equal "<=", query.dig("op", "due_date")
  assert_equal ["2026-11-01"], query.dig("v", "due_date")
end

test "due between is an open list over a date range" do
  query = parameters(link.due_between(Date.new(2026, 11, 2), Date.new(2026, 11, 9)))
  assert_equal "o", query.dig("op", "status_id")
  assert_equal "><", query.dig("op", "due_date")
  assert_equal %w[2026-11-02 2026-11-09], query.dig("v", "due_date")
end

test "unassigned is open with no assignee" do
  query = parameters(link.unassigned)
  assert_equal %w[status_id assigned_to_id], query["f"]
  assert_equal "!*", query.dig("op", "assigned_to_id")
end

test "project ids limit the list to those projects, before the subproject filter" do
  portfolio = RubylodeProjects::IssueListLink.new(base_path: "/issues", subprojects: :include, project_ids: [3, "7"])
  query = parameters(portfolio.status(:open))
  assert_equal %w[status_id project_id subproject_id], query["f"]
  assert_equal "=", query.dig("op", "project_id")
  assert_equal %w[3 7], query.dig("v", "project_id")
  assert portfolio.status(:open).start_with?("/issues?set_filter=1")
end

test "project ids must be whole numbers" do
  assert_raises(ArgumentError) { RubylodeProjects::IssueListLink.new(base_path: "/issues", project_ids: ["3&x=1"]) }
end

test "an empty list of project ids adds no filter" do
  refute_includes RubylodeProjects::IssueListLink.new(base_path: "/issues", project_ids: []).status(:open), "project_id"
end
end
