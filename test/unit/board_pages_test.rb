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

class RubylodeProjectsBoardPagesTest < ActiveSupport::TestCase
  Node = Struct.new(:name, :lft, :rgt)

  # alpha (with beta, and gamma under beta), delta, epsilon (with zeta), eta
  def projects
    [Node.new("delta", 7, 8), Node.new("alpha", 1, 6), Node.new("gamma", 3, 4), Node.new("beta", 2, 5),
     Node.new("eta", 13, 14), Node.new("epsilon", 9, 12), Node.new("zeta", 10, 11)]
  end

  def pages
    RubylodeProjects::BoardPages.new(projects)
  end

  test "a tree is a top project with everything under it, in tree order" do
    assert_equal [%w[alpha beta gamma], %w[delta], %w[epsilon zeta], %w[eta]], pages.trees.map { |tree| tree.map(&:name) }
    assert_equal 4, pages.tree_count
  end

  test "a page takes whole trees, so a subproject never lands apart from its parent" do
    assert_equal %w[alpha beta gamma delta], pages.projects_for(offset: 0, limit: 2).map(&:name)
    assert_equal %w[epsilon zeta eta], pages.projects_for(offset: 2, limit: 2).map(&:name)
    assert_empty pages.projects_for(offset: 4, limit: 2)
  end

  test "a filtered list whose parent is missing starts its own tree" do
    filtered = RubylodeProjects::BoardPages.new([Node.new("beta", 2, 5), Node.new("gamma", 3, 4), Node.new("zeta", 10, 11)])
    assert_equal [%w[beta gamma], %w[zeta]], filtered.trees.map { |tree| tree.map(&:name) }
  end

  test "no projects, no trees" do
    assert_equal 0, RubylodeProjects::BoardPages.new([]).tree_count
  end
end
