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
  # Prepended to Redmine's ProjectsController. Both actions run Redmine's own code first and only add to it.
  module ProjectsControllerPatch
    # The Overview page: hands the cards their data. Nothing is queried until the view asks.
    def show
      @rubylode_project_overview = RubylodeProjects::ProjectOverview.new(@project, user: User.current)
      super
    end

    # The projects list. Redmine 7 pages the list view itself but loads every project for the board view.
    # The page is rendered after this method returns, so the board's entries can still be cut to one page here.
    # Only Redmine's HTML board branch leaves entries without pages; the API, Atom and CSV branches set neither or render
    # themselves. Checking that, rather than the request format, also covers a client that sends "Accept: */*".
    def index
      super
      paginate_board if !performed? && @query&.display_type == "board" && @entries && @entry_pages.nil?
    end

    private

    REMEMBERED_DISPLAY_KEY = :rubylode_projects_display_type

    # Redmine builds the query here, before it reads its display type, so a change made after super is what the page uses.
    def retrieve_project_query
      super
      remember_requested_display
      apply_default_display
      apply_added_columns
    end

    # A display named in the address is the user choosing one; it lasts for the session, so the plain /projects link in the
    # menu does not undo it. Redmine keeps no such memory for the projects list (it does not use the session for it).
    def remember_requested_display
      return if api_request? || !request.format.html?

      requested = requested_display_type
      session[REMEMBERED_DISPLAY_KEY] = requested if RubylodeProjects::DisplayRule.rememberable?(requested)
    end

    def apply_default_display
      return if api_request?

      rule = RubylodeProjects::DisplayRule.new(settings: RubylodeProjects::Settings.new)
      display = rule.display_for(requested: requested_display_type, saved_query: @query.persisted?,
                                 remembered: session[REMEMBERED_DISPLAY_KEY])
      @query.display_type = display if display
    end

    # The columns checked in the plugin settings go after Redmine's default columns, but only when the list names no columns
    # of its own: a visit that picked its columns keeps exactly those. A saved query keeps its columns too, unless the
    # "add to saved queries" setting is on and the query holds none of the plugin's columns; then the checked ones are added
    # for this page only, and the query is not written.
    def apply_added_columns
      return if RubylodeProjects::Coexistence.other_summary_present?
      return if params[:c].present? || nested_query_params[:column_names].present?

      settings = RubylodeProjects::Settings.new
      return if @query.persisted? && !saved_query_gets_added_columns?(settings)

      added = RubylodeProjects::ProjectColumns.query_column_names(settings.added_columns)
      @query.column_names = (current_column_names + added).uniq if added.any?
    end

    def saved_query_gets_added_columns?(settings)
      return false if api_request? || !settings.add_columns_to_saved_queries?

      current_column_names.none? { |name| RubylodeProjects::ProjectColumns.own_name?(name) }
    end

    def current_column_names
      @query.has_default_columns? ? @query.default_columns_names : @query.column_names
    end

    def requested_display_type
      params[:display_type].presence || nested_query_params[:display_type].presence
    end

    def nested_query_params
      params[:query].is_a?(ActionController::Parameters) ? params[:query] : {}
    end

    def paginate_board
      board_pages = RubylodeProjects::BoardPages.new(@entries)
      @entry_count = board_pages.tree_count
      @entry_pages = Redmine::Pagination::Paginator.new(@entry_count, per_page_option, params["page"])
      @entries = board_pages.projects_for(offset: @entry_pages.offset, limit: @entry_pages.per_page)
    end
  end
end
