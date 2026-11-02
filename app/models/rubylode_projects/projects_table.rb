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
  # The rows of the projects table: one per project the viewer may see, in Redmine's project tree order (a project, then
  # its subprojects, indented), with the open and closed issues the viewer may see.
  #
  # The counts come from two grouped queries however many projects there are. By default each row counts its own issues
  # and its links exclude the subprojects (which have rows of their own). With include_subprojects false only the
  # top-level projects get a row, and each counts everything under it, with links that include the subprojects.
  class ProjectsTable
    LIMIT_RANGE = (1..100)
    DESCRIPTION_LENGTH = 140

    Row = Struct.new(:project, :level, :open_count, :closed_count, :done_percentage, :description, :open_url, :closed_url,
                     keyword_init: true)

    # issues_path is called with a project and returns the path of its issue list (project_issues_path in a view).
    def initialize(user:, issues_path:, limit: 20, include_subprojects: true)
      @user = user
      @issues_path = issues_path
      @limit = limit.to_i.clamp(LIMIT_RANGE)
      @include_subprojects = include_subprojects
    end

    def rows
      @rows ||= begin
        projects = shown_projects
        open_counts = counts_for(Issue.visible(@user).open)
        closed_counts = counts_for(Issue.visible(@user).joins(:status).where(issue_statuses: { is_closed: true }))
        rolled = @include_subprojects ? nil : lft_by_project(open_counts.keys | closed_counts.keys)
        projects.map { |project, level| build_row(project, level, open_counts, closed_counts, rolled) }
      end
    end

    private

    def counts_for(scope) = scope.group(:project_id).count

    # [project, level] pairs. The level is the number of listed projects above it, so a subproject whose parent the
    # viewer cannot see is listed as a top-level project.
    def shown_projects
      above = []
      pairs = Project.visible(@user).active.sorted.to_a.map do |project|
        above.pop while above.any? && above.last.rgt < project.lft
        pair = [project, above.size]
        above.push(project)
        pair
      end
      pairs = pairs.select { |_project, level| level.zero? } unless @include_subprojects
      pairs.first(@limit)
    end

    def lft_by_project(project_ids) = Project.where(id: project_ids).pluck(:id, :lft).to_h

    def build_row(project, level, open_counts, closed_counts, rolled)
      open_count, closed_count = if rolled
        [rolled_sum(open_counts, rolled, project), rolled_sum(closed_counts, rolled, project)]
      else
        [open_counts.fetch(project.id, 0), closed_counts.fetch(project.id, 0)]
      end
      link = IssueListLink.new(base_path: @issues_path.call(project), subprojects: subprojects_choice(project))
      Row.new(project: project, level: level, open_count: open_count, closed_count: closed_count,
              done_percentage: Percentage.of(closed_count, open_count + closed_count), description: one_line(project.description),
              open_url: link.status(:open), closed_url: link.status(:closed))
    end

    def rolled_sum(counts, lft_by_project, project)
      counts.sum { |project_id, count| lft_by_project[project_id].between?(project.lft, project.rgt) ? count : 0 }
    end

    def subprojects_choice(project)
      return nil if project.rgt - project.lft == 1

      @include_subprojects ? :exclude : :include
    end

    def one_line(text)
      line = text.to_s.squish
      line.length > DESCRIPTION_LENGTH ? "#{line[0, DESCRIPTION_LENGTH - 1].rstrip}…" : line
    end
  end
end
