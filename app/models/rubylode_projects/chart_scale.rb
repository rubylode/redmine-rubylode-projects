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
  # A count axis: whole, round steps (1, 2 or 5 times a power of ten), about four of them, reaching past the highest value.
  class ChartScale
    ROUND_FACTORS = [1, 2, 5, 10].freeze
    INTERVALS_WANTED = 4

    def initialize(highest_value)
      @highest_value = highest_value.to_i
    end

    def step
      @step ||= begin
        raw_step = @highest_value.to_f / INTERVALS_WANTED
        if raw_step <= 1
          1
        else
          magnitude = 10**Math.log10(raw_step).floor
          magnitude * ROUND_FACTORS.find { |factor| factor * magnitude >= raw_step }
        end
      end
    end

    def top
      [(@highest_value.to_f / step).ceil, 1].max * step
    end

    def ticks
      (0..top).step(step).to_a
    end
  end
end
