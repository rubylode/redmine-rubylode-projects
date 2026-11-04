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

# Which display /projects opens in: the plugin's choice for a plain visit, never over an explicit request or a saved query.
class DefaultDisplayTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :enabled_modules, :trackers,
           :projects_trackers, :issue_statuses, :enumerations, :queries

  def setup
    @previous_plugin_settings = Setting.plugin_redmine_rubylode_projects
    log_user("admin", "admin")
  end

  def teardown
    Setting.plugin_redmine_rubylode_projects = @previous_plugin_settings
  end

  def configure(**values)
    Setting.plugin_redmine_rubylode_projects = RubylodeProjects::Settings::DEFAULTS.merge(values.stringify_keys)
  end

  def shows_list? = css_select("table.projects").any?

  def shows_board? = css_select("#projects-index").any?

  test "a plain visit shows the list by default, whatever Redmine's own setting is" do
    with_settings project_list_display_type: "board" do
      get "/projects"
      assert_response :success
      assert shows_list?
      refute shows_board?
    end
  end

  test "an explicit display_type=board always gives the board" do
    get "/projects", params: { display_type: "board" }
    assert shows_board?
    refute shows_list?
  end

  test "an explicit display_type=list gives the list when the plugin is set to the board" do
    configure(default_display: "board")
    get "/projects", params: { display_type: "list" }
    assert shows_list?
  end

  test "set to the board, a plain visit shows the board" do
    configure(default_display: "board")
    get "/projects"
    assert shows_board?
  end

  test "leave to Redmine follows Redmine's own setting, board by default and list when it says so" do
    configure(default_display: "redmine")
    get "/projects"
    assert shows_board?, "Redmine's own default is the board"
    with_settings project_list_display_type: "list" do
      get "/projects"
      assert shows_list?
    end
  end

  test "the radio buttons of the options form still switch the display" do
    get "/projects", params: { set_filter: 1, display_type: "board", f: ["status"], op: { status: "=" }, v: { status: ["1"] } }
    assert shows_board?
    get "/projects", params: { set_filter: 1, display_type: "list", f: ["status"], op: { status: "=" }, v: { status: ["1"] } }
    assert shows_list?
  end

  test "a saved query is left as it was saved: a board query stays a board while the plugin says list" do
    query = ProjectQuery.create!(name: "Saved board", visibility: Query::VISIBILITY_PUBLIC, user_id: 1, options: { display_type: "board" })
    configure(default_display: "list")
    get "/projects", params: { query_id: query.id }
    assert_response :success
    assert shows_board?
    refute shows_list?
  end

  test "a saved list query stays a list while the plugin says board, and keeps its own columns" do
    query = ProjectQuery.create!(name: "Saved list", visibility: Query::VISIBILITY_PUBLIC, user_id: 1,
                                 column_names: %w[name status], options: { display_type: "list" })
    configure(default_display: "board", added_columns: %w[open_issues trend])
    get "/projects", params: { query_id: query.id }
    assert shows_list?
    assert_equal %w[Name Status], css_select("table.projects thead th").map { |heading| heading.text.strip }
  end

  test "the default saved query set in Redmine's settings is a saved query too" do
    query = ProjectQuery.create!(name: "Default board", visibility: Query::VISIBILITY_PUBLIC, user_id: 1, options: { display_type: "board" })
    with_settings default_project_query: query.id.to_s do
      configure(default_display: "list")
      get "/projects"
      assert shows_board?
    end
  end

  test "a choice made in the session is kept for the plain visits after it" do
    configure(default_display: "list")
    get "/projects", params: { display_type: "board" }
    assert shows_board?
    get "/projects"
    assert shows_board?, "the plain link after choosing the board keeps the board"
    get "/projects", params: { display_type: "list" }
    get "/projects"
    assert shows_list?
  end

  test "another session starts from the setting again" do
    get "/projects", params: { display_type: "board" }
    reset!
    log_user("admin", "admin")
    get "/projects"
    assert shows_list?
  end

  test "a choice by the API or a CSV export is not remembered, and the format does not change" do
    get "/projects.csv", params: { display_type: "board" }
    assert_response :success
    get "/projects.json", params: { display_type: "board" }
    assert_response :success
    get "/projects"
    assert shows_list?
  end
end
