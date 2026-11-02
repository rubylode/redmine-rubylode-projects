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

# Demo data for the throwaway Redmine in docker-compose.yml: about 40 projects (enough for two pages of the projects
# list), one big project with a few hundred issues over the last 14 weeks, and eight people in three roles.
# Everything is made up. The people are computer scientists of the past, the projects are plain nouns.
#
#   ruby bin/demo seed      (or: docker compose exec redmine bin/rails runner plugins/redmine_rubylode_projects/test/seed.rb)
#
# Safe to run twice: it runs in one transaction and does nothing when the big project is already there.
# The demo people sign in with their login and the password below; the administrator stays admin / admin.

DEMO_PASSWORD = "demo-password-1".freeze
BIG_PROJECT_IDENTIFIER = "orchard".freeze
WEEKS_OF_HISTORY = 14
BIG_PROJECT_ISSUE_COUNT = 360
CLOSED_SHARE = 0.72

Redmine::DefaultData::Loader.load("en") if Tracker.none?

if Project.exists?(identifier: BIG_PROJECT_IDENTIFIER)
  puts "demo data already loaded: #{Project.count} projects, #{Issue.count} issues"
  return
end

random = Random.new(2026)
now = Time.current
pick = ->(list) { list[random.rand(list.size)] }
# Picks from [[value, weight], ...].
weighted = lambda do |pairs|
  roll = random.rand * pairs.sum(&:last)
  pairs.each do |value, weight|
    return value if (roll -= weight) <= 0
  end
  pairs.last.first
end

