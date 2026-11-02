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
  # Puts the overview cards between Redmine's own page heading and its blocks. Nothing is parsed or rewritten: the page is
  # cut in two at the end of its first heading and the cards go in between. Both parts must already be safe, rendered
  # HTML; slicing a safe buffer keeps it safe, so nothing here marks a string safe.
  module HeadingInsertion
    FIRST_HEADING_END = "</h2>"

    def self.after_first_heading(page_html, addition_html)
      raise ArgumentError, "both parts must be safe, rendered HTML" unless page_html.html_safe? && addition_html.html_safe?

      position = page_html.index(FIRST_HEADING_END)
      return addition_html + page_html if position.nil?

      split_at = position + FIRST_HEADING_END.length
      page_html[0...split_at] + addition_html + page_html[split_at..]
    end
  end
end
