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
  # Puts the projects table on the welcome page (view_welcome_index_left and _right) when the setting asks for it.
  # Loads the stylesheet on the two pages the plugin changes: the projects list (index) and a project's Overview (show).
  # Neither page has a head hook of its own, so the layout hook checks the controller and action.
  class Hooks < Redmine::Hook::ViewListener
    STYLED_ACTIONS = %w[index show].freeze

    def view_layouts_base_html_head(context)
      return unless styled_page?(context)

      assets = stylesheet_link_tag("projects", plugin: "redmine_rubylode_projects")
      assets += javascript_include_tag("overview", plugin: "redmine_rubylode_projects", defer: true)
      assets
    end

    def view_welcome_index_left(context) = welcome_table(context, "left")

    def view_welcome_index_right(context) = welcome_table(context, "right")

    private

    # The welcome page block, when the setting is on and this is the column the setting names. The partial adds the
    # stylesheet itself, so the table also works from the macro and from other plugins.
    def welcome_table(context, column)
      settings = PluginSettings.new
      return unless settings.welcome_table_shown? && settings.welcome_table_column == column

      context[:hook_caller].render(partial: "rubylode_projects/projects_table")
    end

    def styled_page?(context)
      controller = context[:controller]
      controller.is_a?(ProjectsController) && STYLED_ACTIONS.include?(controller.action_name)
    end
  end
end
