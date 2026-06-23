-- workspace_manager.lua — Global workspace state, debounced refresh, and event orchestration.
-- This is the "brain" that coordinates workspace data, focus tracking,
-- and reacts to aerospace / sketchybar events.
local colors = require("colors")
local settings = require("settings")
local ws_item = require("items.spaces.workspace_item")

local M = {}

-- ---------------------------------------------------------------------------
-- State (initialized by M.init)
-- ---------------------------------------------------------------------------

local workspaces = {}        -- Ordered list of workspace names
local workspace_data = {}    -- workspace name → ws_data table
local max_apps = 8           -- Max app icon slots per workspace

M.focused_window_id = nil    -- Currently focused window ID
M.focused_workspace = nil    -- Currently focused workspace name

-- ---------------------------------------------------------------------------
-- Core refresh logic
-- ---------------------------------------------------------------------------

--- Return false for system daemons that AeroSpace surfaces but have no app icon.
-- These show up as bundle-ID-style names (e.g. "com.apple.LocalAuthentication.UIAgent").
local function is_user_app(app_name)
    if not app_name or app_name == "" then return false end
    if app_name:match("^com%.apple%.") then return false end
    if app_name:match("UIAgent$") or app_name:match("Daemon$") then return false end
    return true
end

--- Update app icons for a single workspace using fresh window data.
-- @param workspace string
-- @param apps table  Array of {["app-name"], ["window-id"]} from aerospace
local function update_workspace(workspace, apps)
    local ws_data = workspace_data[workspace]
    if not ws_data then return end

    local is_focused = (workspace == M.focused_workspace)
    ws_item.update_apps(ws_data, apps, M.focused_window_id, is_focused, max_apps)
end

-- Debounce flag: coalesces rapid refresh calls into a single delayed refresh
local refresh_pending = false

--- Refresh app icons on all workspaces (debounced).
-- Multiple calls within the debounce window are collapsed into one.
function M.refresh()
    if refresh_pending then return end
    refresh_pending = true
    sbar.delay(0.05, function()
        refresh_pending = false
        for _, workspace in ipairs(workspaces) do
            sbar.exec(
                "aerospace list-windows --workspace " .. workspace
                    .. " --format '%{window-id} %{app-name}' --json 2>/dev/null",
                function(apps)
                    local user_apps = {}
                    for _, app in ipairs(apps) do
                        if is_user_app(app["app-name"]) then
                            table.insert(user_apps, app)
                        end
                    end
                    update_workspace(workspace, user_apps)
                end)
        end
    end)
end

--- Fetch the focused window ID from aerospace, then refresh all workspaces.
function M.update_focused_and_refresh()
    sbar.exec("aerospace list-windows --focused --format '%{window-id}' 2>/dev/null", function(result)
        local id_str = result:gsub("%s+$", "")
        M.focused_window_id = tonumber(id_str)
        M.refresh()
    end)
end

-- ---------------------------------------------------------------------------
-- Event observers
-- ---------------------------------------------------------------------------

--- Register all sketchybar event subscriptions.
-- Must be called after M.init().
function M.setup_observers()
    local observer = sbar.add("item", {
        drawing = false,
        updates = true
    })

    -- Windows added/removed on any workspace
    observer:subscribe("space_windows_change", function()
        M.refresh()
    end)

    -- A different window gained focus (including within the same app)
    observer:subscribe("window_focus_changed", function()
        M.update_focused_and_refresh()
    end)

    -- User switched to a different workspace
    observer:subscribe("aerospace_workspace_change", function(env)
        local old_workspace = M.focused_workspace
        M.focused_workspace = env.FOCUSED_WORKSPACE

        -- Immediately clear highlights on the old workspace (optimistic UI)
        if old_workspace and workspace_data[old_workspace] then
            for idx = 1, max_apps do
                local app_item = workspace_data[old_workspace].app_items[idx]
                if workspace_data[old_workspace].app_names[idx] then
                    app_item:set({
                        background = { color = colors.transparent }
                    })
                end
            end
        end

        -- Immediately highlight the last active window on the new workspace
        local ws_data = workspace_data[M.focused_workspace]
        if ws_data and ws_data.active_window_id then
            for idx = 1, max_apps do
                if ws_data.window_ids[idx] == ws_data.active_window_id then
                    ws_data.app_items[idx]:set({
                        background = { color = colors.with_alpha(colors.solid_white, 0.5) }
                    })
                end
            end
        end

        -- Full async refresh for accuracy
        M.update_focused_and_refresh()
    end)

    -- Front app switched (Cmd-Tab, clicking another app, etc.)
    observer:subscribe("front_app_switched", function()
        M.update_focused_and_refresh()
    end)
end

-- ---------------------------------------------------------------------------
-- Initialization
-- ---------------------------------------------------------------------------

--- Initialize the workspace manager.
-- @param ws_list table        Ordered list of workspace names
-- @param ws_data_map table    workspace name → ws_data table (from workspace_item.create)
-- @param current_ws string    Name of the currently focused workspace
-- @param max_apps_count number  Maximum app icon slots per workspace
function M.init(ws_list, ws_data_map, current_ws, max_apps_count)
    workspaces = ws_list
    workspace_data = ws_data_map
    max_apps = max_apps_count
    M.focused_workspace = current_ws
    M.focused_window_id = nil
end

return M
