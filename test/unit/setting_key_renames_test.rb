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
require_relative "../../lib/rubylode_projects/setting_key_renames"

class RubylodeProjectsSettingKeyRenamesTest < ActiveSupport::TestCase
  RENAMES = RubylodeProjects::SettingKeyRenames

  test "the old keys move to the standard ones and the other keys stay" do
    saved = { "welcome_projects_table" => "1", "welcome_projects_table_column" => "left", "projects_table_limit" => "35", "trend_weeks" => "8" }
    assert_equal({ "show_on_welcome_page" => "1", "welcome_page_column" => "left", "maximum_rows" => "35", "trend_weeks" => "8" }, RENAMES.forward(saved))
  end

  test "going back restores the old keys" do
    saved = { "show_on_welcome_page" => "1", "welcome_page_column" => "left", "maximum_rows" => "35", "default_display" => "board" }
    assert_equal({ "welcome_projects_table" => "1", "welcome_projects_table_column" => "left", "projects_table_limit" => "35", "default_display" => "board" }, RENAMES.backward(saved))
  end

  test "forward then backward gives back what was saved" do
    saved = { "welcome_projects_table" => "0", "welcome_projects_table_column" => "right", "projects_table_limit" => "20", "added_columns" => %w[trend] }
    assert_equal saved, RENAMES.backward(RENAMES.forward(saved))
  end

  test "a hash that already uses the new keys is left alone, and the new key wins over a stale old one" do
    assert_equal({ "maximum_rows" => "5" }, RENAMES.forward("maximum_rows" => "5"))
    assert_equal({ "maximum_rows" => "5" }, RENAMES.forward("maximum_rows" => "5", "projects_table_limit" => "9"))
  end

  test "symbol keys are read as strings" do
    assert_equal({ "maximum_rows" => "7" }, RENAMES.forward(projects_table_limit: "7"))
  end
end
