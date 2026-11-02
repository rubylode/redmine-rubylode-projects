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

# Administration, Plugins, Configure: the form, and the check before anything is saved.
class PluginSettingsPageTest < Redmine::IntegrationTest
  fixtures :users, :email_addresses, :roles

  PATH = "/settings/plugin/redmine_rubylode_projects".freeze

  def setup
    @previous = Setting.plugin_redmine_rubylode_projects
    log_user("admin", "admin")
  end

  def teardown
    Setting.plugin_redmine_rubylode_projects = @previous
  end

  def valid_settings(**changes)
    { "default_display" => "list", "show_summary" => "1", "added_columns" => ["", "open_issues", "trend"], "trend_weeks" => "12" }.merge(changes.stringify_keys)
  end

  test "the plugin is configurable and the form shows each setting with its default" do
    get PATH
    assert_response :success
    assert_select "select#settings_default_display option[selected][value=list]"
    assert_select "select#settings_default_display option", 3
    assert_select "input#settings_show_summary[checked]"
    assert_select "input[name='settings[added_columns][]'][type=checkbox]", 6
    assert_select "input#settings_added_columns_open_issues[checked]"
    assert_select "input#settings_added_columns_closed_week:not([checked])"
    assert_select "input#settings_trend_weeks[value='12'][min='4'][max='26']"
    assert_select "input#settings_welcome_projects_table:not([checked])"
    assert_select "select#settings_welcome_projects_table_column option[selected][value=right]"
    assert_select "input#settings_projects_table_limit[value='20'][min='1'][max='100']"
    assert_select "input#settings_projects_table_show_description[checked]"
    assert_select "input#settings_projects_table_show_done_bar[checked]"
  end

  test "valid settings are saved" do
    post PATH, params: { settings: valid_settings(default_display: "board", trend_weeks: "20", show_summary: "0") }
    assert_redirected_to PATH
    saved = RubylodeProjects::PluginSettings.new
    assert_equal "board", saved.default_display
    assert_equal 20, saved.trend_weeks
    refute saved.summary_shown?
    assert_equal %w[open_issues trend], saved.added_columns
  end

  test "an out of range trend is refused: nothing is saved and the form returns with the typed values and the problem" do
    Setting.plugin_redmine_rubylode_projects = valid_settings(trend_weeks: "9")
    post PATH, params: { settings: valid_settings(trend_weeks: "40", default_display: "board") }
    assert_response :unprocessable_entity
    assert_select "#errorExplanation, .flash.error", text: /from 4 to 26/
    assert_select "input#settings_trend_weeks[value='40']"
    assert_select "select#settings_default_display option[selected][value=board]"
    assert_equal "9", Setting.plugin_redmine_rubylode_projects["trend_weeks"]
  end

  test "the table settings are saved, and a bad column or limit is refused" do
    post PATH, params: { settings: valid_settings(welcome_projects_table: "1", welcome_projects_table_column: "left", projects_table_limit: "35",
                                                  projects_table_show_description: "0", projects_table_show_done_bar: "0") }
    assert_redirected_to PATH
    saved = RubylodeProjects::PluginSettings.new
    assert saved.welcome_table_shown?
    assert_equal "left", saved.welcome_table_column
    assert_equal 35, saved.table_limit
    refute saved.table_description_shown?
    refute saved.table_done_bar_shown?
    post PATH, params: { settings: valid_settings(welcome_projects_table_column: "top") }
    assert_response :unprocessable_entity
    post PATH, params: { settings: valid_settings(projects_table_limit: "101") }
    assert_response :unprocessable_entity
    assert_select ".flash.error", text: /from 1 to 100/
    assert_select "input#settings_projects_table_limit[value='101']"
  end

  test "an unknown display or column is refused" do
    post PATH, params: { settings: valid_settings(default_display: "grid") }
    assert_response :unprocessable_entity
    post PATH, params: { settings: valid_settings(added_columns: %w[open_issues nope]) }
    assert_response :unprocessable_entity
    assert_select ".flash.error", text: /nope/
  end
end
