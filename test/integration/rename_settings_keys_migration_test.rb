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
require_relative "../../db/migrate/001_rename_settings_keys_to_the_rubylode_standard"

# The saved plugin setting is moved to the 2.0.0 keys by a migration, and moved back by its reverse.
class RenameSettingsKeysMigrationTest < ActiveSupport::TestCase
  SETTING_NAME = "plugin_redmine_rubylode_projects".freeze

  def setup
    @previous = Setting.find_by(name: SETTING_NAME)&.value
    Setting.where(name: SETTING_NAME).delete_all
    Setting.clear_cache
  end

  def teardown
    Setting.where(name: SETTING_NAME).delete_all
    Setting.clear_cache
    Setting[SETTING_NAME] = @previous if @previous
  end

  def saved = Setting.find_by(name: SETTING_NAME)&.value

  def run_migration(direction)
    ActiveRecord::Migration.suppress_messages { RenameSettingsKeysToTheRubylodeStandard.new.public_send(direction) }
  end

  test "up moves the saved values to the new keys" do
    Setting[SETTING_NAME] = { "welcome_projects_table" => "1", "welcome_projects_table_column" => "left", "projects_table_limit" => "35", "trend_weeks" => "8" }
    run_migration(:up)
    assert_equal({ "show_on_welcome_page" => "1", "welcome_page_column" => "left", "maximum_rows" => "35", "trend_weeks" => "8" }, saved)
  end

  test "down moves them back" do
    Setting[SETTING_NAME] = { "show_on_welcome_page" => "1", "welcome_page_column" => "left", "maximum_rows" => "35" }
    run_migration(:down)
    assert_equal({ "welcome_projects_table" => "1", "welcome_projects_table_column" => "left", "projects_table_limit" => "35" }, saved)
  end

  test "nothing saved means nothing is written, in both directions" do
    run_migration(:up)
    assert_nil saved
    run_migration(:down)
    assert_nil saved
  end

  test "the new settings read what the migration moved" do
    Setting[SETTING_NAME] = { "welcome_projects_table" => "1", "projects_table_limit" => "35" }
    run_migration(:up)
    settings = RubylodeProjects::Settings.new
    assert settings.show_on_welcome_page?
    assert_equal 35, settings.maximum_rows
  end
end
