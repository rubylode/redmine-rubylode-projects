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
  # The plugin's settings (Administration, Plugins, Configure), read with their defaults and checked before they are saved.
  # Redmine keeps them as one hash under Setting.plugin_redmine_rubylode_projects; anything missing or unusable falls back
  # to the default, so a half-filled hash from an older version never breaks the page.
  class PluginSettings
    DISPLAY_CHOICES = %w[list board redmine].freeze
    COLUMN_CHOICES = %w[open_issues overdue closed_week percent_done trend last_activity].freeze
    TREND_WEEKS_RANGE = (4..26)
    WELCOME_COLUMN_CHOICES = %w[left right].freeze
    TABLE_LIMIT_RANGE = ProjectsTable::LIMIT_RANGE
    PLUGIN_ID = :redmine_rubylode_projects

    DEFAULTS = {
      "default_display" => "list",
      "show_summary" => "1",
      "added_columns" => %w[open_issues overdue percent_done trend],
      "trend_weeks" => "12",
      "welcome_projects_table" => "0",
      "welcome_projects_table_column" => "right",
      "projects_table_limit" => "20",
      "projects_table_show_description" => "1",
      "projects_table_show_done_bar" => "1"
    }.freeze

    # An unsaved hash can be passed in (the settings form on a failed save, tests); by default the saved one is read.
    def initialize(values = nil)
      @values = (values || saved_values).to_h.stringify_keys
    end

    # Returns the problems with a submitted hash as an array of messages, empty when it can be saved.
    def self.errors_for(values)
      new(values).errors
    end

    def errors
      messages = []
      unless DISPLAY_CHOICES.include?(@values.fetch("default_display", DEFAULTS["default_display"]))
        messages << I18n.t(:rubylode_projects_error_default_display)
      end
      unless valid_trend_weeks?(@values.fetch("trend_weeks", DEFAULTS["trend_weeks"]))
        messages << I18n.t(:rubylode_projects_error_trend_weeks, first: TREND_WEEKS_RANGE.first, last: TREND_WEEKS_RANGE.last)
      end
      unless WELCOME_COLUMN_CHOICES.include?(@values.fetch("welcome_projects_table_column", DEFAULTS["welcome_projects_table_column"]))
        messages << I18n.t(:rubylode_projects_error_welcome_column)
      end
      unless valid_table_limit?(@values.fetch("projects_table_limit", DEFAULTS["projects_table_limit"]))
        messages << I18n.t(:rubylode_projects_error_table_limit, first: TABLE_LIMIT_RANGE.first, last: TABLE_LIMIT_RANGE.last)
      end
      unknown = submitted_columns - COLUMN_CHOICES
      messages << I18n.t(:rubylode_projects_error_columns, names: unknown.join(", ")) if unknown.any?
      messages
    end

    def valid? = errors.empty?

    # "list", "board", or "redmine" when the choice is left to Redmine's own setting.
    def default_display
      choice = @values["default_display"]
      DISPLAY_CHOICES.include?(choice) ? choice : DEFAULTS["default_display"]
    end

    def override_display? = default_display != "redmine"

    def summary_shown?
      return true unless @values.key?("show_summary")

      !%w[0 false].include?(@values["show_summary"].to_s)
    end

    # In the order of COLUMN_CHOICES, so the columns do not move about with the order the boxes were ticked.
    def added_columns
      return DEFAULTS["added_columns"] unless @values.key?("added_columns")

      COLUMN_CHOICES & submitted_columns
    end

    def trend_weeks
      valid_trend_weeks?(@values["trend_weeks"]) ? Integer(@values["trend_weeks"].to_s, 10) : Integer(DEFAULTS["trend_weeks"])
    end

    def welcome_table_shown? = switched_on?("welcome_projects_table")

    def welcome_table_column
      choice = @values["welcome_projects_table_column"]
      WELCOME_COLUMN_CHOICES.include?(choice) ? choice : DEFAULTS["welcome_projects_table_column"]
    end

    # An unusable value reads as the default; a whole number outside the range is held to it.
    def table_limit
      Integer(@values["projects_table_limit"].to_s, 10).clamp(TABLE_LIMIT_RANGE)
    rescue ArgumentError, TypeError
      Integer(DEFAULTS["projects_table_limit"])
    end

    def table_description_shown? = switched_on?("projects_table_show_description")

    def table_done_bar_shown? = switched_on?("projects_table_show_done_bar")

    private

    def switched_on?(key)
      return DEFAULTS[key] == "1" unless @values.key?(key)

      !%w[0 false].include?(@values[key].to_s)
    end

    def valid_table_limit?(value)
      TABLE_LIMIT_RANGE.cover?(Integer(value.to_s, 10))
    rescue ArgumentError, TypeError
      false
    end

    def saved_values
      Setting.send(:"plugin_#{PLUGIN_ID}") || {}
    end

    def submitted_columns = Array(@values["added_columns"]).map(&:to_s).reject(&:empty?)

    def valid_trend_weeks?(value)
      TREND_WEEKS_RANGE.cover?(Integer(value.to_s, 10))
    rescue ArgumentError, TypeError
      false
    end
  end
end
