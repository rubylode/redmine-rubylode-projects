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
  # Renders one of Redmine's own page templates even though this plugin has a template of the same name in front of it.
  # The plugin's projects/show wraps Redmine's projects/show instead of copying it, so whatever the installed Redmine
  # version puts on its Overview page stays there, below the cards.
  module RedmineTemplate
    REDMINE_VIEWS = Rails.root.join("app", "views").to_s

    def self.render(view, name)
      template = lookup_context.find_template(name)
      template.render(view, {})
    end

    # The same for a partial, such as "projects/list"; locals are the partial's local variables.
    def self.render_partial(view, name, locals = {})
      folder, partial = File.split(name)
      template = lookup_context.find_template(partial, [folder], true, locals.keys)
      template.render(view, locals)
    end

    def self.lookup_context
      @lookup_context ||= ActionView::LookupContext.new([REDMINE_VIEWS], formats: [:html])
    end
  end
end
