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
  # A project list column whose value is the project's issue figures. The figures are put on each project by
  # ProjectQueryPatch#results_scope, in a fixed number of queries for the whole page; the helper draws the cell from them.
  # None of these columns is sortable: the figures depend on what the viewer may see, so there is no cheap column to sort by.
  class ProjectFigureColumn < QueryColumn
    def value_object(project) = project.rubylode_figures
    alias_method :value, :value_object
  end
end
