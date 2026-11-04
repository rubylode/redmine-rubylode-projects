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

module RubylodeProjects
  # The settings keys that 2.0.0 renamed, and the move between the old names and the new ones. Used by the migration
  # db/migrate/001_rename_settings_keys_to_the_rubylode_standard.rb and its reverse. Keys that are not renamed stay as they are.
  module SettingKeyRenames
    OLD_TO_NEW = {
      "welcome_projects_table" => "show_on_welcome_page",
      "welcome_projects_table_column" => "welcome_page_column",
      "projects_table_limit" => "maximum_rows"
    }.freeze

    # A new key that is already present wins over a stale old one.
    def self.forward(saved) = rename(saved, OLD_TO_NEW)

    def self.backward(saved) = rename(saved, OLD_TO_NEW.invert)

    def self.rename(saved, names)
      saved.to_h.stringify_keys.each_with_object({}) do |(key, value), result|
        target = names.fetch(key, key)
        next if target != key && saved.to_h.stringify_keys.key?(target)

        result[target] = value
      end
    end
    private_class_method :rename
  end
end
