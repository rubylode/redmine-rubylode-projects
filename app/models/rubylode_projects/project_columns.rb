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

module RubylodeProjects
  # The columns the plugin adds to the project list. The names a settings checkbox uses (see PluginSettings::COLUMN_CHOICES)
  # map to the column names on ProjectQuery. "Last activity" is Redmine's own column, so it is not added a second time.
  module ProjectColumns
    COLUMN_NAMES = {
      "open_issues" => :rubylode_open_issues,
      "overdue" => :rubylode_overdue_issues,
      "closed_week" => :rubylode_closed_week,
      "percent_done" => :rubylode_percent_done,
      "trend" => :rubylode_trend,
      "last_activity" => :last_activity_date
    }.freeze

    OWN_NAMES = COLUMN_NAMES.values.select { |name| name.to_s.start_with?("rubylode_") }.freeze

    def self.own_name?(name) = OWN_NAMES.include?(name.to_sym)

    def self.query_column_names(setting_names)
      setting_names.filter_map { |setting_name| COLUMN_NAMES[setting_name] }
    end
  end
end
