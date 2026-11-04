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

require_relative "../../lib/rubylode_projects/setting_key_renames"

# 2.0.0 renames three settings keys (see CHANGELOG.md). This moves the saved values to the new keys; down moves them back.
# Nothing is written when the settings were never saved, so a fresh install keeps reading the defaults.
class RenameSettingsKeysToTheRubylodeStandard < ActiveRecord::Migration[6.1]
  SETTING_NAME = "plugin_redmine_rubylode_projects".freeze

  def up = move { |saved| RubylodeProjects::SettingKeyRenames.forward(saved) }

  def down = move { |saved| RubylodeProjects::SettingKeyRenames.backward(saved) }

  private

  def move
    record = Setting.find_by(name: SETTING_NAME)
    return unless record && record.value.is_a?(Hash)

    Setting[SETTING_NAME] = yield(record.value)
  end
end
