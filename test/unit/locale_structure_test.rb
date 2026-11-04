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

# The Rubylode plugin standard: one locale root, and a label for every setting.
class RubylodeProjectsLocaleStructureTest < ActiveSupport::TestCase
  ENGLISH = YAML.load_file(File.expand_path("../../config/locales/en.yml", __dir__)).fetch("en")

  test "the plugin has one root, rubylode_projects, and no flat keys" do
    assert_equal ["rubylode_projects"], ENGLISH.keys
  end

  test "every setting has a label under settings" do
    RubylodeProjects::Settings::DEFAULTS.each_key do |key|
      assert I18n.exists?("rubylode_projects.settings.#{key}.label"), key
    end
  end

  test "the welcome page placement is worded as the standard words it" do
    assert_equal "Welcome page", I18n.t("rubylode_projects.settings.show_on_welcome_page.label")
    assert_equal "Column", I18n.t("rubylode_projects.settings.welcome_page_column.label")
    assert_equal %w[left right], I18n.t("rubylode_projects.settings.welcome_page_column.choices").keys.map(&:to_s)
  end
end
