local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
-- Cache for app bundle IDs (app name -> bundle ID)
local bundle_id_cache = {}

-- Validate a bundle ID looks real (must contain a dot, no spaces)
local function is_valid_bid(s)
    return s and s ~= "" and s ~= "(null)" and s:find("%.") ~= nil and s:find("%s") == nil
end

-- Resolve bundle ID with fallback: osascript first, then lsappinfo
local function resolve_bundle_id(name, callback)
    sbar.exec('osascript -e \'id of app "' .. name .. '"\' 2>/dev/null', function(result)
        local bid = result:gsub("%s+$", "")
        if is_valid_bid(bid) then
            callback(bid)
        else
            sbar.exec('lsappinfo info -only bundleid "' .. name .. '" | cut -d\'"\' -f4',
                function(result2)
                    local bid2 = result2:gsub("%s+$", "")
                    if is_valid_bid(bid2) then
                        callback(bid2)
                    else
                        print("[WARN] Could not resolve bundle ID for: " .. name)
                    end
                end)
        end
    end)
end

-- Register custom events for window changes
sbar.add("event", "space_windows_change")
sbar.add("event", "aerospace_workspace_change")
sbar.add("event", "window_focus_changed")

-- Maximum number of app icons per workspace
local MAX_APPS_PER_WORKSPACE = 8

-- Storage for all workspace data
local workspace_data = {}
local focused_window_id = nil -- Track the currently focused window ID
local focused_workspace = nil -- Track the currently focused workspace

local workspaces = get_workspaces()
local current_workspace = get_current_workspace()
focused_workspace = current_workspace



-- Forward declarations (defined later, but needed by click handlers)
local refresh_workspace_icons

-- Create items for each workspace
for i, workspace in ipairs(workspaces) do
    local selected = workspace == current_workspace
    local ws_prefix = "ws." .. workspace

    -- Store workspace data
    workspace_data[workspace] = {
        app_items = {},
        app_names = {},  -- Track which app each slot holds
        window_ids = {}, -- Track window IDs
        bracket_items = {},
        active_window_id = nil -- Track last active window for immediate highlight
    }

    -- Workspace number item
    local ws_number = sbar.add("item", ws_prefix .. ".num", {
        icon = {
            font = {
                family = settings.font.numbers,
                style = settings.font.style_map["Black"]
            },
            string = workspace,
            padding_left = 5,
            padding_right = 5,
            color = settings.items.default_color,
            highlight_color = settings.items.highlight_color,
            highlight = selected
        },
        label = {
            drawing = false
        },
        padding_right = 10,
        padding_left = 8,
        background = {
            drawing = false
        }
    })

    workspace_data[workspace].number_item = ws_number
    table.insert(workspace_data[workspace].bracket_items, ws_number.name)

    -- Subscribe workspace number to click (switch workspace)
    ws_number:subscribe("mouse.clicked", function(env)
        sbar.exec("aerospace workspace " .. workspace)
    end)

    -- Subscribe to workspace change for highlighting
    ws_number:subscribe("aerospace_workspace_change", function(env)
        local is_selected = env.FOCUSED_WORKSPACE == workspace
        -- sbar.animate("tanh", 20, function()
            ws_number:set({
                icon = {
                    highlight = is_selected
                }
            })
        -- end)
    end)

    -- Pre-create app icon items (hidden by default)
    for app_idx = 1, MAX_APPS_PER_WORKSPACE do
        local app_item = sbar.add("item", ws_prefix .. ".app." .. app_idx, {
            drawing = false,
            icon = {
                drawing = false,
                align = "center"
            },
            label = {
                drawing = false,
                align = "center"
            },
            padding_left = -6,
            padding_right = 8,
            background = {
                drawing = true,
                height = 24,
                -- height = 22, 
                color = settings.app.background.color,
                border_width = 0,
                corner_radius = 7,
                image = {
                    scale = 0.66,
                    -- scale = 0.60,
                    padding_left = 1,
                    padding_right = 1,
                    border_width = 0,
                }
            }
        })

        workspace_data[workspace].app_items[app_idx] = app_item
        workspace_data[workspace].app_names[app_idx] = nil
        table.insert(workspace_data[workspace].bracket_items, app_item.name)

        -- Subscribe to click - focus the specific window
        app_item:subscribe("mouse.clicked", function(env)
            local window_id = workspace_data[workspace].window_ids[app_idx]
            if window_id then
                sbar.exec("aerospace focus --window-id " .. window_id, function()
                    focused_window_id = window_id
                    refresh_workspace_icons()
                end)
            end
        end)

        -- Hover state tracking to prevent re-render feedback loops
        local is_hovered = false

        app_item:subscribe("mouse.entered", function(env)
            if not workspace_data[workspace].app_names[app_idx] then return end
            if is_hovered then return end
            is_hovered = true
            local window_id = workspace_data[workspace].window_ids[app_idx]
            local is_focused = (window_id == focused_window_id)
            if not is_focused then
                app_item:set({
                    background = { color = colors.with_alpha(colors.solid_white, 0.5) }
                })
            end
        end)

        app_item:subscribe("mouse.exited", function(env)
            if not workspace_data[workspace].app_names[app_idx] then return end
            if not is_hovered then return end
            is_hovered = false
            local window_id = workspace_data[workspace].window_ids[app_idx]
            local is_focused = (window_id == focused_window_id)
            if not is_focused then
                app_item:set({
                    background = { color = colors.transparent }
                })
            end
        end)

        -- app_item:subscribe("window_focus_changed", function(env)
        --     local window_id = workspace_data[workspace].window_ids[app_idx]
        --     local is_focused = (window_id == focused_window_id)
        --     sbar.animate("tanh", 5, function()
        --         app_item:set({
        --             background = {
        --                 color = is_focused and colors.with_alpha(colors.solid_white, 0.4) or colors.transparent
        --             }
        --         })
        --     end)
        -- end)
    end

    -- Bracket to group workspace number and app icons
    local bracket = sbar.add("bracket", ws_prefix .. ".bracket", workspace_data[workspace].bracket_items, {
        background = {
            color = selected and settings.background.highlight_color or settings.background.default_color,
            height = settings.items.height,
            corner_radius = settings.items.corner_radius,
            border_width = 0
        }
    })

    workspace_data[workspace].bracket = bracket

    -- Update bracket background on workspace change
    bracket:subscribe("aerospace_workspace_change", function(env)
        local is_selected = env.FOCUSED_WORKSPACE == workspace
        -- sbar.animate("tanh", 5, function()
        bracket:set({
            background = {
                color = is_selected and settings.background.highlight_color or settings.background.default_color
            }
        })
        -- end)
    end)

    -- Padding between workspaces
    local padding = sbar.add("item", ws_prefix .. ".padding", {
        width = 5,
        background = { drawing = false }
    })
    workspace_data[workspace].padding = padding
