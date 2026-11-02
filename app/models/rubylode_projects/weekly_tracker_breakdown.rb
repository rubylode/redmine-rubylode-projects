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
  # Which trackers the issues opened in each week belong to: the biggest few per week, as [tracker_id, count] pairs.
  class WeeklyTrackerBreakdown
    DEFAULT_LIMIT = 3

    # opened is a list of [date, tracker_id] pairs. Dates outside the window of week_count weeks up to today are ignored.
    def initialize(opened:, today:, week_count:, limit: DEFAULT_LIMIT)
      @buckets = WeeklyBuckets.new(today: today, week_count: week_count)
      @today = today
      @limit = limit
      @opened = opened
    end

    # { Monday => [[tracker_id, count], ...] } for every week of the window, empty for a week with nothing opened.
    def top_trackers_by_week
      grouped = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      @opened.each do |date, tracker_id|
        next unless date.between?(@buckets.first_date, @today)

        grouped[date.beginning_of_week(:monday)][tracker_id] += 1
      end
      Array.new(@buckets.week_count) do |index|
        start_date = @buckets.first_date + (index * 7)
        [start_date, grouped[start_date].sort_by { |tracker_id, count| [-count, tracker_id] }.first(@limit)]
      end.to_h
    end
  end
end
