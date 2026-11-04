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

require_relative "../test_helper"

class RubylodeProjectsDisplayRuleTest < ActiveSupport::TestCase
  def rule(default_display = "list")
    RubylodeProjects::DisplayRule.new(settings: RubylodeProjects::Settings.new("default_display" => default_display))
  end

  def display_for(rule, requested: nil, saved_query: false, remembered: nil)
    rule.display_for(requested: requested, saved_query: saved_query, remembered: remembered)
  end

  test "a plain visit gets the configured display" do
    assert_equal "list", display_for(rule("list"))
    assert_equal "board", display_for(rule("board"))
  end

  test "leaving it to Redmine changes nothing" do
    assert_nil display_for(rule("redmine"))
  end

  test "a display named in the address is left alone, whatever the setting" do
    assert_nil display_for(rule("list"), requested: "board")
    assert_nil display_for(rule("board"), requested: "list")
  end

  test "a saved query is left as it was saved" do
    assert_nil display_for(rule("list"), saved_query: true)
    assert_nil display_for(rule("board"), saved_query: true, remembered: "list")
  end

  test "a choice made earlier in the session wins over the setting" do
    assert_equal "board", display_for(rule("list"), remembered: "board")
    assert_equal "list", display_for(rule("board"), remembered: "list")
  end

  test "a remembered choice still applies when the setting leaves it to Redmine" do
    assert_equal "board", display_for(rule("redmine"), remembered: "board")
  end

  test "a remembered value that is not a display is ignored" do
    assert_equal "list", display_for(rule("list"), remembered: "grid")
  end

  test "only list and board are worth remembering" do
    assert RubylodeProjects::DisplayRule.rememberable?("board")
    assert RubylodeProjects::DisplayRule.rememberable?("list")
    refute RubylodeProjects::DisplayRule.rememberable?("grid")
    refute RubylodeProjects::DisplayRule.rememberable?(nil)
  end
end
