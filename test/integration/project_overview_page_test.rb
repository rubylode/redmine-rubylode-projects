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

# The project Overview page (projects#show) with the cards above Redmine's own blocks.
class ProjectOverviewPageTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :enabled_modules, :trackers,
           :projects_trackers, :issue_statuses, :enumerations, :workflows, :issues, :custom_fields, :custom_values,
           :custom_fields_projects, :custom_fields_trackers

  BUG = 1
  FEATURE = 2
  NEW_STATUS = 1
  ASSIGNED_STATUS = 2
  CLOSED_STATUS = 5
  NORMAL_PRIORITY = 5
  HIGH_PRIORITY = 6

  # A public project with one subproject. Six issues: four open, one of them private to the administrator, and two closed.
  def setup
    @project = Project.generate!(name: "Overview parent", is_public: true, tracker_ids: [BUG, FEATURE])
    @subproject = Project.generate_with_parent!(@project, name: "Overview child", is_public: true, tracker_ids: [BUG, FEATURE])
    @new_bug = issue("A new bug at normal priority", tracker_id: BUG)
    @bug_in_progress = issue("A bug someone is working on", tracker_id: BUG, status_id: ASSIGNED_STATUS)
    @urgent_feature = issue("A feature at high priority", tracker_id: FEATURE, priority_id: HIGH_PRIORITY)
    @closed_feature = issue("A closed feature at high priority", tracker_id: FEATURE, status_id: CLOSED_STATUS, priority_id: HIGH_PRIORITY)
    @closed_child_bug = issue("A closed bug in the subproject", project: @subproject, tracker_id: BUG, status_id: CLOSED_STATUS)
    @private_bug = issue("A private bug", tracker_id: BUG, is_private: true, author_id: 1, assigned_to_id: nil)
  end

  def issue(subject, **attributes)
    Issue.generate!({ project: @project, subject: subject, author_id: 2, priority_id: NORMAL_PRIORITY }.merge(attributes))
  end

  def tile_value(name)
    css_select(%([data-rubylode-tile="#{name}"] .rubylode-overview-tile-value)).first&.text&.strip
  end

  def week_counts(week_start)
    %w[opened closed].map { |series| css_select(".rubylode-overview-chart tr[data-week-start='#{week_start}'] td[data-series='#{series}']").first&.text }
  end

  test "the tiles count open, closed and all issues, subprojects included, and the done share" do
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    assert_response :success
    assert_equal "4", tile_value("open")
    assert_equal "2", tile_value("closed")
    assert_equal "6", tile_value("all")
    assert_equal "33%", tile_value("done")
    assert_select %([data-rubylode-tile="open"] .rubylode-overview-tile-note), text: "Bug 3 · Feature request 1"
    assert_select %([data-rubylode-tile="all"] .rubylode-overview-tile-note), text: /1 subproject/
    assert_select %([data-rubylode-tile="done"] .rubylode-overview-progress[style*="33%"])
  end

  test "someone who may not see the private issue does not get it counted" do
    get "/projects/#{@project.identifier}"
    assert_response :success
    assert_equal "3", tile_value("open")
    assert_equal "5", tile_value("all")
    assert_equal "40%", tile_value("done")
    assert_select "[data-issue-id='#{@private_bug.id}']", 0
  end

  test "the by-tracker panel shows each tracker and links to the issue list, the summary and the Gantt chart" do
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    assert_select "[data-rubylode-tracker='#{BUG}']", text: /3 open · 1 closed/ do
      assert_select ".rubylode-overview-tracker-note", text: /25% done of 4/
    end
    assert_select "[data-rubylode-tracker='#{FEATURE}']", text: /1 open · 1 closed/
    assert_select ".rubylode-overview-trackers a[href=?]", "/projects/#{@project.identifier}/issues/report"
    assert_select ".rubylode-overview-trackers a[href=?]", "/projects/#{@project.identifier}/issues/gantt"
    assert_select ".rubylode-overview-trackers a[href^=?]", "/projects/#{@project.identifier}/issues?set_filter=1"
  end

  test "the in-progress-and-urgent list holds open issues that have started or sit above the default priority" do
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    assert_select ".rubylode-overview-urgent [data-issue-id]", 2
    assert_select ".rubylode-overview-urgent [data-issue-id='#{@urgent_feature.id}']"
    assert_select ".rubylode-overview-urgent [data-issue-id='#{@bug_in_progress.id}']"
    # The higher priority comes first.
    assert_equal [@urgent_feature.id, @bug_in_progress.id].map(&:to_s),
                 css_select(".rubylode-overview-urgent [data-issue-id]").map { |row| row["data-issue-id"] }
  end

  test "the weekly chart counts opened and closed issues in the week they happened" do
    two_weeks_ago = 14.days.ago.change(hour: 12)
    @new_bug.update_columns(created_on: two_weeks_ago)
    @closed_feature.update_columns(created_on: two_weeks_ago, closed_on: 7.days.ago.change(hour: 12))
    @closed_child_bug.update_columns(created_on: 7.days.ago.change(hour: 12), closed_on: 7.days.ago.change(hour: 12))
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    assert_select ".rubylode-overview-chart svg rect.rubylode-overview-bar-opened", 12
    assert_select ".rubylode-overview-chart svg rect.rubylode-overview-bar-closed", 12
    two_weeks_ago_start = two_weeks_ago.to_date.beginning_of_week(:monday)
    one_week_ago_start = 7.days.ago.to_date.beginning_of_week(:monday)
    assert_equal %w[2 0], week_counts(two_weeks_ago_start)
    assert_equal %w[1 2], week_counts(one_week_ago_start)
  end

  test "members are grouped by role and subprojects show as chips" do
    User.add_to_project(User.find(2), @project, Role.find(1))
    User.add_to_project(User.find(3), @project, Role.find(2))
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    assert_select ".rubylode-overview-members [data-rubylode-role='1']", text: /John Smith/
    assert_select ".rubylode-overview-members [data-rubylode-role='2']", text: /Dave Lopper/
    assert_select ".rubylode-overview-subprojects a.rubylode-overview-chip[href=?]", "/projects/#{@subproject.identifier}", text: "Overview child"
  end

  test "the cards replace Redmine's blocks, so nothing shows twice, and link to the classic overview" do
    @project.update!(description: "The parent of the overview tests.")
    User.add_to_project(User.find(2), @project, Role.find(1))
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    assert_select "h2", text: "Overview"
    assert_select ".rubylode-projects-redmine-page.rubylode-projects-cards-shown" do
      assert_select ".rubylode-overview-tiles"
      # Redmine's blocks are passed through untouched; the stylesheet hides them under the cards-shown class
      # (test/unit/replaced_blocks_stylesheet_test.rb checks those rules).
      %w[div.issues.box div.spent_time.box div.members.box div.projects.box].each { |block| assert_select ".splitcontent #{block}", 1 }
      assert_select "div.splitcontentleft > div.wiki", 1
    end
    assert_select "a.rubylode-projects-view-switch[href=?]", "/projects/#{@project.identifier}?view=classic"
    body = response.body
    assert body.index("<h2>Overview</h2>") < body.index("rubylode-overview-tiles"), "the cards come after the page heading"
  end

  test "the classic overview is Redmine's own page with nothing hidden, and a link back" do
    @project.update!(description: "The parent of the overview tests.")
    User.add_to_project(User.find(2), @project, Role.find(1))
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}", params: { view: "classic" }
    assert_response :success
    assert_select ".rubylode-projects-redmine-page"
    assert_select ".rubylode-projects-cards-shown", 0
    assert_select ".rubylode-overview", 0
    assert_select ".rubylode-projects-subtitle", 0
    assert_select "div.issues.box"
    assert_select "div.members.box"
    assert_select "div.projects.box"
    assert_select "div.splitcontentleft > div.wiki", text: /The parent of the overview tests/
    assert_select "a.rubylode-projects-view-switch[href=?]", "/projects/#{@project.identifier}"
  end

  # Mutation-prone content: a page that was parsed and written out again could change what these mean.
  HOSTILE_DESCRIPTION = <<~TEXT
    <script>alert(1)</script>
    <noscript><p title="</noscript><img src=x onerror=alert(2)>"></noscript>
    <svg><style><img src=x onerror=alert(3)></style></svg>
    <math><mtext><table><mglyph><style><img src=x onerror=alert(4)></style></mglyph></table></mtext></math>
  TEXT

  def redmine_part(body, wrapper_class)
    start = body.index(%(<div class="#{wrapper_class}">)) + %(<div class="#{wrapper_class}">).length
    heading_end = body.index("</h2>", start) + "</h2>".length
    blocks_start = body.index(%(<div class="splitcontent">), heading_end)
    blocks_end = body.index(%(<div id="footer">), blocks_start)
    [body[start...heading_end], body[blocks_start...blocks_end]]
  end

  test "Redmine's own rendering goes through byte for byte, even with a hostile description" do
    @project.update!(description: HOSTILE_DESCRIPTION)
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}", params: { view: "classic" }
    classic = redmine_part(response.body, "rubylode-projects-redmine-page")
    get "/projects/#{@project.identifier}"
    with_cards = redmine_part(response.body, "rubylode-projects-redmine-page rubylode-projects-cards-shown")
    assert_includes with_cards.last, "&lt;script&gt;alert(1)&lt;/script&gt;", "the description is in the compared part"
    assert_includes with_cards.last, %(<p title="</noscript>), "and so is Redmine's rendering of the noscript sample"
    assert_equal classic, with_cards
  end

  test "the description is a one-line subtitle under the title, as plain text with the whole of it on hover" do
    @project.update!(description: "A *bold* plan <script>alert(1)</script>\n\nwith a second paragraph")
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    assert_select "p.rubylode-projects-subtitle", 1 do |subtitles|
      assert_equal subtitles.first["title"], subtitles.first.text.strip
      assert_match(/\AA bold plan .*with a second paragraph\z/, subtitles.first["title"])
    end
    assert_select "p.rubylode-projects-subtitle strong", 0
    assert_select "p.rubylode-projects-subtitle script", 0
    body = response.body
    assert body.index("<h2>Overview</h2>") < body.index("rubylode-projects-subtitle")
    assert body.index("rubylode-projects-subtitle") < body.index("rubylode-overview-tiles")
  end

  test "no description, no subtitle" do
    @project.update!(description: "")
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    assert_select ".rubylode-projects-subtitle", 0
  end

  test "a project with time tracking keeps its spent and estimated time in a compact card" do
    @new_bug.update!(estimated_hours: 5)
    TimeEntry.generate!(project: @project, issue: @new_bug, hours: 2.5, user: User.find(1))
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    assert_select ".rubylode-overview-time" do
      assert_select "[data-rubylode-time='spent']", text: /2:30/
      assert_select "[data-rubylode-time='estimated']", text: /5:00/
      assert_select "a[href=?]", "/projects/#{@project.identifier}/time_entries"
    end
  end

  test "a project without time tracking has no time card" do
    @project.enabled_module_names = @project.enabled_module_names - ["time_tracking"]
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    assert_select ".rubylode-overview-time", 0
  end

  test "a project without issue tracking shows no issue cards, and keeps members and subprojects" do
    @project.enabled_module_names = @project.enabled_module_names - ["issue_tracking"]
    log_user("admin", "admin")
    get "/projects/#{@project.identifier}"
    assert_response :success
    assert_select ".rubylode-overview"
    assert_select ".rubylode-overview-tiles", 0
    assert_select ".rubylode-overview-chart", 0
    assert_select ".rubylode-overview-trackers", 0
    assert_select ".rubylode-overview-urgent", 0
    assert_select ".rubylode-overview-subprojects"
  end

  test "someone who may not view issues sees no issue cards" do
    Role.anonymous.remove_permission!(:view_issues)
    get "/projects/#{@project.identifier}"
    assert_response :success
    assert_select ".rubylode-overview-tiles", 0
    assert_select ".rubylode-overview-urgent", 0
  end

  test "the Overview page loads the plugin stylesheet" do
    get "/projects/#{@project.identifier}"
    assert_select "link[href*=?]", "plugin_assets/redmine_rubylode_projects/projects"
  end
end
