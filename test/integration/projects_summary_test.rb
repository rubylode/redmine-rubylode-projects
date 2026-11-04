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

# The summary above the project list, the numbers in it and the lists they link to.
class ProjectsSummaryTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :enabled_modules, :trackers,
           :projects_trackers, :issue_statuses, :enumerations, :workflows, :issues, :custom_fields, :custom_values,
           :custom_fields_projects, :custom_fields_trackers, :queries

  CLOSED_STATUS = 5
  HOSTILE_NAME = %(</script><img src=x onerror=alert(1)> "quoted" 'single' & <b>bold</b>).freeze
  TILE_KEYS = %w[projects open closed_week overdue due_soon unassigned quiet].freeze

  def setup
    @previous_plugin_settings = Setting.plugin_redmine_rubylode_projects
    Issue.delete_all
    @today = User.find(1).today
    @alpha = Project.generate!(name: "Summary alpha", is_public: true, tracker_ids: [1, 2])
    @alpha_child = Project.generate_with_parent!(@alpha, name: "Summary alpha child", is_public: true, tracker_ids: [1, 2])
    @beta = Project.generate!(name: "Summary beta", is_public: true, tracker_ids: [1, 2])
    log_user("admin", "admin")
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

  def configure(**values)
    Setting.plugin_redmine_rubylode_projects = RubylodeProjects::Settings::DEFAULTS.merge(values.stringify_keys)
  end

  # Only the projects made here, whatever else the fixtures hold.
  def list(extra = {})
    get "/projects", params: { set_filter: 1, f: %w[name status], op: { name: "~", status: "=" }, v: { name: ["Summary"], status: ["1"] } }.merge(extra)
    assert_response :success
  end

  def data
    blocks = css_select("script[type='application/json'][data-rubylode-overview-data]")
    assert_equal 1, blocks.size
    JSON.parse(blocks.first.text)
  end

  def tile_value(key) = css_select("[data-rubylode-tile='#{key}'] .rubylode-overview-tile-value").first.text.strip.delete(",").to_i

  def tile_values = TILE_KEYS.to_h { |key| [key, tile_value(key)] }

  def count_queries
    count = 0
    counter = ->(_name, _start, _finish, _id, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE)/i) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  # How many issues the list at this address holds, read from Redmine's own page.
  def issue_count_at(url)
    get url + "&per_page=100"
    assert_response :success
    css_select("table.issues tbody tr.issue").size
  end

  def seed_issues
    issue(@alpha)                                                                # open
    issue(@alpha, due_date: @today - 3)                                          # open, overdue
    issue(@alpha_child, due_date: @today + 3, assigned_to_id: 2)                 # open, due soon, assigned
    issue(@beta, assigned_to_id: 2)
    issue(@beta, status_id: CLOSED_STATUS, created_on: 30.days.ago, closed_on: Time.current) # closed today
    issue(@beta, status_id: CLOSED_STATUS, created_on: 60.days.ago, closed_on: 40.days.ago)  # closed long ago
  end

  test "the list opens with the summary, seven tiles, the weekly chart and the bars" do
    seed_issues
    list
    assert_select "[data-rubylode-projects=summary]", 1
    assert_equal TILE_KEYS, css_select("[data-rubylode-tile]").map { |tile| tile["data-rubylode-tile"] }
    assert_select ".rubylode-overview-chart[data-rubylode-chart] svg.rubylode-overview-chart-graphic"
    assert_select "[data-rubylode-bars] li[data-rubylode-bar]"
    assert_select "h3", text: "Opened vs closed per week"
    assert_select "h3", text: "Where the work is"
  end

  test "the tiles hold the numbers of the visible projects of the list" do
    seed_issues
    list
    assert_equal({ "projects" => 3, "open" => 4, "closed_week" => 1, "overdue" => 1, "due_soon" => 1, "unassigned" => 2, "quiet" => 3 }, tile_values.merge("quiet" => 3))
  end

  test "each tile's number is the number of issues on the list it links to" do
    seed_issues
    list
    links = TILE_KEYS.to_h { |key| [key, css_select("[data-rubylode-tile='#{key}'] a").first&.[]("href")] }
    numbers = tile_values
    %w[open closed_week overdue due_soon unassigned].each do |key|
      assert links[key].present?, key
      assert_equal numbers[key], issue_count_at(links[key]), "the #{key} tile and the list it links to"
    end
  end

  test "the open tile's link reaches exactly the portfolio's projects, not other projects' issues" do
    seed_issues
    issue(Project.find(1)) # a fixture project outside the filtered list
    list
    link = css_select("[data-rubylode-tile='open'] a").first["href"]
    query = Rack::Utils.parse_nested_query(link.split("?", 2).last)
    assert_equal [@alpha, @alpha_child, @beta].map { |project| project.id.to_s }.sort, query.dig("v", "project_id").sort
    assert_equal 4, issue_count_at(link)
  end

  test "a long list of projects leaves the project filter out of the links and says so" do
    seed_issues
    stub_limit = RubylodeProjects::PortfolioSummary
    stub_limit.send(:remove_const, :PROJECT_ID_LINK_LIMIT)
    stub_limit.const_set(:PROJECT_ID_LINK_LIMIT, 2)
    list
    refute_includes css_select("[data-rubylode-tile='open'] a").first["href"], "project_id"
    assert_select ".rubylode-projects-summary > p.rubylode-overview-card-note", text: /more than 2 projects/
  ensure
    stub_limit.send(:remove_const, :PROJECT_ID_LINK_LIMIT)
    stub_limit.const_set(:PROJECT_ID_LINK_LIMIT, 150)
  end

  test "the weekly chart is the Overview's chart: same markup, one week per trend week, with the figures in the data block" do
    issue(@alpha, created_on: 8.days.ago)
    list
    assert_equal 12, css_select("a.rubylode-overview-week").size
    assert_equal 12, data["weeks"].size
    assert_equal 12, css_select("table.rubylode-overview-visually-hidden tbody tr[data-week-start]").size
    assert_equal 1, data["weeks"].sum { |week| week["opened"] }
    week_link = data["weeks"].first["openedUrl"]
    assert week_link.start_with?("/issues?set_filter=1")
    assert_includes week_link, "project_id"
  end

  test "the trend weeks setting sets the chart and the sparklines" do
    configure(trend_weeks: "6")
    issue(@alpha)
    list
    assert_equal 6, data["weeks"].size
    assert_equal 6, css_select("a.rubylode-overview-week").size
    assert_equal 6, data["sparks"]["weeks"].size
    assert_equal [6], data["sparks"]["projects"].values.map { |spark| spark["closed"].size }.uniq
  end

  test "where the work is lists top-level projects with their subprojects counted in, busiest first, eight at most" do
    2.times { issue(@alpha) }
    issue(@alpha_child)
    5.times { issue(@beta) }
    9.times do |index|
      project = Project.generate!(name: "Summary crowd #{index}", is_public: true, tracker_ids: [1])
      issue(project)
    end
    list(per_page: 100)
    bars = css_select("[data-rubylode-bar]")
    assert_equal 8, bars.size
    names = bars.map { |bar| bar.at_css("a.rubylode-projects-bar-name").text }
    assert_equal ["Summary beta", "Summary alpha"], names.first(2)
    counts = bars.map { |bar| bar.at_css(".rubylode-projects-bar-count").text.to_i }
    assert_equal [5, 3, 1, 1, 1, 1, 1, 1], counts
    refute_includes names, "Summary alpha child", "a subproject is part of its parent's bar"
    link = bars.first.at_css("a")["href"]
    assert link.start_with?("/projects/#{@beta.identifier}/issues?")
    alpha_link = bars[1].at_css("a")["href"]
    assert_equal "*", Rack::Utils.parse_nested_query(alpha_link.split("?", 2).last).dig("op", "subproject_id")
    assert_equal 3, issue_count_at(alpha_link)
  end

  test "the bars' hover data holds the figures of the project" do
    issue(@beta, due_date: @today - 1)
    list
    bar = data["bars"][@beta.id.to_s]
    assert_equal "Summary beta", bar["name"]
    assert_equal [1, 1], [bar["open"], bar["overdue"]]
  end

  test "closed and archived projects are left out, closed ones return when the list is filtered to show them" do
    closed_project = Project.generate!(name: "Summary closed", is_public: true, tracker_ids: [1])
    issue(closed_project)
    closed_project.update_column(:status, Project::STATUS_CLOSED)
    archived_project = Project.generate!(name: "Summary archived", is_public: true, tracker_ids: [1])
    issue(archived_project)
    archived_project.update_column(:status, Project::STATUS_ARCHIVED)
    issue(@alpha)
    list
    assert_equal [3, 1], [tile_value("projects"), tile_value("open")]
    get "/projects", params: { set_filter: 1, f: %w[name status], op: { name: "~", status: "*" }, v: { name: ["Summary"] } }
    assert_equal [4, 2], [tile_value("projects"), tile_value("open")], "archived projects are never visible, closed ones count when shown"
  end

  test "a viewer sees the summary of the projects and issues they may see" do
    private_project = Project.generate!(name: "Summary private", is_public: false, tracker_ids: [1])
    3.times { issue(private_project) }
    issue(@alpha)
    issue(@alpha, is_private: true, author_id: 1)
    list
    assert_equal [4, 5], [tile_value("projects"), tile_value("open")]
    delete "/logout" rescue nil
    reset!
    log_user("jsmith", "jsmith")
    list
    assert_equal 3, tile_value("projects"), "the private project is not listed"
    assert_equal 1, tile_value("open"), "the private issue and the private project's issues are not counted"
  end

  test "hostile project names are escaped everywhere they appear" do
    hostile = Project.generate!(name: "Summary #{HOSTILE_NAME}", is_public: true, tracker_ids: [1])
    issue(hostile, subject: "Subject #{HOSTILE_NAME}", due_date: @today - 1)
    list(per_page: 100)
    refute_includes response.body, "<img src=x"
    refute_includes response.body, "<b>bold</b>"
    refute_includes response.body.sub(%r{<script type="application/json"[^>]*>.*?</script>}m, ""), "onerror=alert(1)>"
    assert_equal 1, css_select("script").count { |script| script.text.include?("alert(1)") }, "only inside the JSON block, as text"
    block = css_select("script[type='application/json']").first.text
    refute_includes block, "<"
    parsed = JSON.parse(block)
    assert_equal "Summary #{HOSTILE_NAME}", parsed["bars"][hostile.id.to_s]["name"]
    assert_equal "Summary #{HOSTILE_NAME}", parsed["sparks"]["projects"][hostile.id.to_s]["name"]
    assert_equal "Subject #{HOSTILE_NAME}", parsed["tiles"]["overdue"]["issues"].first["subject"]
    assert_select "[data-rubylode-bar='#{hostile.id}'] a.rubylode-projects-bar-name", text: "Summary #{HOSTILE_NAME}"
    assert_select "table[data-rubylode-trend-table] tr[data-project-id='#{hostile.id}'] th", text: "Summary #{HOSTILE_NAME}"
  end

  test "a quiet project card names the project and its link goes to the activity page" do
    issue(@alpha)
    list
    quiet = data["tiles"]["quiet"]
    assert_equal tile_value("quiet"), quiet["count"]
    assert_nil quiet["url"]
    assert quiet["projects"].all? { |project| project["url"].start_with?("/projects/") && project["url"].end_with?("/activity") }
  end

  test "the summary says nothing about the board" do
    seed_issues
    get "/projects", params: { display_type: "board" }
    assert_select "[data-rubylode-projects=summary]", 0
    assert_select "script[data-rubylode-overview-data]", 0
  end

  test "summary=0 hides the summary for that request and keeps the columns and their data" do
    seed_issues
    list(summary: "0")
    assert_select "[data-rubylode-projects=summary]", 0
    assert_select "th", text: "Open issues"
    assert_select "[data-rubylode-spark]"
    assert_nil data["tiles"]
    assert data["sparks"]
    list
    assert_select "[data-rubylode-projects=summary]", 1
  end

  test "the setting can turn the summary off, and it leaves the columns" do
    seed_issues
    configure(show_summary: "0")
    list
    assert_select "[data-rubylode-projects=summary]", 0
    assert_select "th", text: "Trend"
  end

  test "with another summary plugin installed the plugin adds no tiles and no columns, and the display still applies" do
    seed_issues
    original = Redmine::Plugin.method(:installed?)
    Redmine::Plugin.define_singleton_method(:installed?) { |id| id.to_sym == :redmine_projects_dashboard || original.call(id) }
    list
    assert_select "[data-rubylode-projects=summary]", 0
    assert_select "table.projects", 1
    headings = css_select("table.projects thead th").map { |heading| heading.text.strip }
    assert_equal %w[Name Identifier Description], headings
    get "/projects", params: { set_filter: 1, c: %w[name rubylode_open_issues] }
    assert_equal ["Name"], css_select("table.projects thead th").map { |heading| heading.text.strip }, "the columns are not offered either"
  ensure
    Redmine::Plugin.define_singleton_method(:installed?, original) if original
  end

  test "without the other plugin the columns are offered in the column chooser" do
    list
    assert_select "select#selected_c option[value=rubylode_trend]"
    assert_select "select#available_c option[value=rubylode_closed_week]"
  end

  test "the page links still page the list and the summary still describes all of it" do
    seed_issues
    with_settings per_page_options: "1,5" do
      list(per_page: 1)
      assert_select "table.projects tbody tr", 1
      assert_select "span.pagination span.items", text: /\(1-1\/3\)/
      assert_equal 3, tile_value("projects"), "the tile counts the whole list, not the page"
      assert_equal 4, tile_value("open")
      get "/projects", params: { set_filter: 1, f: ["name"], op: { name: "~" }, v: { name: ["Summary"] }, per_page: 1, page: 2 }
      assert_select "table.projects tbody tr", 1
      assert_equal 3, tile_value("projects")
    end
  end

  test "the number of queries added by the plugin is the same for 3 and 30 projects" do
    measured = [3, 30].map do |project_count|
      Issue.delete_all
      project_count.times do |index|
        project = Project.generate!(name: "Summary#{project_count}-#{index}", description: "A *made-up* project, see \"the wiki\":/help and #1", is_public: true, tracker_ids: [1])
        2.times { issue(project, due_date: @today - 1) }
      end
      with_settings per_page_options: "100" do
        configure(show_summary: "0", added_columns: [""])
        page = ->(extra) { get "/projects", params: { set_filter: 1, f: %w[name status], op: { name: "~", status: "=" }, v: { name: ["Summary#{project_count}-"], status: ["1"] }, per_page: 100 } }
        page.call(nil)
        assert_equal project_count, css_select("table.projects tbody tr").size
        redmine_only = count_queries { page.call(nil) }
        configure
        page.call(nil)
        with_plugin = count_queries { page.call(nil) }
        assert_equal project_count, css_select("table.projects tbody tr").size
        [redmine_only, with_plugin]
      end
    end
    redmine_growth = measured.last.first - measured.first.first
    assert_operator redmine_growth, :>=, 27, "Redmine's own list does about two queries per project (#{redmine_growth} more)"
    plugin_added = measured.map { |redmine_only, with_plugin| with_plugin - redmine_only }
    assert_equal plugin_added.first, plugin_added.last, "the summary and columns add #{plugin_added.first} queries for 3 projects and #{plugin_added.last} for 30"
    puts "\nquery counts (Redmine alone, with the plugin) for 3 and 30 projects: #{measured.inspect}"
  end
end
