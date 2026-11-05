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

require "redmine"
require_relative "lib/rubylode_projects/hooks"
require_relative "lib/rubylode_projects/projects_table_macro"

Redmine::Plugin.register :redmine_rubylode_projects do
  name "Rubylode Projects"
  author "Rubylode"
  author_url "https://github.com/rubylode"
  url "https://github.com/rubylode/redmine-rubylode-projects"
  description "A project Overview with counts, a weekly chart and urgent issues; for the projects list, a summary, extra columns and board pages; and a projects table for the welcome page and wiki pages"
  version "2.1.0"
  requires_redmine version_or_higher: "6.0.0"
  settings default: RubylodeProjects::Settings::DEFAULTS, partial: "settings/rubylode_projects_settings"
end

# Redmine runs this file again on every code reload, so the patch goes in only once.
unless ProjectsController.ancestors.include?(RubylodeProjects::ProjectsControllerPatch)
  ProjectsController.prepend(RubylodeProjects::ProjectsControllerPatch)
end

unless SettingsController.ancestors.include?(RubylodeProjects::SettingsControllerPatch)
  SettingsController.prepend(RubylodeProjects::SettingsControllerPatch)
end

# The columns go on ProjectQuery, and the patches on its helper, again after every code reload (this file runs inside
# Redmine's own prepare callback, so they are in place before the first request).
Project.include(RubylodeProjects::ProjectFiguresHolder) unless Project.include?(RubylodeProjects::ProjectFiguresHolder)
ProjectQuery.prepend(RubylodeProjects::ProjectQueryPatch) unless ProjectQuery.ancestors.include?(RubylodeProjects::ProjectQueryPatch)
unless ProjectsQueriesHelper.ancestors.include?(RubylodeProjects::ProjectColumnsHelper)
  ProjectsQueriesHelper.prepend(RubylodeProjects::ProjectColumnsHelper)
end
RubylodeProjects::ColumnRegistration.register
