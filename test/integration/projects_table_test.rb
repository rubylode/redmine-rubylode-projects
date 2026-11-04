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

# The projects table: its rows and counts, the welcome page block, the {{projects_table}} macro and the partial.
class ProjectsTableTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :enabled_modules, :trackers,
           :projects_trackers, :issue_statuses, :enumerations, :workflows, :issues, :wiki_pages, :wikis, :wiki_contents,
           :custom_fields, :custom_values, :custom_fields_projects, :custom_fields_trackers

  CLOSED_STATUS = 5
  HOSTILE = %(</script><img src=x onerror=alert(1)> "quoted" 'single' & <b>bold</b>).freeze

  def setup
    @previous_plugin_settings = Setting.plugin_redmine_rubylode_projects
    Issue.delete_all
    @parent = Project.generate!(name: "Table parent", is_public: true, tracker_ids: [1, 2])
    @child = Project.generate_with_parent!(@parent, name: "Table child", is_public: true, tracker_ids: [1, 2])
    @other = Project.generate!(name: "Table other", is_public: true, tracker_ids: [1, 2])
  end

  def teardown
    Setting.plugin_redmine_rubylode_projects = @previous_plugin_settings
  end

  def configure(**values)
    Setting.plugin_redmine_rubylode_projects = RubylodeProjects::Settings::DEFAULTS.merge(values.stringify_keys)
  end

  def issue(project, **attributes)
    Issue.generate!({ project: project, author_id: 2, priority_id: 5, tracker_id: 1 }.merge(attributes))
  end

  def row(project) = "tr[data-project-id='#{project.id}']"

  def welcome_with_table
    configure(show_on_welcome_page: "1")
    get "/"
    assert_response :success
  end

  def count_queries
    count = 0
    counter = ->(_name, _start, _finish, _id, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE)/i) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  def render_partial(user: User.find(1), **locals)
    ApplicationController.render(partial: "rubylode_projects/projects_table", locals: { user: user }.merge(locals))
  end

  test "the welcome page shows nothing by default" do
    get "/"
    assert_response :success
    assert_select "[data-rubylode-projects=table]", 0
  end

  test "the welcome page block is on the right by default and on the left when asked" do
    welcome_with_table
    assert_select ".splitcontentright [data-rubylode-projects=table]", 1
    assert_select ".splitcontentleft [data-rubylode-projects=table]", 0
    configure(show_on_welcome_page: "1", welcome_page_column: "left")
    get "/"
    assert_select ".splitcontentleft [data-rubylode-projects=table]", 1
    assert_select ".splitcontentright [data-rubylode-projects=table]", 0
  end

  test "the table has a caption, scoped headers and one row per project, subprojects under their parents and indented" do
    welcome_with_table
    assert_select "table.rubylode-projects-table caption", text: "Projects"
    assert_select "table.rubylode-projects-table thead th[scope=col]", 5
    assert_select "tbody th[scope=row] a", text: "Table parent"
    names = css_select("tbody th[scope=row] a").map(&:text)
    assert_equal [names.index("Table parent") + 1], [names.index("Table child")], "the child follows its parent"
    assert_select "#{row(@parent)} th[style*='--rubylode-projects-table-level: 0']"
    assert_select "#{row(@child)} th[style*='--rubylode-projects-table-level: 1']"
  end

  test "open and closed counts count the issues of the project alone, and link to the filtered list" do
    issue(@parent)
    2.times { issue(@parent, status_id: CLOSED_STATUS) }
    issue(@child)
    issue(@child)
    issue(@child)
    welcome_with_table
    assert_select "#{row(@parent)} a.rubylode-projects-table-open", text: "1"
    assert_select "#{row(@parent)} a.rubylode-projects-table-closed", text: "2"
    assert_select "#{row(@child)} a.rubylode-projects-table-open", text: "3"
    open_link = css_select("#{row(@parent)} a.rubylode-projects-table-open").first["href"]
    closed_link = css_select("#{row(@parent)} a.rubylode-projects-table-closed").first["href"]
    assert_includes open_link, "/projects/#{@parent.identifier}/issues?set_filter=1&f[]=status_id&op[status_id]=o"
    assert_includes open_link, "op[subproject_id]=%21%2A", "the parent's own count excludes its subprojects"
    assert_includes closed_link, "op[status_id]=c"
    leaf_link = css_select("#{row(@other)} a.rubylode-projects-table-open").first["href"]
    refute_includes leaf_link, "subproject_id"
  end

  test "counts only the issues the viewer may see" do
    issue(@other)
    issue(@other, is_private: true, author_id: 3)
    log_user("jsmith", "jsmith")
    welcome_with_table
    assert_select "#{row(@other)} a.rubylode-projects-table-open", text: "1"
  end

  test "an administrator sees the private issue in the count" do
    issue(@other)
    issue(@other, is_private: true, author_id: 3)
    log_user("admin", "admin")
    welcome_with_table
    assert_select "#{row(@other)} a.rubylode-projects-table-open", text: "2"
  end

  test "archived and closed projects are left out" do
    @other.update_column(:status, Project::STATUS_ARCHIVED)
    @child.update_column(:status, Project::STATUS_CLOSED)
    welcome_with_table
    assert_select row(@other), 0
    assert_select row(@child), 0
    assert_select row(@parent), 1
  end

  test "a hostile name and description are escaped" do
    @other.update_columns(name: HOSTILE, description: HOSTILE)
    log_user("admin", "admin")
    welcome_with_table
    refute_includes response.body, "<img src=x"
    refute_includes response.body, "<b>bold</b>"
    assert_select "#{row(@other)} th a", text: HOSTILE
    assert_select "#{row(@other)} td.rubylode-projects-table-description", text: HOSTILE
  end

  test "a long description is cut to one line" do
    @other.update_column(:description, "word " * 100 + "\n\nsecond paragraph")
    welcome_with_table
    text = css_select("#{row(@other)} td.rubylode-projects-table-description").first.text
    assert_operator text.length, :<=, RubylodeProjects::ProjectsTable::DESCRIPTION_LENGTH
    assert text.end_with?("…")
    refute_includes text, "second paragraph"
  end

  test "the description and done bar can be switched off" do
    configure(show_on_welcome_page: "1", projects_table_show_description: "0", projects_table_show_done_bar: "0")
    get "/"
    assert_select "td.rubylode-projects-table-description", 0
    assert_select ".rubylode-projects-table-bar", 0
    assert_select "table.rubylode-projects-table thead th", 3
  end

  test "the done bar shows the share of closed issues" do
    3.times { issue(@other) }
    issue(@other, status_id: CLOSED_STATUS)
    welcome_with_table
    assert_select "#{row(@other)} .rubylode-projects-table-percentage", text: "25%"
    assert_select "#{row(@other)} .rubylode-projects-table-bar-fill[style*='width: 25%']"
  end

  test "the rows are limited by the setting" do
    configure(show_on_welcome_page: "1", maximum_rows: "2")
    get "/"
    assert_select "[data-rubylode-projects=table] tbody tr", 2
  end

  test "the query count stays the same for 3 and 30 projects" do
    log_user("admin", "admin")
    configure(show_on_welcome_page: "1", maximum_rows: "100")
    Project.where("name LIKE 'Table%'").delete_all
    run = lambda do |total|
      created = Array.new(total) { |index| Project.generate!(name: "Counted #{total}-#{index}", is_public: true, tracker_ids: [1]) }
      created.each { |project| issue(project, tracker_id: 1); issue(project, status_id: CLOSED_STATUS) }
      queries = count_queries { get "/" }
      assert_select "[data-rubylode-projects=table] tbody tr[data-project-id]", minimum: total
      created.each(&:destroy)
      queries
    end
    run.call(1) # the first request loads what Rails caches
    few = run.call(3)
    many = run.call(30)
    assert_equal few, many
  end

  test "the table also counts for a viewer with no login" do
    issue(@other)
    welcome_with_table
    assert_select "#{row(@other)} a.rubylode-projects-table-open", text: "1"
  end

  test "the projects page does not get the table" do
    configure(show_on_welcome_page: "1")
    get "/projects"
    assert_response :success
    assert_select "[data-rubylode-projects=table]", 0
  end

  test "the welcome block does not depend on the other summary plugin" do
    original = Redmine::Plugin.method(:installed?)
    Redmine::Plugin.define_singleton_method(:installed?) { |id| id.to_sym == :redmine_projects_dashboard || original.call(id) }
    welcome_with_table
    assert_select "[data-rubylode-projects=table]", 1
    get "/projects"
    assert_select "[data-rubylode-projects=table]", 0
    assert_select "[data-rubylode-projects=summary]", 0
  ensure
    Redmine::Plugin.define_singleton_method(:installed?, original) if original
  end

  test "the macro renders the table in a wiki page" do
    issue(@other)
    page = WikiPage.find(1)
    page.content.update!(text: "Intro\n\n{{projects_table}}")
    get "/projects/#{page.project.identifier}/wiki/#{page.title}"
    assert_response :success
    assert_select "table.rubylode-projects-table caption", text: "Projects"
    assert_select "#{row(@other)} a.rubylode-projects-table-open", text: "1"
    assert_select "link[rel=stylesheet][href*='plugin_assets/redmine_rubylode_projects/projects-']", 1
  end

  test "the macro takes a title, a limit and subprojects=false" do
    issue(@child)
    page = WikiPage.find(1)
    page.content.update!(text: %({{projects_table(title="Mine, all mine", limit=1, subprojects=false)}}))
    get "/projects/#{page.project.identifier}/wiki/#{page.title}"
    assert_select "table.rubylode-projects-table caption", text: "Mine, all mine"
    assert_select "tbody tr", 1
    page.content.update!(text: %({{projects_table(subprojects=false)}}))
    get "/projects/#{page.project.identifier}/wiki/#{page.title}"
    assert_select row(@child), 0
    assert_select "#{row(@parent)} a.rubylode-projects-table-open", text: "1", message: "a top-level project counts everything under it"
    assert_includes css_select("#{row(@parent)} a.rubylode-projects-table-open").first["href"], "op[subproject_id]=%2A"
  end

  test "the macro refuses an unknown argument or a bad limit and escapes the title" do
    page = WikiPage.find(1)
    page.content.update!(text: "{{projects_table(colour=red)}}")
    get "/projects/#{page.project.identifier}/wiki/#{page.title}"
    assert_select "table.rubylode-projects-table", 0
    assert_match(/takes title, limit and subprojects/, response.body)
    page.content.update!(text: "{{projects_table(limit=500)}}")
    get "/projects/#{page.project.identifier}/wiki/#{page.title}"
    assert_match(/whole number from 1 to 100/, response.body)
    page.content.update!(text: %({{projects_table(title="<b>x</b>")}}))
    get "/projects/#{page.project.identifier}/wiki/#{page.title}"
    refute_includes response.body, "<caption><b>x"
  end

  test "the partial renders with its documented locals" do
    issue(@other)
    html = render_partial(title: "Partial title", limit: 100, subprojects: false, show_description: false, show_done_bar: false)
    page = Nokogiri::HTML.fragment(html)
    assert_equal "Partial title", page.at_css("caption").text
    assert_nil page.at_css("td.rubylode-projects-table-description")
    assert_nil page.at_css("tr[data-project-id='#{@child.id}']")
    assert page.at_css("tr[data-project-id='#{@parent.id}']")
  end
end
