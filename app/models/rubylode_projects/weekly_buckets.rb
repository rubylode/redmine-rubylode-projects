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
  # Counts opened and closed dates per calendar week (Monday to Sunday), for the last few weeks up to today.
  class WeeklyBuckets
    Week = Data.define(:start_date, :opened_count, :closed_count) do
      def end_date = start_date + 6

      # The ISO week number, as calendars print it.
      def number = start_date.cweek
    end

    def self.highest_count(weeks)
      weeks.flat_map { |week| [week.opened_count, week.closed_count] }.max || 0
    end

    attr_reader :week_count

    def initialize(today:, week_count:)
      @today = today
      @week_count = week_count
    end

    # The Monday of the oldest week: the counts need nothing older.
    def first_date
      @today.beginning_of_week(:monday) - ((@week_count - 1) * 7)
    end

    def weeks(opened_dates:, closed_dates:)
      opened_per_week = count_per_week(opened_dates)
      closed_per_week = count_per_week(closed_dates)
      Array.new(@week_count) do |index|
        start_date = first_date + (index * 7)
        Week.new(start_date: start_date, opened_count: opened_per_week[start_date], closed_count: closed_per_week[start_date])
      end
    end

    private

    def count_per_week(dates)
      dates.select { |date| date.between?(first_date, @today) }
           .each_with_object(Hash.new(0)) { |date, counts| counts[date.beginning_of_week(:monday)] += 1 }
    end
  end
end
