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

class RubylodeProjectsHeadingInsertionTest < ActiveSupport::TestCase
  def insert(page, addition)
    RubylodeProjects::HeadingInsertion.after_first_heading(page.html_safe, addition.html_safe)
  end

  test "the addition goes right after the page's first h2" do
    page = %(<div class="contextual">x</div>\n<h2>Overview</h2>\n<div class="splitcontent"><h2>Other</h2></div>)
    assert_equal %(<div class="contextual">x</div>\n<h2>Overview</h2><section>cards</section>\n<div class="splitcontent"><h2>Other</h2></div>),
                 insert(page, "<section>cards</section>")
  end

  test "without a heading the addition goes first, so nothing is lost" do
    assert_equal "<section>cards</section><p>page</p>", insert("<p>page</p>", "<section>cards</section>")
  end

  test "the result is safe HTML" do
    assert insert("<h2>a</h2>", "<b>b</b>").html_safe?
  end

  test "a part that is not already safe HTML is refused, never marked safe" do
    assert_raises(ArgumentError) { RubylodeProjects::HeadingInsertion.after_first_heading("<h2>a</h2>", "<b>b</b>".html_safe) }
    assert_raises(ArgumentError) { RubylodeProjects::HeadingInsertion.after_first_heading("<h2>a</h2>".html_safe, "<b>b</b>") }
  end
end