ActiveRecord::Base.transaction do
  Setting.default_language = "en"
  Setting.notified_events = [] # no mail from the demo
  Setting.welcome_text = "A throwaway Redmine with made-up data, for trying the Rubylode Projects plugin."

  admin = User.find_by!(login: "admin")
  admin.update_columns(must_change_passwd: false)
  User.current = admin

  people = [
    %w[ada.lovelace Ada Lovelace], %w[alan.turing Alan Turing], %w[grace.hopper Grace Hopper],
    %w[edsger.dijkstra Edsger Dijkstra], %w[charles.babbage Charles Babbage], %w[frances.allen Frances Allen],
    %w[john.backus John Backus], %w[dennis.ritchie Dennis Ritchie]
  ].to_h do |login, firstname, lastname|
    user = User.find_or_initialize_by(login: login)
    user.assign_attributes(firstname: firstname, lastname: lastname, mail: "#{login}@example.com", language: "en",
                           must_change_passwd: false)
    user.password = user.password_confirmation = DEMO_PASSWORD
    user.save!
    [login, user]
  end

  manager, developer, reporter = %w[Manager Developer Reporter].map { |name| Role.find_by!(name: name) }
  trackers = Tracker.where(name: %w[Bug Feature Support]).index_by(&:name)
  statuses = IssueStatus.all.index_by(&:name)
  priorities = IssuePriority.all.index_by(&:name)
  modules = %w[issue_tracking time_tracking news documents files wiki gantt calendar]

  make_project = lambda do |name, identifier, description, parent: nil|
    project = Project.new(name: name, identifier: identifier, description: description, is_public: true,
                          enabled_module_names: modules, inherit_members: parent.present?)
    project.parent = parent
    project.trackers = trackers.values
    project.save!
    project
  end
  add_members = lambda do |project, members|
    members.each { |login, role| Member.create!(project: project, principal: people.fetch(login), roles: [role]) }
  end

  # ---- The big project and its subprojects ----

  orchard = make_project.("Orchard", BIG_PROJECT_IDENTIFIER, "The demo's big project: a made-up app with an API, a web client, mobile apps and docs.")
  add_members.(orchard, [["ada.lovelace", manager], ["grace.hopper", manager], ["alan.turing", developer], ["edsger.dijkstra", developer],
                         ["dennis.ritchie", developer], ["john.backus", developer], ["charles.babbage", reporter], ["frances.allen", reporter]])
  orchard_parts = {
    "API" => "The public API and its keys.",
    "Web" => "The browser client.",
    "Mobile" => "The phone apps.",
    "Docs" => "The guides and the reference."
  }.map { |part, description| make_project.("Orchard #{part}", "orchard-#{part.downcase}", description, parent: orchard) }

  # ---- Many small projects, a few with subprojects, so the projects list has more than one page ----

  small_project_names = %w[Atlas Beacon Canyon Cedar Compass Delta Ember Falcon Fjord Glacier Granite Harbor Heron Island
                           Juniper Kestrel Lagoon Lantern Marlin Meadow Mesa Otter Pelican Prairie Quarry Raven Reef Summit
                           Tundra Willow]
  small_projects = small_project_names.map do |name|
    project = make_project.(name, name.downcase, "A small demo project called #{name}.")
    add_members.(project, people.keys.sample(3, random: random).each_with_index.map { |login, index| [login, [manager, developer, reporter][index]] })
    project
  end
  beacon = small_projects.find { |project| project.name == "Beacon" }
  harbor = small_projects.find { |project| project.name == "Harbor" }
  subprojects = [make_project.("Beacon iOS", "beacon-ios", "The iPhone app.", parent: beacon),
                 make_project.("Beacon Android", "beacon-android", "The Android app.", parent: beacon),
                 make_project.("Harbor Staging", "harbor-staging", "The staging copy.", parent: harbor)]

  # ---- Issues ----

  subjects = {
    "Bug" => [["Fix", "Stop", "Correct", "Handle"],
              ["the crash on the settings page", "duplicate rows in the export", "a timeout on large uploads", "the wrong time zone in reports",
               "a broken link in the footer", "the login loop after a password reset", "slow search on long words", "the missing icon on small screens",
               "an empty error message", "the sort order of the list"]],
    "Feature" => [["Add", "Build", "Allow", "Support"],
                  ["a dark mode", "an export to spreadsheet", "two-factor sign-in", "saved filters", "a weekly digest email", "drag and drop ordering",
                   "keyboard shortcuts", "a public status page", "bulk editing", "an audit log"]],
    "Support" => [["Explain", "Document", "Answer", "Help with"],
                  ["how to invite a team", "the import format", "the API rate limits", "moving data between accounts", "the backup schedule",
                   "single sign-on settings", "the billing cycle", "the mobile app setup"]]
  }
  open_statuses = [["New", 55], ["In Progress", 30], ["Feedback", 10], ["Resolved", 5]]
  closed_statuses = [["Closed", 88], ["Rejected", 12]]
  priority_weights = [["Low", 15], ["Normal", 58], ["High", 18], ["Urgent", 7], ["Immediate", 2]]
  tracker_weights = [["Bug", 45], ["Feature", 35], ["Support", 20]]
  assignees = %w[alan.turing edsger.dijkstra dennis.ritchie john.backus grace.hopper]
  authors = people.keys

  make_issue = lambda do |project, created_at, closed_at|
    tracker_name = weighted.(tracker_weights)
    verbs, things = subjects.fetch(tracker_name)
    status_name = closed_at ? weighted.(closed_statuses) : weighted.(open_statuses)
    assignable = project.assignable_users.select { |user| assignees.include?(user.login) }
    assignee = assignable.any? && !(status_name == "New" && random.rand < 0.5) ? pick.(assignable) : nil
    issue = Issue.new(project: project, tracker: trackers.fetch(tracker_name), author: people.fetch(pick.(authors)),
                      subject: "#{pick.(verbs)} #{pick.(things)}", status: statuses.fetch(status_name),
                      priority: priorities.fetch(weighted.(priority_weights)), assigned_to: assignee)
    issue.save!
    # Backdated by id: update_columns on the record Redmine has just saved changes no row.
    Issue.where(id: issue.id).update_all(created_on: created_at, updated_on: closed_at || created_at + random.rand(0..72).hours,
                                         closed_on: closed_at)
  end

  # A time in working hours on a weekday, some days back.
  working_time = lambda do |days_back|
    day = now.to_date - days_back
    day -= 1 while day.saturday? || day.sunday?
    day.in_time_zone.change(hour: random.rand(8..17), min: random.rand(60))
  end

  orchard_projects = [orchard] * 6 + orchard_parts
  BIG_PROJECT_ISSUE_COUNT.times do |index|
    # Steadily more work in recent weeks, with one busy release week five weeks ago.
    days_back = index < 40 ? random.rand(28..34) : (WEEKS_OF_HISTORY * 7 * (1 - Math.sqrt(random.rand))).floor
    created_at = [working_time.(days_back), now - 1.hour].min
    closed_at = nil
    if random.rand < CLOSED_SHARE
      candidate = created_at + random.rand(4..(24 * 21)).hours
      closed_at = candidate if candidate < now
    end
    make_issue.(pick.(orchard_projects), created_at, closed_at)
  end

  (small_projects + subprojects).each do |project|
    random.rand(0..8).times do
      created_at = working_time.(random.rand(1..WEEKS_OF_HISTORY * 7))
      closed_at = random.rand < 0.5 ? [created_at + random.rand(1..15).days, now].min : nil
      make_issue.(project, created_at, closed_at)
    end
  end

  # Due dates on a quarter of the open issues: some already past (overdue), some in the coming week, some later.
  due_offsets = [-14, -9, -5, -2, -1, 1, 2, 3, 5, 6, 10, 20]
  Issue.open.order(:id).each_with_index do |issue, index|
    Issue.where(id: issue.id).update_all(due_date: now.to_date + due_offsets.fetch(random.rand(due_offsets.size))) if index % 4 == 0
  end

  # Some issues closed in the last couple of days, so "closed this week" and the newest week of the charts are not empty.
  Issue.where.not(closed_on: nil).where("created_on < ?", now - 5.days).order(:id).each_with_index do |issue, index|
    Issue.where(id: issue.id).update_all(closed_on: now - random.rand(1..60).hours, updated_on: now - random.rand(1..60).hours) if index % 9 == 0
  end

  # Estimates on some of the big project's issues, and time logged against them, so the time card has numbers.
  activity = TimeEntryActivity.find_by(is_default: true) || TimeEntryActivity.first
  big_project_issues = Issue.where(project_id: [orchard.id] + orchard_parts.map(&:id)).order(:id).to_a
  big_project_issues.each_with_index do |issue, index|
    next unless index % 3 == 0

    Issue.where(id: issue.id).update_all(estimated_hours: [2, 4, 6, 8, 12, 16].fetch(random.rand(6)))
    next if issue.assigned_to.nil? || index % 2 == 1

    TimeEntry.create!(project: issue.project, issue: issue, user: issue.assigned_to, activity: activity,
                      hours: [0.5, 1, 1.5, 2, 3, 4].fetch(random.rand(6)), comments: "Worked on it",
                      spent_on: [issue.created_on.to_date + random.rand(0..6), now.to_date].min)
  end

  puts "demo data loaded: #{Project.count} projects, #{Issue.count} issues, #{User.where(login: people.keys).count} demo people"
end
