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
  # Prepended to ProjectsQueriesHelper: draws the plugin's columns in the list and writes them as plain text in the CSV
  # export. Redmine's own columns go to Redmine's code unchanged.
  module ProjectColumnsHelper
    def column_value(column, item, value)
      return super unless rubylode_column?(column, item)
      return "" if value.nil?

      case column.name
      when :rubylode_open_issues then rubylode_count_link(item, value.open_count) { |link| link.status(:open) }
      when :rubylode_overdue_issues then rubylode_overdue_cell(item, value)
      when :rubylode_closed_week then rubylode_closed_week_cell(item, value)
      when :rubylode_percent_done then rubylode_progress_cell(item, value)
      when :rubylode_trend then rubylode_sparkline(item, value)
      end
    end

    def csv_value(column, object, value)
      return super unless rubylode_column?(column, object)
      return "" if value.nil?

      case column.name
      when :rubylode_open_issues then value.open_count
      when :rubylode_overdue_issues then value.overdue_count
      when :rubylode_closed_week then value.closed_recent_count
      when :rubylode_percent_done then value.total_count.zero? ? "" : "#{value.done_percentage}%"
      when :rubylode_trend then value.closed_by_week.join(" ")
      end
    end

    private

    def rubylode_column?(column, item)
      item.is_a?(Project) && RubylodeProjects::ProjectColumns.own_name?(column.name)
    end

    # The links count a project's issues the way the figures were counted: with its subprojects when it has some and
    # Redmine's setting includes them, and without them when the setting is off.
    def rubylode_project_link(project)
      subprojects = project.leaf? ? nil : (Setting.display_subprojects_issues? ? :include : :exclude)
      RubylodeProjects::IssueListLink.new(base_path: project_issues_path(project), subprojects: subprojects)
    end

    def rubylode_count_link(project, count)
      link_to(number_with_delimiter(count), yield(rubylode_project_link(project)), class: "rubylode-projects-count")
    end

    def rubylode_overdue_cell(project, figures)
      return content_tag(:span, "0", class: "rubylode-projects-count rubylode-projects-count-none") if figures.overdue_count.zero?

      link_to(number_with_delimiter(figures.overdue_count), rubylode_project_link(project).overdue(User.current.today),
              class: "rubylode-projects-count rubylode-projects-count-overdue")
    end

    def rubylode_closed_week_cell(project, figures)
      today = User.current.today
      rubylode_count_link(project, figures.closed_recent_count) do |link|
        link.closed_between(today - (RubylodeProjects::PortfolioMetrics::RECENT_DAYS - 1), today)
      end
    end

    # A thin bar and the share of issues that are closed, the same figure as the Overview's done tile.
    def rubylode_progress_cell(project, figures)
      return content_tag(:span, "–", class: "rubylode-projects-count-none") if figures.total_count.zero?

      percentage = figures.done_percentage
      link_to(rubylode_project_link(project).status(:closed), class: "rubylode-projects-progress",
                                                               title: l(:rubylode_projects_closed_of_total, closed: number_with_delimiter(figures.closed_count), total: number_with_delimiter(figures.total_count))) do
        content_tag(:span, content_tag(:span, "", class: "rubylode-projects-progress-fill", style: "width: #{percentage}%"),
                    class: "rubylode-projects-progress-track", role: "presentation") +
          content_tag(:span, "#{percentage}%", class: "rubylode-projects-progress-label")
      end
    end

    # The closed-per-week line. Its weekly figures, and the links the card offers, go in the page's data block (see
    # rubylode_spark_data) under the project's id; the script draws the card on hover and focus.
    def rubylode_sparkline(project, figures)
      layout = RubylodeProjects::SparklineLayout.new(figures.closed_by_week)
      subprojects = project.leaf? ? "" : (Setting.display_subprojects_issues? ? "include" : "exclude")
      (@rubylode_spark_data ||= {})[project.id] = { name: project.name, closed: figures.closed_by_week, opened: figures.opened_by_week,
                                                    base: project_issues_path(project), subprojects: subprojects }
      label = l(:rubylode_projects_trend_label, count: layout.values.size, values: layout.values.join(", "))
      content_tag(:span, class: "rubylode-spark-host") do
        content_tag(:span, tabindex: 0, role: "img", class: "rubylode-spark", "aria-label": label, data: { rubylode_spark: project.id }) do
          tag.svg(viewBox: "0 0 #{layout.width} #{layout.height}", class: "rubylode-spark-graphic", focusable: "false", "aria-hidden": "true") do
            tag.path(d: layout.area_path, class: "rubylode-spark-area") + tag.polyline(points: layout.line_points, class: "rubylode-spark-line")
          end
        end
      end
    end
  end
end
