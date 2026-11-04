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
  # Puts the plugin's columns on ProjectQuery. Runs on every code reload (the query class is new each time in development)
  # and adds each column once.
  module ColumnRegistration
    # The caption is a Proc: Redmine reads a plain string as the caption itself, and a Proc is called when the caption is shown.
    COLUMNS = [
      [:rubylode_open_issues, -> { I18n.t("rubylode_projects.columns.open_issues") }],
      [:rubylode_overdue_issues, -> { I18n.t("rubylode_projects.columns.overdue") }],
      [:rubylode_closed_week, -> { I18n.t("rubylode_projects.columns.closed_week") }],
      [:rubylode_percent_done, -> { I18n.t("rubylode_projects.columns.percent_done") }],
      [:rubylode_trend, -> { I18n.t("rubylode_projects.columns.trend") }]
    ].freeze

    def self.register
      known = ProjectQuery.available_columns.map(&:name)
      added = COLUMNS.reject { |name, _caption| known.include?(name) }
                     .map { |name, caption| RubylodeProjects::ProjectFigureColumn.new(name, caption: caption) }
      ProjectQuery.available_columns = ProjectQuery.available_columns + added if added.any?
    end
  end
end
