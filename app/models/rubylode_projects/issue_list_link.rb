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
  # Builds links to a project's issue list, in the query format Redmine's own filters use:
  #
  #   /projects/shop/issues?set_filter=1&f[]=status_id&op[status_id]==*&f[]=created_on&op[created_on]=><&v[created_on][]=2026-10-19...
  #
  # Only filter names from a fixed list, integer ids and dates go in, and every part is percent-escaped, so nothing a
  # user typed (a subject, a tracker name) can reach a URL. Redmine drops a filter it does not offer, which is why the
  # subproject filter is harmless on a project without subprojects.
  class IssueListLink
    STATUS_OPERATORS = { open: "o", closed: "c", all: "*" }.freeze
    SUBPROJECT_OPERATORS = { include: "*", exclude: "!*" }.freeze
    BETWEEN = "><"

    # base_path is the issue list path of the project (project_issues_path), or the global one (issues_path). subprojects is
    # :include or :exclude, to match how the numbers next to the link were counted, or nil to leave it to Redmine's setting.
    # project_ids limits the list to those projects (a portfolio of several), whole numbers only; the global list needs it.
    def initialize(base_path:, subprojects: nil, project_ids: nil)
      @base_path = base_path
      @subprojects = subprojects
      @project_ids = project_ids&.map { |project_id| Integer(project_id).to_s }
    end

    def status(status)
      build(status_filter(status))
    end

    def tracker(tracker_id, status: :all)
      build(status_filter(status), ["tracker_id", "=", [Integer(tracker_id).to_s]])
    end

    def opened_between(first_date, last_date)
      build(status_filter(:all), date_filter("created_on", first_date, last_date))
    end

    def closed_between(first_date, last_date)
      build(status_filter(:all), date_filter("closed_on", first_date, last_date))
    end

    # Open issues whose due date is before today: "on or before yesterday", which is how the filter says it.
    def overdue(today)
      build(status_filter(:open), ["due_date", "<=", [date_value(today - 1)]])
    end

    def due_between(first_date, last_date)
      build(status_filter(:open), date_filter("due_date", first_date, last_date))
    end

    def unassigned
      build(status_filter(:open), ["assigned_to_id", "!*", []])
    end

    private

    def status_filter(status)
      ["status_id", STATUS_OPERATORS.fetch(status), []]
    end

    def date_filter(field, first_date, last_date)
      [field, BETWEEN, [date_value(first_date), date_value(last_date)]]
    end

    def date_value(date)
      raise ArgumentError, "a Date is needed, got #{date.class}" unless date.is_a?(Date)

      date.iso8601
    end

    def build(*filters)
      filters += [["project_id", "=", @project_ids]] if @project_ids&.any?
      filters += [["subproject_id", SUBPROJECT_OPERATORS.fetch(@subprojects), []]] if @subprojects
      parts = ["set_filter=1"]
      filters.each do |field, operator, values|
        parts << "f[]=#{escape(field)}"
        parts << "op[#{escape(field)}]=#{escape(operator)}"
        values.each { |value| parts << "v[#{escape(field)}][]=#{escape(value)}" }
      end
      "#{@base_path}?#{parts.join('&')}"
    end

    def escape(value) = ERB::Util.url_encode(value.to_s)
  end
end
