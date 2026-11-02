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

# The data block, markup and links behind the Overview's tooltips and popovers. The script itself is checked in a browser.
class OverviewInteractivityTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :enabled_modules, :trackers,
           :projects_trackers, :issue_statuses, :enumerations, :workflows, :issues, :custom_fields, :custom_values,
           :custom_fields_projects, :custom_fields_trackers

  BUG = 1
  FEATURE = 2
  ASSIGNED_STATUS = 2
  CLOSED_STATUS = 5
  HOSTILE_SUBJECT = %(</script><img src=x onerror=alert(1)> <script>alert("x")</script> & "quoted" 'single')

  def setup
    @project = Project.generate!(name: "Interaction parent", is_public: true, tracker_ids: [BUG, FEATURE])
    @subproject = Project.generate_with_parent!(@project, name: "Interaction child", is_public: true, tracker_ids: [BUG, FEATURE])
    @last_week = 7.days.ago.change(hour: 12)
  end

  # created_on is set by Rails on create, so a past date goes in afterwards.
  def issue(subject, **attributes)
    created_on = attributes.delete(:created_on)
    Issue.generate!({ project: @project, subject: subject, author_id: 2, priority_id: 5 }.merge(attributes)).tap do |created|
      created.update_columns(created_on: created_on) if created_on
    end
  end

  def overview_data
    block = css_select("script[type='application/json'][data-rubylode-overview-data]")
    assert_equal 1, block.size
    JSON.parse(block.first.text)
  end

  def week_data(date)
    overview_data["weeks"].find { |week| week["start"] == date.to_date.beginning_of_week(:monday).iso8601 }
  end

  def query_of(url) = Rack::Utils.parse_nested_query(url.split("?", 2).last)

  def count_queries
    count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      count += 1 unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE)/i)
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  test "the week data holds the dates, counts, net change, running open total, top trackers and both issue lists" do
    2.times { issue("Bug opened last week", tracker_id: BUG, created_on: @last_week) }
    issue("Feature opened last week", tracker_id: FEATURE, created_on: @last_week)
    closed = issue("Closed last week", tracker_id: BUG, status_id: CLOSED_STATUS, created_on: 30.days.ago)
    closed.update_columns(closed_on: @last_week)
    issue("Open and old", tracker_id: BUG, created_on: 40.days.ago)
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    assert_response :success

    week = week_data(@last_week)
    assert_equal 3, week["opened"]
    assert_equal 1, week["closed"]
    assert_equal 2, week["net"]
    assert_equal [{ "name" => "Bug", "count" => 2 }, { "name" => "Feature request", "count" => 1 }], week["topTrackers"]
    # Four issues are open now (three opened last week, one older). The closed one was open until last week, so last week
    # ended with four open, and the week before with the one old issue plus the one closed later: two.
    assert_equal 4, overview_data["tiles"]["open"]["count"]
    assert_equal 4, overview_data["weeks"].last["openTotal"]
    assert_equal 4, week["openTotal"]
    assert_equal 2, overview_data["weeks"][overview_data["weeks"].index(week) - 1]["openTotal"]

    first_day = Date.iso8601(week["start"])
    opened_query = query_of(week["openedUrl"])
    assert_equal "1", opened_query["set_filter"]
    assert_equal %w[status_id created_on subproject_id], opened_query["f"]
    assert_equal [first_day.iso8601, (first_day + 6).iso8601], opened_query.dig("v", "created_on")
    closed_query = query_of(week["closedUrl"])
    assert_equal [first_day.iso8601, (first_day + 6).iso8601], closed_query.dig("v", "closed_on")
    assert_equal "*", closed_query.dig("op", "subproject_id")
    assert week["openedUrl"].start_with?("/projects/#{@project.identifier}/issues?")
  end

  test "the running open total works backwards from the open count now" do
    issue("Still open", tracker_id: BUG, created_on: 20.days.ago)
    closed = issue("Closed two weeks ago", tracker_id: BUG, status_id: CLOSED_STATUS, created_on: 20.days.ago)
    closed.update_columns(closed_on: 14.days.ago)
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    weeks = overview_data["weeks"]
    assert_equal 1, weeks.last["openTotal"]
    closing_week = week_data(14.days.ago)
    previous_week = weeks[weeks.index(closing_week) - 1]
    assert_equal 1, closing_week["openTotal"]
    assert_equal 2, previous_week["openTotal"], "before the close, both issues were open"
  end

  test "subprojects are included in the links the way the chart counts them, or excluded when the setting is off" do
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    assert_equal "*", query_of(overview_data["weeks"].first["openedUrl"]).dig("op", "subproject_id")
    assert_equal "*", query_of(overview_data["tiles"]["open"]["url"]).dig("op", "subproject_id")
    with_settings display_subprojects_issues: "0" do
      get "/projects/#{@project.identifier}"
      assert_equal "!*", query_of(overview_data["weeks"].first["openedUrl"]).dig("op", "subproject_id")
    end
  end

  test "a project without subprojects leaves the subproject filter out" do
    get "/projects/#{@subproject.identifier}"
    assert_response :success
    refute_includes overview_data["weeks"].first["openedUrl"], "subproject_id"
  end

  test "each tile carries its count, its list, at most five issues with their status, and a see-all label" do
    7.times { |index| issue("Open issue #{index}", tracker_id: BUG, status_id: ASSIGNED_STATUS) }
    issue("Closed one", tracker_id: BUG, status_id: CLOSED_STATUS)
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    tiles = overview_data["tiles"]
    assert_equal 7, tiles["open"]["count"]
    assert_equal 5, tiles["open"]["issues"].size
    assert_equal "Assigned", tiles["open"]["issues"].first["status"]
    assert_equal "See all 7", tiles["open"]["seeAll"]
    assert_equal "/issues/#{tiles['open']['issues'].first['id']}", tiles["open"]["issues"].first["url"]
    assert_equal ["Closed one"], tiles["closed"]["issues"].map { |row| row["subject"] }
    assert_equal 8, tiles["all"]["count"]
    assert_equal 5, tiles["all"]["issues"].size
    assert_equal tiles["closed"]["issues"], tiles["done"]["issues"]
    assert_equal "o", query_of(tiles["open"]["url"]).dig("op", "status_id")
    assert_equal "c", query_of(tiles["closed"]["url"]).dig("op", "status_id")
  end

  test "tracker rows carry open, closed and overdue counts, the percentage done and a link to the tracker's list" do
    issue("Late bug", tracker_id: BUG, due_date: 3.days.ago.to_date)
    issue("Not late bug", tracker_id: BUG, due_date: 3.days.from_now.to_date)
    issue("Late but closed", tracker_id: BUG, status_id: CLOSED_STATUS, due_date: 3.days.ago.to_date)
    issue("A feature", tracker_id: FEATURE)
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    bug = overview_data["trackers"][BUG.to_s]
    assert_equal({ "name" => "Bug", "open" => 2, "closed" => 1, "overdue" => 1, "percentage" => 33 }, bug.except("url"))
    assert_equal [BUG.to_s], query_of(bug["url"]).dig("v", "tracker_id")
    assert_equal 0, overview_data["trackers"][FEATURE.to_s]["overdue"]
    assert_select "[data-rubylode-tracker='#{BUG}'] a.rubylode-overview-tracker-name[href=?]", bug["url"].gsub("&", "&amp;").then { |_| bug["url"] }
  end

  test "the number of queries does not grow with the number of issues" do
    log_user("admin", "admin")
    # Every list the cards fill is non-empty from the start: an empty list skips its follow-up query, which is not growth.
    issue("Early open", tracker_id: BUG, created_on: 1.day.ago, due_date: 2.days.ago.to_date, status_id: ASSIGNED_STATUS)
    issue("Early closed", tracker_id: FEATURE, created_on: 2.days.ago, status_id: CLOSED_STATUS).update_columns(closed_on: 1.day.ago)
    get "/projects/#{@project.identifier}"
    few = count_queries { get "/projects/#{@project.identifier}" }
    40.times do |index|
      issue("Later #{index}", tracker_id: [BUG, FEATURE][index % 2], created_on: (index * 2).days.ago, status_id: [1, 2, CLOSED_STATUS][index % 3],
                              due_date: 2.days.ago.to_date)
    end
    get "/projects/#{@project.identifier}"
    many = count_queries { get "/projects/#{@project.identifier}" }
    assert_response :success
    assert_equal 42, overview_data["tiles"]["all"]["count"]
    assert_equal few, many, "the page makes the same queries for 2 issues as for 42"
  end

  test "the chart is a group of focusable week links, each labelled with its figures, and the legend has toggle buttons" do
    issue("Opened last week", tracker_id: BUG, created_on: @last_week)
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    assert_select "svg.rubylode-overview-chart-graphic[role=group][aria-label]"
    assert_select "svg a.rubylode-overview-week[href][aria-label]", 12
    week = week_data(@last_week)
    label = css_select("svg a.rubylode-overview-week")[overview_data["weeks"].index(week)]["aria-label"]
    assert_includes label, "1 opened, 0 closed, net +1, 1 open at the end"
    assert_includes label, week["label"]
    assert_select "svg a.rubylode-overview-week[href=?]", week["openedUrl"]
    assert_select ".rubylode-overview-legend button[aria-pressed=true][data-series]", 2
    assert_select ".rubylode-overview [onclick], .rubylode-overview [onmouseover], .rubylode-overview [onfocus], .rubylode-overview [onmouseenter]", 0
  end

  test "the hidden table gives every week's figures and both issue lists, so no mouse is needed" do
    issue("Opened last week", tracker_id: BUG, created_on: @last_week)
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    week = week_data(@last_week)
    row = "table.rubylode-overview-visually-hidden tr[data-week-start='#{week['start']}']"
    assert_select "#{row} td[data-series=opened]", text: "1"
    assert_select "#{row} td[data-series=closed]", text: "0"
    assert_select "#{row} td[data-series=net]", text: "1"
    assert_select "#{row} td[data-series=open-total]", text: week["openTotal"].to_s
    assert_select "#{row} a[href=?]", week["openedUrl"]
    assert_select "#{row} a[href=?]", week["closedUrl"]
  end

  test "a hostile subject stays text: escaped in the data block, never markup" do
    hostile = issue(HOSTILE_SUBJECT, tracker_id: BUG, status_id: ASSIGNED_STATUS)
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    assert_response :success
    body = response.body
    block = body[/<script type="application\/json" data-rubylode-overview-data>(.*?)<\/script>/m, 1]
    assert block, "the data block is closed by its own tag"
    refute_includes block, "<", "no angle bracket reaches the page raw"
    refute_includes block, "&"
    assert_equal HOSTILE_SUBJECT, overview_data["tiles"]["open"]["issues"].find { |row| row["id"] == hostile.id }["subject"]
    assert_select "img[src=x]", 0
    assert_select "script", text: /alert\("x"\)/, count: 0
    assert_equal 1, css_select("script[data-rubylode-overview-data]").size
  end

  test "someone who may not see a private issue does not get it in a tile card" do
    private_issue = issue("Secret plan", tracker_id: BUG, is_private: true, author_id: 1, assigned_to_id: nil)
    issue("Public plan", tracker_id: BUG)
    get "/projects/#{@project.identifier}"
    refute_includes response.body, "Secret plan"
    ids = overview_data["tiles"]["all"]["issues"].map { |row| row["id"] }
    refute_includes ids, private_issue.id
    assert_equal 1, overview_data["tiles"]["all"]["count"]
  end

  test "a project without issue cards has no data block and no chart" do
    @project.enabled_module_names = @project.enabled_module_names - ["issue_tracking"]
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    assert_select "script[data-rubylode-overview-data]", 0
  end

  test "the Overview and the list of projects load the script, deferred" do
    get "/projects/#{@project.identifier}"
    assert_select "script[src*=?][defer]", "plugin_assets/redmine_rubylode_projects/overview"
    get "/projects"
    assert_select "script[src*=?][defer]", "plugin_assets/redmine_rubylode_projects/overview"
  end

  test "the colour and size choices for tooltips are custom properties in the stylesheet" do
    css = File.read(File.expand_path("../../assets/stylesheets/projects.css", __dir__))
    %w[background text-color border-color shadow].each { |name| assert_includes css, "--rubylode-projects-tooltip-#{name}:" }
    %w[highlight-color dim-opacity].each { |name| assert_includes css, "--rubylode-projects-#{name}:" }
    assert_includes css, "prefers-reduced-motion"
  end
end
