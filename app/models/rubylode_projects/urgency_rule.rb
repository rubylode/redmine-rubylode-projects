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
  # Which open issues belong in the "In progress and urgent" list. An open issue is listed when either
  #
  # - its priority sits above the default priority (High, Urgent and Immediate in Redmine's default data), or
  # - it is in progress: its status is no longer the first status of its tracker (the one a new issue gets).
  #
  # Without a default priority, the middle priority (the lower of the two middle ones) stands in for it.
  # ProjectOverview runs the same rule as SQL; a test checks the two agree.
  class UrgencyRule
    def initialize(priority_positions:, default_priority_position:)
      @priority_positions = priority_positions.sort
      @default_priority_position = default_priority_position
    end

    def threshold_position
      return @default_priority_position if @default_priority_position
      return nil if @priority_positions.empty?

      @priority_positions[(@priority_positions.size - 1) / 2]
    end

    def urgent_priority?(position)
      threshold_position.present? && position > threshold_position
    end

    def in_progress?(closed:, status_id:, tracker_default_status_id:)
      !closed && status_id != tracker_default_status_id
    end

    def listed?(closed:, priority_position:, status_id:, tracker_default_status_id:)
      return false if closed

      urgent_priority?(priority_position) ||
        in_progress?(closed: closed, status_id: status_id, tracker_default_status_id: tracker_default_status_id)
    end
  end
end