end






-- Function to update app icons for a single workspace
local function update_workspace_apps(workspace, apps)
    local ws_data = workspace_data[workspace]
    if not ws_data then return end

    -- Sort by app-name first (groups same-app windows together), then by
    -- window-id as tiebreaker for a stable, deterministic order.
    table.sort(apps, function(a, b)
        local name_a = a["app-name"] or ""
        local name_b = b["app-name"] or ""
        if name_a ~= name_b then
            return name_a < name_b
        end
        return (a["window-id"] or 0) < (b["window-id"] or 0)
    end)

    local app_count = #apps
    local is_focused_workspace = (workspace == focused_workspace)

    -- Show workspace if it has apps OR is the focused workspace
    local should_show = (app_count > 0) or is_focused_workspace

    -- Update visibility of workspace number and bracket
    ws_data.number_item:set({ drawing = should_show })
    ws_data.bracket:set({
        drawing = should_show,
        background = {
            drawing = should_show,
            color = is_focused_workspace and settings.background.highlight_color or settings.background.default_color
        }
    })
    ws_data.padding:set({ drawing = should_show })

    for idx = 1, MAX_APPS_PER_WORKSPACE do
        local app_item = ws_data.app_items[idx]

        if idx <= app_count then
            local app = apps[idx]
            local app_name = app["app-name"]
            local window_id = app["window-id"]

            -- Store app name and window ID for click handler
            ws_data.app_names[idx] = app_name
            ws_data.window_ids[idx] = window_id

            -- Check if this specific window is focused
            local is_focused = (window_id == focused_window_id)
            if is_focused then
                ws_data.active_window_id = window_id
            end

            -- Function to apply the icon once we have the bundle ID
            local function apply_icon(bid)
                app_item:set({
                    drawing = true,
                    background = {
                        image = "app." .. bid,
                        color = is_focused and colors.with_alpha(colors.solid_white, 0.5) or colors.transparent
                    }
                })
            end

            -- Resolve bundle ID (cached) and set actual app icon
            local cached_bid = bundle_id_cache[app_name]
            if cached_bid then
                apply_icon(cached_bid)
            else
                -- Show item immediately with cleared icon (prevent stale icon from previous app)
                app_item:set({
                    drawing = true,
                    background = {
                        image = "",
                        color = is_focused and colors.with_alpha(colors.solid_white, 0.5) or
                            settings.app.background.color
                    }
                })

                resolve_bundle_id(app_name, function(bid)
                    bundle_id_cache[app_name] = bid
                    apply_icon(bid)
                end)
            end
        else
            -- Hide unused slots
            ws_data.app_names[idx] = nil
            app_item:set({
                drawing = false
            })
        end
    end
