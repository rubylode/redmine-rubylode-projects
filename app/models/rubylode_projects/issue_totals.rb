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
  # The four tiles: open, closed, all and done, added up from the tracker tallies.
  class IssueTotals
    def initialize(tracker_tallies)
      @tracker_tallies = tracker_tallies
    end

    def open_count = @tracker_tallies.sum(&:open_count)

    def closed_count = @tracker_tallies.sum(&:closed_count)

    def total_count = open_count + closed_count

    def done_percentage = Percentage.of(closed_count, total_count)

    # Trackers that have open issues, the most open first.
    def open_by_tracker
      @tracker_tallies.select { |tally| tally.open_count.positive? }.sort_by { |tally| -tally.open_count }
    end
  end
end
