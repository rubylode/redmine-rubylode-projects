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
  # Another plugin may decorate the projects list with a summary of its own. When it is installed, this plugin adds neither
  # its tiles and charts nor its columns, so nothing shows twice. The display choice (list or board) still applies.
  module Coexistence
    OTHER_SUMMARY_PLUGIN_ID = :redmine_projects_dashboard

    def self.other_summary_present?
      Redmine::Plugin.installed?(OTHER_SUMMARY_PLUGIN_ID)
    end
  end
end
