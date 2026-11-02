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
  # Pages for the board view of the projects list. The board draws a tree, so a page holds whole trees: a top project
  # with every subproject under it. The per-page number counts top projects, and a subproject is never cut off from its parent.
  # Projects only need lft and rgt, the nested set columns Redmine keeps on every project.
  class BoardPages
    def initialize(projects)
      @projects = projects.sort_by(&:lft)
    end

    def trees
      @trees ||= @projects.each_with_object([]) do |project, trees|
        root = trees.last&.first
        if root && project.lft > root.lft && project.rgt < root.rgt
          trees.last << project
        else
          trees << [project]
        end
      end
    end

    def tree_count = trees.size

    def projects_for(offset:, limit:)
      Array(trees[offset, limit]).flatten
    end
  end
end
