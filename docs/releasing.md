# Releasing

Push a `vX.Y.Z` tag whose version matches `version` in `init.rb` and that has an entry in `CHANGELOG.md`. The release
workflow runs the tests on every supported Redmine and Ruby, builds `redmine_rubylode_projects-X.Y.Z.zip` (with a checksum
file) and publishes the GitHub release with that changelog entry as its notes. To build a release for a tag that already
exists, open Actions, choose release, Run workflow, and enter the tag.

The text for the www.redmine.org listing, and how to read the result of Check for updates, is in [docs/redmine-org-listing.md](docs/redmine-org-listing.md).