end

-- Debounce: coalesce rapid refresh calls into a single delayed refresh
local refresh_pending = false

-- Shared function to refresh app icons on all workspaces (debounced)
refresh_workspace_icons = function()
    if refresh_pending then return end
    refresh_pending = true
    sbar.delay(0.05, function()
        refresh_pending = false
        for i, workspace in ipairs(workspaces) do
            sbar.exec(
                "aerospace list-windows --workspace " .. workspace .. " --format '%{window-id} %{app-name}' --json ",
                function(apps)
                    update_workspace_apps(workspace, apps)
                end)
        end
    end)
end

-- Helper: fetch the focused window ID and refresh all workspace icons
local function update_focused_and_refresh()
    sbar.exec("aerospace list-windows --focused --format '%{window-id}'", function(result)
        local id_str = result:gsub("%s+$", "")
        focused_window_id = tonumber(id_str)
        refresh_workspace_icons()
    end)
end

-- Get initial focused window and load icons
update_focused_and_refresh()

-- Event observer
local space_window_observer = sbar.add("item", {
    drawing = false,
    updates = true
})

-- Event handles
space_window_observer:subscribe("space_windows_change", function()
    refresh_workspace_icons()
end)

-- Window focus changed (including between windows of same app)
space_window_observer:subscribe("window_focus_changed", function()
    update_focused_and_refresh()
end)

-- Update focused workspace when workspace changes
space_window_observer:subscribe("aerospace_workspace_change", function(env)
    local old_workspace = focused_workspace
    focused_workspace = env.FOCUSED_WORKSPACE

    -- Immediately clear highlights on old workspace apps
    if old_workspace and workspace_data[old_workspace] then
        for idx = 1, MAX_APPS_PER_WORKSPACE do
            local app_item = workspace_data[old_workspace].app_items[idx]
            if workspace_data[old_workspace].app_names[idx] then
                app_item:set({
                    background = { color = colors.transparent }
                })
            end
        end
    end

    -- Immediately highlight active window on new workspace (Optimistic UI)
    local ws_data = workspace_data[focused_workspace]
    if ws_data and ws_data.active_window_id then
        for idx = 1, MAX_APPS_PER_WORKSPACE do
            if ws_data.window_ids[idx] == ws_data.active_window_id then
                ws_data.app_items[idx]:set({
                    background = { color = colors.with_alpha(colors.solid_white, 0.5) }
                })
            end
        end
    end

    -- Then do the full async refresh for accuracy
    update_focused_and_refresh()
end)

-- front_app_switched: single refresh with debouncing handles the timing
space_window_observer:subscribe("front_app_switched", function()
    update_focused_and_refresh()
end)







-- Handles the small icon indicator for spaces / menus changes
local spaces_indicator = sbar.add("item", {
    padding_left = -3,
    padding_right = 0,
    icon = {
        width = 26,
        padding_left = 8,
        padding_right = 9,
        color = colors.grey,
        string = icons.switch.on
    },
    label = {
        width = 0,
        padding_left = 0,
        padding_right = 8,
        string = "Spaces"
    },
    background = {
        color = colors.with_alpha(settings.items.colors.background, 0.0),
        border_width = 0
    }
})

spaces_indicator:subscribe("swap_menus_and_spaces", function(env)
    local query = spaces_indicator:query()
    if not query or not query.icon then return end
    local currently_on = query.icon.value == icons.switch.on
    spaces_indicator:set({
        icon = currently_on and icons.switch.off or icons.switch.on
    })
end)

-- NOTE: mouse.entered/exited hover effects removed (same re-render feedback loop issue)

spaces_indicator:subscribe("mouse.clicked", function(env)
    sbar.trigger("swap_menus_and_spaces")
end)
