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
  # The wiki macro {{projects_table}}, with optional title=, limit= and subprojects= arguments:
  #
  #   {{projects_table}}
  #   {{projects_table(title="Our projects", limit=10, subprojects=false)}}
  #
  # An argument it does not know, or a value it cannot use, shows Redmine's usual macro error instead of a guess.
  module ProjectsTableMacro
    KNOWN_ARGUMENTS = %w[title limit subprojects].freeze
    FALSE_WORDS = %w[false 0 no off].freeze
    TRUE_WORDS = %w[true 1 yes on].freeze

    # Turns the macro's arguments (strings such as "limit=5") into the locals of the projects_table partial.
    def self.locals_for(arguments)
      pairs = arguments.map { |argument| argument.to_s.split("=", 2).map(&:strip) }
      locals = {}
      pairs.each do |name, value|
        raise ArgumentError, I18n.t(:rubylode_projects_macro_unknown_argument, name: name) unless KNOWN_ARGUMENTS.include?(name) && !value.nil?

        locals[name.to_sym] = send(:"read_#{name}", value.delete_prefix('"').delete_suffix('"'))
      end
      locals
    end

    def self.read_title(value) = value

    def self.read_limit(value)
      number = Integer(value, 10)
      raise ArgumentError unless ProjectsTable::LIMIT_RANGE.cover?(number)

      number
    rescue ArgumentError, TypeError
      raise ArgumentError, I18n.t(:rubylode_projects_macro_bad_limit, first: ProjectsTable::LIMIT_RANGE.first, last: ProjectsTable::LIMIT_RANGE.last)
    end

    def self.read_subprojects(value)
      word = value.downcase
      return true if TRUE_WORDS.include?(word)
      return false if FALSE_WORDS.include?(word)

      raise ArgumentError, I18n.t(:rubylode_projects_macro_bad_subprojects)
    end

    Redmine::WikiFormatting::Macros.register do
      desc <<~DESCRIPTION
        A table of the projects you may see, with their open and closed issue counts:

          {{projects_table}}
          {{projects_table(title="Our projects", limit=10, subprojects=false)}}

        title: the caption (default Projects). limit: the most rows, 1 to 100 (default from the plugin settings).
        subprojects=false: top-level projects only, each counting everything under it.
      DESCRIPTION
      macro :projects_table do |_object, arguments|
        locals = RubylodeProjects::ProjectsTableMacro.locals_for(arguments)
        render(partial: "rubylode_projects/projects_table", locals: locals)
      end
    end
  end
end
