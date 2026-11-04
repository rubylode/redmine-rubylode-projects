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
  # What the plugin adds to one request for the projects list: whether the summary shows, and the data the script needs.
  #
  # The summary shows on the HTML list of the Projects page when the setting is on, the address does not say ?summary=0,
  # and no other plugin supplies a summary of its own. The columns do not depend on any of this.
  class IndexPage
    def initialize(query:, params:, settings: Settings.new, other_summary_present: Coexistence.other_summary_present?)
      @query = query
      @params = params
      @settings = settings
      @other_summary_present = other_summary_present
    end

    def summary_shown?
      @settings.summary_shown? && @params[:summary].to_s != "0" && !@other_summary_present && @query.is_a?(ProjectQuery) && @query.valid?
    end

    # The ids of the projects the list is filtered to, over every page: the summary describes the whole list.
    def portfolio_project_ids
      @query.base_scope.reorder(nil).pluck(:id)
    end
  end
end
