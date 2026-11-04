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
  # Prepended to Redmine's SettingsController. Redmine saves a plugin's settings without looking at them, so this checks
  # ours first: a bad value shows the form again with the problems and the typed values, and nothing is saved.
  module SettingsControllerPatch
    def plugin
      return super unless request.post? && params[:id].to_s == RubylodeProjects::Settings::PLUGIN_ID.to_s

      submitted = params[:settings] ? params[:settings].permit!.to_h : {}
      errors = RubylodeProjects::Settings.errors_for(submitted)
      return super if errors.empty?

      @plugin = Redmine::Plugin.find(params[:id])
      @partial = @plugin.settings[:partial]
      @settings = submitted
      flash.now[:error] = errors.join(" ")
      render "settings/plugin", status: :unprocessable_entity
    end
  end
end
