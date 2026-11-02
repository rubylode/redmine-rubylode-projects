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

require_relative "../test_helper"

# Redmine's blocks the cards replace are hidden by the stylesheet, keyed on the wrapper class the cards view sets.
class RubylodeProjectsReplacedBlocksStylesheetTest < ActiveSupport::TestCase
  STYLESHEET = File.expand_path("../../assets/stylesheets/projects.css", __dir__)

  REPLACED_BLOCKS = [
    ".splitcontentleft > .wiki", # the description, shown as the subtitle instead
    ".splitcontent .issues.box",
    ".splitcontent .spent_time.box",
    ".splitcontent .members.box",
    ".splitcontent .projects.box" # subprojects
  ].freeze

  def hide_rule
    css = File.read(STYLESHEET)
    css[/((?:\.rubylode-projects-cards-shown[^{]+?,?\s*)+)\{\s*display:\s*none;\s*\}/, 1].to_s
  end

  test "each replaced block is hidden with display none, only under the cards-shown wrapper" do
    selectors = hide_rule.split(",").map(&:strip)
    assert_equal REPLACED_BLOCKS.map { |block| ".rubylode-projects-cards-shown #{block}" }, selectors
  end

  test "news and other plugins' blocks are not hidden" do
    assert_not_includes hide_rule, "news"
    assert_equal 4, hide_rule.scan(".box").size, "only issue tracking, time tracking, members and subprojects"
  end
end
