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

# The checked columns on a project list: on a fresh install, on a saved query, and when the list picks its own columns.
class SavedQueryColumnsTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :enabled_modules, :trackers,
           :projects_trackers, :issue_statuses, :enumerations, :workflows, :issues, :custom_fields, :custom_values,
           :custom_fields_projects, :custom_fields_trackers, :queries

  FRESH_HEADINGS = ["Name", "Identifier", "Description", "Open issues", "Overdue", "% done", "Trend"].freeze
  SAVED_KEY = "add_columns_to_saved_queries".freeze

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

  def headings = css_select("table.projects thead th").map { |heading| heading.text.strip }

  def saved_query(column_names)
    ProjectQuery.create!(name: "Saved #{column_names.inspect}", visibility: Query::VISIBILITY_PUBLIC, user_id: 1,
                         column_names: column_names, options: { display_type: "list" })
  end

  def with_other_summary_plugin
    coexistence = RubylodeProjects::Coexistence
    coexistence.singleton_class.alias_method :original_other_summary_present?, :other_summary_present?
    coexistence.define_singleton_method(:other_summary_present?) { true }
    yield
  ensure
    coexistence.singleton_class.alias_method :other_summary_present?, :original_other_summary_present?
    coexistence.singleton_class.remove_method :original_other_summary_present?
  end

  test "a fresh install, with no stored settings at all, shows the four columns on an unsaved visit" do
    Setting.plugin_redmine_rubylode_projects = {}
    get "/projects"
    assert_response :success
    assert_equal FRESH_HEADINGS, headings
    assert_select "[data-rubylode-spark]"
  end

  test "the setting for saved queries is off on a fresh install" do
    refute RubylodeProjects::Settings.new({}).add_columns_to_saved_queries?
    assert_equal "0", RubylodeProjects::Settings::DEFAULTS.fetch(SAVED_KEY)
  end

  test "a saved query without the plugin's columns is left as saved while the setting is off" do
    configure
    get "/projects", params: { query_id: saved_query(%w[name identifier short_description]).id }
    assert_equal %w[Name Identifier Description], headings
  end

  test "a saved query without the plugin's columns gets the checked ones when the setting is on" do
    configure(SAVED_KEY => "1")
    query = saved_query(%w[name identifier status])
    get "/projects", params: { query_id: query.id }
    assert_equal (["Name", "Identifier", "Status"] + FRESH_HEADINGS.last(4)), headings
    assert_equal %w[name identifier status], query.reload.column_names.map(&:to_s), "the saved query itself is never written to"
  end

  test "a saved query that has the default columns, none stored, gets them too" do
    configure(SAVED_KEY => "1")
    get "/projects", params: { query_id: saved_query([]).id }
    assert_equal FRESH_HEADINGS, headings
  end

  test "the added columns follow the checked ones, not the whole set" do
    configure(SAVED_KEY => "1", "added_columns" => %w[trend])
    get "/projects", params: { query_id: saved_query(%w[name status]).id }
    assert_equal %w[Name Status Trend], headings
  end

  test "a saved query that holds some of the plugin's columns keeps exactly those" do
    configure(SAVED_KEY => "1")
    get "/projects", params: { query_id: saved_query(%w[name rubylode_trend]).id }
    assert_equal %w[Name Trend], headings
  end

  test "nothing is added to a saved query when no column is checked" do
    configure(SAVED_KEY => "1", "added_columns" => [""])
    get "/projects", params: { query_id: saved_query(%w[name status]).id }
    assert_equal %w[Name Status], headings
  end

  test "a visit that picks its columns with c keeps exactly those, with the setting on" do
    configure(SAVED_KEY => "1")
    get "/projects", params: { set_filter: 1, c: %w[name status] }
    assert_equal %w[Name Status], headings
  end

  test "the API request is not changed by the setting and does not fail" do
    configure(SAVED_KEY => "1")
    query = saved_query(%w[name identifier])
    get "/projects.json", params: { query_id: query.id }
    assert_response :success
    assert_equal %w[name identifier], query.reload.column_names.map(&:to_s)
    assert JSON.parse(response.body).key?("projects")
  end

  test "another plugin's summary leaves the list alone, with the setting on" do
    configure(SAVED_KEY => "1")
    with_other_summary_plugin do
      get "/projects", params: { query_id: saved_query(%w[name identifier]).id }
    end
    assert_equal %w[Name Identifier], headings
  end
end
