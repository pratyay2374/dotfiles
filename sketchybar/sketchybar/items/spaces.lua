-- spaces.lua — Orchestrator for aerospace workspace display in sketchybar.
-- Wires together the workspace item factory, manager, and indicator widget.
local settings = require("settings")
local aerospace = require("items.aerospace")
local ws_item = require("items.spaces.workspace_item")
local manager = require("items.spaces.workspace_manager")

-- Register custom events consumed by workspace items and manager
sbar.add("event", "space_windows_change")
sbar.add("event", "aerospace_workspace_change")
sbar.add("event", "window_focus_changed")

-- Query aerospace for initial state
local workspaces = aerospace.get_workspaces()
local current_workspace = aerospace.get_current_workspace()
local max_apps = settings.app.max_apps_per_workspace

-- Initialize the manager (sets up state before items reference it)
manager.init(workspaces, {}, current_workspace, max_apps)

-- Create UI items for each workspace
local workspace_data = {}
for _, workspace in ipairs(workspaces) do
    workspace_data[workspace] = ws_item.create(workspace, workspace == current_workspace, {
        max_apps = max_apps,
        on_refresh = function() manager.refresh() end,
        get_focused_window_id = function() return manager.focused_window_id end,
        set_focused_window_id = function(id) manager.focused_window_id = id end,
    })
end

-- Re-initialize manager with the populated workspace data map
manager.init(workspaces, workspace_data, current_workspace, max_apps)

-- Wire up event observers and perform initial refresh
manager.setup_observers()
manager.update_focused_and_refresh()

-- Load the spaces indicator widget (independent toggle)
require("items.spaces_indicator")
