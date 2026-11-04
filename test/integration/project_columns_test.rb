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

# The columns the plugin adds to the project list: registration, cells, links, CSV and the sparkline's data.
class ProjectColumnsTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :enabled_modules, :trackers,
           :projects_trackers, :issue_statuses, :enumerations, :workflows, :issues, :custom_fields, :custom_values,
           :custom_fields_projects, :custom_fields_trackers, :queries

  CLOSED_STATUS = 5

  def setup
    @previous_plugin_settings = Setting.plugin_redmine_rubylode_projects
    Issue.delete_all
    @today = User.find(1).today
    @parent = Project.generate!(name: "Columns parent", is_public: true, tracker_ids: [1])
    @child = Project.generate_with_parent!(@parent, name: "Columns child", is_public: true, tracker_ids: [1])
    log_user("admin", "admin")
    3.times { issue(@parent) }
    issue(@parent, due_date: @today - 2)
    issue(@child)
    issue(@child, status_id: CLOSED_STATUS, created_on: 20.days.ago, closed_on: 2.days.ago)
    issue(@child, status_id: CLOSED_STATUS, created_on: 50.days.ago, closed_on: 30.days.ago)
  end

  def teardown
    Setting.plugin_redmine_rubylode_projects = @previous_plugin_settings
  end

  def issue(project, **attributes)
    created_on = attributes.delete(:created_on)
    closed_on = attributes.delete(:closed_on)
    Issue.generate!({ project: project, author_id: 2, priority_id: 5, tracker_id: 1 }.merge(attributes)).tap do |created|
      created.update_columns(created_on: created_on) if created_on
      created.update_columns(closed_on: closed_on) if closed_on
    end
  end

  def list(**params)
    get "/projects", params: { set_filter: 1, f: %w[name status], op: { name: "~", status: "=" }, v: { name: ["Columns"], status: ["1"] } }.merge(params)
    assert_response :success
  end

  def configure(**values)
    Setting.plugin_redmine_rubylode_projects = RubylodeProjects::Settings::DEFAULTS.merge(values.stringify_keys)
  end

  def cells(project, column) = css_select("tr#project-#{project.id} td.#{column}").first

  test "the five columns are registered on the project query, with captions, and none is sortable" do
    columns = ProjectQuery.new(name: "_").available_columns.select { |column| RubylodeProjects::ProjectColumns.own_name?(column.name) }
    assert_equal %i[rubylode_open_issues rubylode_overdue_issues rubylode_closed_week rubylode_percent_done rubylode_trend], columns.map(&:name)
    assert_equal ["Open issues", "Overdue", "Closed (last 7 days)", "% done", "Trend"], columns.map(&:caption)
    refute(columns.any?(&:sortable?))
  end

  test "registering twice adds nothing twice" do
    RubylodeProjects::ColumnRegistration.register
    names = ProjectQuery.available_columns.map(&:name)
    assert_equal names.uniq, names
  end

  test "the default list shows name, identifier, description, open, overdue, % done and trend" do
    list
    assert_equal ["Name", "Identifier", "Description", "Open issues", "Overdue", "% done", "Trend"],
                 css_select("table.projects thead th").map { |heading| heading.text.strip }
  end

  test "open and overdue cells hold the counts, with the subprojects of a parent counted in" do
    list
    assert_equal "5", cells(@parent, "rubylode_open_issues").text.strip
    assert_equal "1", cells(@parent, "rubylode_overdue_issues").text.strip
    assert_equal "1", cells(@child, "rubylode_open_issues").text.strip
    assert_equal "0", cells(@child, "rubylode_overdue_issues").text.strip
    assert_select "tr#project-#{@parent.id} td.rubylode_overdue_issues a.rubylode-projects-count-overdue"
    assert_select "tr#project-#{@child.id} td.rubylode_overdue_issues a", 0
  end

  test "each cell's number is the number of issues on the list it links to" do
    columns = %w[name rubylode_open_issues rubylode_overdue_issues rubylode_closed_week]
    %w[rubylode_open_issues rubylode_overdue_issues rubylode_closed_week].each do |column|
      [@parent, @child].each do |project|
        list(c: columns)
        cell = cells(project, column)
        number = cell.text.strip.to_i
        link = cell.at_css("a")
        next assert_equal(0, number) unless link

        get link["href"] + "&per_page=100"
        assert_equal number, css_select("table.issues tbody tr.issue").size, "#{column} of #{project.name}"
      end
    end
  end

  test "the closed cell counts the last seven days only, the parent's with its subproject's" do
    list(c: %w[name rubylode_closed_week])
    assert_equal "1", cells(@child, "rubylode_closed_week").text.strip, "closed two days ago counts, thirty days ago does not"
    assert_equal "1", cells(@parent, "rubylode_closed_week").text.strip
  end

  test "the percent done cell shows a thin bar and the share of issues closed" do
    list
    assert_select "tr#project-#{@child.id} td.rubylode_percent_done a.rubylode-projects-progress" do
      assert_select ".rubylode-projects-progress-fill[style*='width: 66%']"
      assert_select ".rubylode-projects-progress-label", text: "66%"
    end
    assert_select "tr#project-#{@parent.id} .rubylode-projects-progress-label", text: "28%", count: 1
  end

  test "a project without issues shows a dash instead of a bar" do
    empty = Project.generate!(name: "Columns empty", is_public: true, tracker_ids: [1])
    list
    assert_equal "–", cells(empty, "rubylode_percent_done").text.strip
    assert_equal "0", cells(empty, "rubylode_open_issues").text.strip
  end

  test "the trend cell holds a labelled sparkline and its data is in the page's data block" do
    list
    assert_select "tr#project-#{@child.id} td.rubylode_trend [data-rubylode-spark='#{@child.id}'][role=img][tabindex='0']" do |sparks|
      assert_match(/Closed per week over the last 12 weeks, oldest first: (\d+, ){11}\d+/, sparks.first["aria-label"])
    end
    assert_select "tr#project-#{@child.id} svg.rubylode-spark-graphic polyline.rubylode-spark-line"
    block = JSON.parse(css_select("script[data-rubylode-overview-data]").first.text)
    spark = block["sparks"]["projects"][@child.id.to_s]
    assert_equal 12, spark["closed"].size
    assert_equal "/projects/#{@child.identifier}/issues", spark["base"]
    assert_equal "", spark["subprojects"]
    assert_equal "include", block["sparks"]["projects"][@parent.id.to_s]["subprojects"]
    assert_includes block["sparks"]["subprojectFilter"]["include"], "subproject_id"
    assert_equal 12, block["sparks"]["weeks"].size
    assert block["sparks"]["weeks"].first["closedQuery"].start_with?("?set_filter=1")
  end

  test "the sparkline's weekly figures add up to what the project closed and opened in the window" do
    list
    spark = JSON.parse(css_select("script[data-rubylode-overview-data]").first.text)["sparks"]["projects"][@child.id.to_s]
    assert_equal 2, spark["closed"].sum, "the closes two and thirty days ago are both within twelve weeks"
    assert_equal 3, spark["opened"].sum, "one open issue and the two that were closed were all created within twelve weeks"
    assert_equal 1, spark["opened"].last, "the open one was created this week"
  end

  test "the hidden trend table repeats the figures for every project and week" do
    list
    assert_select "table[data-rubylode-trend-table] tbody tr", 2
    assert_select "table[data-rubylode-trend-table] tr[data-project-id='#{@child.id}'] td", 12
  end

  test "sorting by an added column is ignored, not an error" do
    get "/projects", params: { set_filter: 1, sort: "rubylode_open_issues" }
    assert_response :success
  end

  test "columns picked in the options are shown, in the order picked" do
    list(c: %w[name rubylode_trend rubylode_open_issues])
    assert_equal ["Name", "Trend", "Open issues"], css_select("table.projects thead th").map { |heading| heading.text.strip }
    list(c: %w[name status])
    assert_select "[data-rubylode-spark]", 0
    assert_select "script[data-rubylode-overview-data]" # the summary's data is still there
  end

  test "the CSV export has the added columns as plain text" do
    get "/projects.csv", params: { set_filter: 1, f: %w[name status], op: { name: "~", status: "=" }, v: { name: ["Columns"], status: ["1"] } }
    assert_response :success
    rows = CSV.parse(response.body, headers: true)
    assert_equal ["Name", "Identifier", "Description", "Open issues", "Overdue", "% done", "Trend"], rows.headers
    parent = rows.find { |row| row["Name"] == "Columns parent" }
    assert_equal ["5", "1", "28%"], parent.values_at("Open issues", "Overdue", "% done")
    assert_match(/\A(\d+ ){11}\d+\z/, parent["Trend"])
    refute_match(/[<>]/, response.body)
    child = rows.find { |row| row["Name"] == "Columns child" }
    assert_equal ["1", "0", "66%"], child.values_at("Open issues", "Overdue", "% done")
  end

  test "a CSV export of the closed column and last activity" do
    get "/projects.csv", params: { set_filter: 1, c: %w[name rubylode_closed_week last_activity_date], f: ["name"], op: { name: "~" }, v: { name: ["Columns child"] } }
    rows = CSV.parse(response.body, headers: true)
    assert_equal ["Name", "Closed (last 7 days)", "Last activity"], rows.headers
    assert_equal "1", rows.first["Closed (last 7 days)"]
  end

  test "Last activity is Redmine's own column, offered by the settings and not added a second time" do
    Setting.plugin_redmine_rubylode_projects = RubylodeProjects::Settings::DEFAULTS.merge("added_columns" => %w[open_issues last_activity])
    list
    headings = css_select("table.projects thead th").map { |heading| heading.text.strip }
    assert_equal ["Name", "Identifier", "Description", "Open issues", "Last activity"], headings
  end

  test "the added columns follow the default columns when the list names none" do
    configure(added_columns: %w[open_issues overdue])
    get "/projects"
    names = css_select("table.projects thead th").map { |heading| heading.text.strip }
    assert_equal %w[Name Identifier Description], names.first(3)
    assert_equal ["Open issues", "Overdue"], names.last(2)
  end

  test "a list that picks its own columns is not given the added ones" do
    configure(added_columns: %w[open_issues overdue])
    get "/projects", params: { set_filter: 1, c: %w[name status] }
    assert_equal %w[Name Status], css_select("table.projects thead th").map { |heading| heading.text.strip }
  end
end
