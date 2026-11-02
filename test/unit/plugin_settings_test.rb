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

class RubylodeProjectsPluginSettingsTest < ActiveSupport::TestCase
  def settings(values) = RubylodeProjects::PluginSettings.new(values)

  test "an empty hash gives the defaults" do
    defaults = settings({})
    assert_equal "list", defaults.default_display
    assert defaults.override_display?
    assert defaults.summary_shown?
    assert_equal %w[open_issues overdue percent_done trend], defaults.added_columns
    assert_equal 12, defaults.trend_weeks
    assert defaults.valid?
  end

  test "the three display choices are accepted, and leaving it to Redmine turns the override off" do
    %w[list board redmine].each { |choice| assert settings("default_display" => choice).valid?, choice }
    refute settings("default_display" => "redmine").override_display?
    assert settings("default_display" => "board").override_display?
  end

  test "an unknown display is an error and reads as the default" do
    problem = settings("default_display" => "grid")
    assert_equal 1, problem.errors.size
    assert_match(/List, Board or Leave to Redmine/, problem.errors.first)
    assert_equal "list", problem.default_display
  end

  test "the trend takes 4 to 26 whole weeks" do
    [4, 12, "26", " 8"].each { |weeks| assert settings("trend_weeks" => weeks).valid?, weeks.inspect }
    [3, 27, 0, -5, "", "abc", "12.5", nil, "1e1"].each do |weeks|
      refute settings("trend_weeks" => weeks).valid?, weeks.inspect
    end
    assert_match(/from 4 to 26/, settings("trend_weeks" => 40).errors.first)
    assert_equal 26, settings("trend_weeks" => "26").trend_weeks
    assert_equal 12, settings("trend_weeks" => "40").trend_weeks, "an unusable value reads as the default"
  end

  test "added columns must be known ones, and keep the columns' own order" do
    chosen = settings("added_columns" => ["", "trend", "open_issues"])
    assert chosen.valid?
    assert_equal %w[open_issues trend], chosen.added_columns
    bad = settings("added_columns" => %w[open_issues secret_column])
    refute bad.valid?
    assert_match(/secret_column/, bad.errors.first)
  end

  test "no ticked column box means no added columns, not the defaults" do
    assert_equal [], settings("added_columns" => [""]).added_columns
  end

  test "the summary checkbox sends 0 when it is off" do
    refute settings("show_summary" => "0").summary_shown?
    assert settings("show_summary" => "1").summary_shown?
  end

  test "settings are read from the saved plugin setting when nothing is passed in" do
    with_plugin_settings("default_display" => "board", "trend_weeks" => "6") do
      saved = RubylodeProjects::PluginSettings.new
      assert_equal "board", saved.default_display
      assert_equal 6, saved.trend_weeks
    end
  end

  test "the projects table settings default to changing nothing" do
    defaults = settings({})
    refute defaults.welcome_table_shown?
    assert_equal "right", defaults.welcome_table_column
    assert_equal 20, defaults.table_limit
    assert defaults.table_description_shown?
    assert defaults.table_done_bar_shown?
    assert defaults.valid?
  end

  test "settings saved by an older version read as the table defaults" do
    older = settings("default_display" => "board", "trend_weeks" => "8")
    refute older.welcome_table_shown?
    assert_equal 20, older.table_limit
    assert older.table_description_shown?
  end

  test "the table switches read their 0 and 1" do
    chosen = settings("welcome_projects_table" => "1", "projects_table_show_description" => "0", "projects_table_show_done_bar" => "0")
    assert chosen.welcome_table_shown?
    refute chosen.table_description_shown?
    refute chosen.table_done_bar_shown?
  end

  test "the welcome column is left or right" do
    assert settings("welcome_projects_table_column" => "left").valid?
    assert_equal "left", settings("welcome_projects_table_column" => "left").welcome_table_column
    refute settings("welcome_projects_table_column" => "middle").valid?
    assert_equal "right", settings("welcome_projects_table_column" => "middle").welcome_table_column
  end

  test "the table rows are 1 to 100, whole numbers, and read clamped" do
    [1, 20, "100", " 5"].each { |limit| assert settings("projects_table_limit" => limit).valid?, limit.inspect }
    [0, 101, -1, "", "abc", "2.5", nil].each { |limit| refute settings("projects_table_limit" => limit).valid?, limit.inspect }
    assert_match(/from 1 to 100/, settings("projects_table_limit" => 500).errors.first)
    assert_equal 100, settings("projects_table_limit" => "500").table_limit
    assert_equal 1, settings("projects_table_limit" => "0").table_limit
    assert_equal 20, settings("projects_table_limit" => "abc").table_limit
  end

  def with_plugin_settings(values)
    previous = Setting.plugin_redmine_rubylode_projects
    Setting.plugin_redmine_rubylode_projects = values
    yield
  ensure
    Setting.plugin_redmine_rubylode_projects = previous
  end
end
