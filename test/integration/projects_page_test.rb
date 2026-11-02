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

# The projects list at /projects: pages for the board view, and Redmine's own pages for the list view.
class ProjectsPageTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :enabled_modules, :trackers,
           :projects_trackers, :issue_statuses, :enumerations

  # The fixtures have two top projects for the administrator: eCookbook (with four subprojects) and OnlineStore.
  # Three more make five trees.
  def setup
    %w[Gamma Delta Epsilon].each { |name| Project.generate!(name: "Generated #{name}", is_public: true) }
    log_user("admin", "admin")
  end

  def board_project_names
    css_select("#projects-index a.project").map { |link| link.text.strip }
  end

  test "the plugin is registered with its name and version" do
    plugin = Redmine::Plugin.find(:redmine_rubylode_projects)
    assert_equal "Rubylode Projects", plugin.name
    assert_equal "0.5.1", plugin.version
  end

  test "the board view shows a page of whole trees and Redmine's page links" do
    with_settings per_page_options: "2,5", project_list_display_type: "board" do
      get "/projects", params: { display_type: "board", per_page: 2 }
      assert_response :success
      assert_select "span.pagination ul.pages li.current", text: "1"
      assert_select "span.pagination span.items", text: "(1-2/5)"
      assert_select "span.pagination span.per-page"

      pages = (1..3).map do |page|
        get "/projects", params: { display_type: "board", per_page: 2, page: page }
        board_project_names
      end
      assert_equal [2, 2, 1], pages.map { |names| names.count { |name| Project.find_by(name: name).parent_id.nil? } }
      assert_equal Project.visible(User.find(1)).count, pages.flatten.uniq.size, "every project shows on exactly one page"
      assert_equal pages.flatten.size, pages.flatten.uniq.size
      ecookbook_page = pages.find { |names| names.include?("eCookbook") }
      assert_includes ecookbook_page, "eCookbook Subproject 1", "a subproject stays on its parent's page"
    end
  end

  test "the board is paged for a client that accepts any format, not only a browser" do
    with_settings per_page_options: "2,5", project_list_display_type: "board" do
      get "/projects", params: { display_type: "board", per_page: 2 }, headers: { "Accept" => "*/*" }
      assert_response :success
      assert_select "span.pagination span.items", text: "(1-2/5)"
    end
  end

  test "board filters still apply before the pages are cut" do
    with_settings per_page_options: "2,5", project_list_display_type: "board" do
      get "/projects", params: { display_type: "board", set_filter: 1, f: ["name", ""], op: { name: "~" }, v: { name: ["Generated"] }, per_page: 2 }
      assert_response :success
      assert_equal 2, board_project_names.size
      assert board_project_names.all? { |name| name.start_with?("Generated") }
      assert_select "span.pagination span.items", text: "(1-2/3)"
    end
  end

  test "the list view keeps Redmine's pages, and the page links carry the sort" do
    with_settings per_page_options: "2,5" do
      get "/projects", params: { display_type: "list", per_page: 2, sort: "name" }
      assert_response :success
      assert_select "table.projects tbody tr", 2
      assert_select "span.pagination a[href*=?]", "sort=name"
      assert_select "span.pagination span.items", text: %r{\(1-2/\d+\)}
    end
  end

  test "the projects list loads the stylesheet, and the old placeholder is gone" do
    get "/projects"
    assert_response :success
    assert_select "link[href*=?]", "plugin_assets/redmine_rubylode_projects/projects"
    assert_select "div.rubylode-projects-placeholder", 0
  end
end
