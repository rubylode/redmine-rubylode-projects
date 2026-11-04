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
  # Prepended to ProjectQuery. Adds the plugin's columns, leaves the issue figures on the projects of a result page, and
  # hands out the figures for the summary above the list.
  module ProjectQueryPatch
    # The columns are not offered at all while another plugin supplies its own summary, so no column name shows twice.
    def available_columns
      columns = super
      RubylodeProjects::Coexistence.other_summary_present? ? columns.reject { |column| RubylodeProjects::ProjectColumns.own_name?(column.name) } : columns
    end

    # Redmine returns a relation and loads it later. It is loaded here, the figures for every project of the page are worked
    # out together, and the same loaded records go on to the page: one set of queries, not one set per project.
    def results_scope(options = {})
      scope = super
      return scope unless columns.any? { |column| RubylodeProjects::ProjectColumns.own_name?(column.name) }

      scope.load.each { |project| project.rubylode_figures = rubylode_metrics.figures_for(project) }
      scope
    end

    # One set of figures per query, shared by the columns and the summary, and sized by the trend setting.
    def rubylode_metrics
      @rubylode_metrics ||= RubylodeProjects::PortfolioMetrics.new(user: User.current,
                                                                   week_count: RubylodeProjects::Settings.new.trend_weeks)
    end
  end
end
