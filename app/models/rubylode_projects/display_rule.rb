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
  # Decides which display the projects list opens in, so the rules can be tested without a request.
  #
  # The plugin's choice applies only to a plain visit: the address names no display_type, it names no saved query, and the
  # user has not chosen one earlier in this session. Anything else is left to Redmine, so ?display_type=board always gives
  # the board and a saved query is shown as it was saved. The answer is a display type to put on the query, or nil for
  # "change nothing".
  class DisplayRule
    DISPLAY_TYPES = %w[list board].freeze

    # remembered is the display the user last asked for by name in this session, if any.
    def initialize(settings:)
      @settings = settings
    end

    def display_for(requested:, saved_query:, remembered:)
      return nil if requested.present?
      return nil if saved_query
      return remembered if DISPLAY_TYPES.include?(remembered)
      return nil unless @settings.override_display?

      @settings.default_display
    end

    # Whether a display named in the address is one to remember for the session.
    def self.rememberable?(requested)
      DISPLAY_TYPES.include?(requested)
    end
  end
end
