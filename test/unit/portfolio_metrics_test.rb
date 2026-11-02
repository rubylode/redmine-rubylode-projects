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

class RubylodeProjectsPortfolioMetricsTest < ActiveSupport::TestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :enabled_modules, :trackers,
           :projects_trackers, :issue_statuses, :enumerations, :workflows, :issues, :custom_fields, :custom_values,
           :custom_fields_projects, :custom_fields_trackers

  CLOSED_STATUS = 5

  def setup
    Issue.delete_all
    @today = Date.new(2026, 11, 4) # a Wednesday
    @admin = User.find(1)
    @parent = Project.generate!(name: "Metrics parent", is_public: true, tracker_ids: [1, 2])
    @child = Project.generate_with_parent!(@parent, name: "Metrics child", is_public: true, tracker_ids: [1, 2])
    @alone = Project.generate!(name: "Metrics alone", is_public: true, tracker_ids: [1, 2])
  end

  def metrics(user: @admin, with_subprojects: true, week_count: 4)
    RubylodeProjects::PortfolioMetrics.new(user: user, week_count: week_count, with_subprojects: with_subprojects, today: @today)
  end

  def issue(project, **attributes)
    created_on = attributes.delete(:created_on)
    closed_on = attributes.delete(:closed_on)
    Issue.generate!({ project: project, author_id: 2, priority_id: 5, tracker_id: 1 }.merge(attributes)).tap do |created|
      created.update_columns(created_on: created_on) if created_on
      created.update_columns(closed_on: closed_on) if closed_on
    end
  end

  def at_noon(date) = date.in_time_zone.change(hour: 12)

  test "open, closed, overdue, due soon and unassigned are counted per project from visible issues" do
    issue(@alone, due_date: @today - 2)                              # open, overdue
    issue(@alone, due_date: @today)                                   # open, due today: due soon, not overdue
    issue(@alone, due_date: @today + 7, assigned_to_id: 2)            # open, due in 7 days
    issue(@alone, due_date: @today + 8, assigned_to_id: 2)            # open, due later
    issue(@alone, status_id: CLOSED_STATUS, due_date: @today - 30)    # closed: never overdue
    figures = metrics.own_figures_of(@alone.id)
    assert_equal 4, figures.open_count
    assert_equal 1, figures.closed_count
    assert_equal 1, figures.overdue_count
    assert_equal 2, figures.due_soon_count
    assert_equal 2, figures.unassigned_count
    assert_equal 5, figures.total_count
    assert_equal 20, figures.done_percentage
  end

  test "weekly counts use the weeks of the buckets, newest last, and recent closes the last seven days" do
    this_monday = @today.beginning_of_week(:monday)
    issue(@alone, created_on: at_noon(this_monday - 7))
    issue(@alone, created_on: at_noon(@today))
    issue(@alone, status_id: CLOSED_STATUS, created_on: at_noon(this_monday - 30), closed_on: at_noon(@today - 6))
    issue(@alone, status_id: CLOSED_STATUS, created_on: at_noon(this_monday - 30), closed_on: at_noon(@today - 7))
    issue(@alone, status_id: CLOSED_STATUS, created_on: at_noon(this_monday - 90), closed_on: at_noon(this_monday - 90))
    issue(@alone, status_id: CLOSED_STATUS, created_on: at_noon(this_monday - 30), closed_on: at_noon(@today))
    figures = metrics.own_figures_of(@alone.id)
    assert_equal 4, figures.opened_by_week.size
    assert_equal [0, 0, 1, 1], figures.opened_by_week
    assert_equal [0, 0, 2, 1], figures.closed_by_week, "two closes last week (six and seven days ago), one today, one too old"
    assert_equal 2, figures.closed_recent_count, "today and six days ago are within the last seven days; seven days ago is not"
  end

  test "a project's figures include its subprojects when the setting is on and leave them out when it is off" do
    issue(@parent)
    issue(@child)
    issue(@child, status_id: CLOSED_STATUS)
    assert_equal [2, 1], metrics.figures_for(@parent).then { |figures| [figures.open_count, figures.closed_count] }
    assert_equal [1, 0], metrics(with_subprojects: false).figures_for(@parent).then { |figures| [figures.open_count, figures.closed_count] }
    assert_equal [1, 1], metrics.figures_for(@child).then { |figures| [figures.open_count, figures.closed_count] }
    assert_equal 2, metrics(with_subprojects: false).subtree_figures_for(@parent).open_count, "the subtree is always counted by subtree_figures_for"
  end

  test "combined figures count each issue once over exactly the projects given" do
    issue(@parent)
    issue(@child)
    issue(@alone)
    assert_equal 2, metrics.combined_figures([@parent.id, @alone.id]).open_count
    assert_equal 3, metrics.combined_figures([@parent.id, @child.id, @alone.id]).open_count
    assert_equal 0, metrics.combined_figures([]).open_count
  end

  test "a project with no issues has empty figures" do
    empty = metrics.figures_for(@alone)
    assert_equal [0, 0], [empty.open_count, empty.total_count]
    assert_equal [0, 0, 0, 0], empty.closed_by_week
  end

  test "only what the viewer may see is counted" do
    private_project = Project.generate!(name: "Metrics private", is_public: false, tracker_ids: [1, 2])
    issue(private_project)
    issue(@alone)
    issue(@alone, is_private: true, author_id: 1)
    outsider = User.find(2) # jsmith is a member of fixture projects only
    assert_equal 1, metrics(user: outsider).own_figures_of(@alone.id).open_count, "the private issue is hidden"
    assert_equal 2, metrics.own_figures_of(@alone.id).open_count
    assert_equal 0, metrics(user: outsider).own_figures_of(private_project.id).open_count
    refute_includes metrics(user: outsider).project_rows.keys, private_project.id
    assert_includes metrics.project_rows.keys, private_project.id
  end

  test "an archived project contributes nothing" do
    issue(@alone)
    @alone.update_column(:status, Project::STATUS_ARCHIVED)
    assert_equal 0, metrics.own_figures_of(@alone.id).open_count
  end

  test "quiet projects are those with no activity for thirty days or none, the longest quiet first" do
    metrics = metrics()
    times = { @parent.id => 5.days.ago, @child.id => 40.days.ago, @alone.id => nil }
    metrics.define_singleton_method(:last_activity_times) { times.compact }
    assert_equal [@alone.id, @child.id], metrics.quiet_project_ids([@parent.id, @child.id, @alone.id])
  end

  test "the number of queries does not depend on the number of projects" do
    counts = [3, 3, 30].map do |project_count| # the first run only warms Redmine's own caches
      Issue.delete_all
      projects = Array.new(project_count) { |index| Project.generate!(name: "Many #{project_count} #{index}", is_public: true, tracker_ids: [1]) }
      projects.each { |project| 2.times { issue(project, due_date: @today - 1) } }
      queries = 0
      counter = ->(_name, _start, _finish, _id, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        fresh = metrics
        projects.each { |project| fresh.figures_for(project) }
        fresh.last_activity_times
      end
      queries
    end
    assert_equal counts[1], counts[2]
  end
end
