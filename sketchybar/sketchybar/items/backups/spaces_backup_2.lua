local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

-- Register custom events for window changes
sbar.add("event", "space_windows_change")
sbar.add("event", "aerospace_workspace_change")
sbar.add("event", "window_focus_changed")

-- Maximum number of app icons per workspace
local MAX_APPS_PER_WORKSPACE = 8

-- Storage for all workspace data
local workspace_data = {}
local focused_app = nil  -- Track the currently focused app
local focused_window_id = nil  -- Track the currently focused window ID
local focused_workspace = nil  -- Track the currently focused workspace

local workspaces = get_workspaces()
local current_workspace = get_current_workspace()
focused_workspace = current_workspace

-- Helper function to split strings
local function split(str, sep)
    local result = {}
    local regex = ("([^%s]+)"):format(sep)
    for each in str:gmatch(regex) do
        table.insert(result, each)
    end
    return result
end

-- Create items for each workspace
for i, workspace in ipairs(workspaces) do
    local selected = workspace == current_workspace
    local ws_prefix = "ws." .. workspace

    -- Store workspace data
    workspace_data[workspace] = {
        app_items = {},
        app_names = {},  -- Track which app each slot holds
        window_ids = {},  -- Track window IDs
        bracket_items = {}
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
            color = settings.items.default_color(),
            highlight_color = settings.items.highlight_color(),
            highlight = selected
        },
        label = {
            drawing = false
        },
        padding_right = 12,
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
        ws_number:set({
            icon = {
                highlight = is_selected
            }
        })
    end)

    -- Pre-create app icon items (hidden by default)
    for app_idx = 1, MAX_APPS_PER_WORKSPACE do
        local app_item = sbar.add("item", ws_prefix .. ".app." .. app_idx, {
            drawing = false,
            icon = {
                drawing = false
            },
            label = {
                font = settings.icons,
                padding_left = 5,
                padding_right = 5,
                color = settings.items.default_color(),
                highlight_color = settings.items.highlight_color(),
            },
            padding_left = -4,
            padding_right = 8,
            background = {
                drawing = true,
                height = 25,
                color = settings.app.background.color,
                border_width = 0,
                corner_radius = 7
            }
        })

        workspace_data[workspace].app_items[app_idx] = app_item
        workspace_data[workspace].app_names[app_idx] = nil
        table.insert(workspace_data[workspace].bracket_items, app_item.name)

        -- Subscribe to click - focus the specific window
        app_item:subscribe("mouse.clicked", function(env)
            local window_id = workspace_data[workspace].window_ids[app_idx]
            if window_id then
                -- Focus the specific window by ID
                sbar.exec("aerospace focus --window-id " .. window_id)
            end
        end)
    end

    -- Bracket to group workspace number and app icons
    local bracket = sbar.add("bracket", ws_prefix .. ".bracket", workspace_data[workspace].bracket_items, {
        background = {
            color = selected and settings.background.highlight_color() or settings.background.default_color(),
            height = settings.items.height,
            corner_radius = settings.items.corner_radius,
            border_width = 0,
        }
    })

    workspace_data[workspace].bracket = bracket

    -- Update bracket background on workspace change
    bracket:subscribe("aerospace_workspace_change", function(env)
        local is_selected = env.FOCUSED_WORKSPACE == workspace
        bracket:set({
            background = {
                color = is_selected and settings.background.highlight_color() or settings.background.default_color()
            }
        })
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

    local app_count = #apps
    local is_focused_workspace = (workspace == focused_workspace)
    
    -- Show workspace if it has apps OR is the focused workspace
    local should_show = (app_count > 0) or is_focused_workspace
    
    -- Update visibility of workspace number and bracket
    ws_data.number_item:set({ drawing = should_show })
    ws_data.bracket:set({ 
        drawing = should_show,
        background = { drawing = should_show } })
    ws_data.padding:set({ drawing = should_show })

    for idx = 1, MAX_APPS_PER_WORKSPACE do
        local app_item = ws_data.app_items[idx]

        if idx <= app_count then
            local app = apps[idx]
            local app_name = app["app-name"]
            local window_id = app["window-id"]
            local lookup = app_icons[app_name]
            local icon = ((lookup == nil) and app_icons["default"] or lookup)

            -- Store app name and window ID for click handler
            ws_data.app_names[idx] = app_name
            ws_data.window_ids[idx] = window_id

            -- Check if this specific window is focused
            local is_focused = (window_id == focused_window_id)

            -- Show and configure the item
            app_item:set({
                drawing = true,
                label = {
                    string = icon,
                    color = is_focused and colors.black or settings.items.default_color()
                },
                background = {
                    drawing = is_focused
                }
            })
        else
            -- Hide unused slots
            ws_data.app_names[idx] = nil
            app_item:set({
                drawing = false
            })
        end
    end
end

-- Shared function to refresh app icons on all workspaces
local function refresh_workspace_icons()
    for i, workspace in ipairs(workspaces) do
        sbar.exec("aerospace list-windows --workspace " .. workspace .. " --format '%{window-id} %{app-name}' --json ", function(apps)
            update_workspace_apps(workspace, apps)
        end)
    end
end

-- Get initial focused window and load icons
sbar.exec("aerospace list-windows --focused --format '%{window-id}'", function(result)
    local id_str = result:gsub("%s+$", "")
    focused_window_id = tonumber(id_str)
    refresh_workspace_icons()
end)

-- Event observer
local space_window_observer = sbar.add("item", {
    drawing = false,
    updates = true
})

-- Event handles
space_window_observer:subscribe("space_windows_change", refresh_workspace_icons)

-- Window focus changed (including between windows of same app)
space_window_observer:subscribe("window_focus_changed", function()
    sbar.exec("aerospace list-windows --focused --format '%{window-id}'", function(result)
        local id_str = result:gsub("%s+$", "")
        focused_window_id = tonumber(id_str)
        refresh_workspace_icons()
    end)
end)

-- Update focused workspace when workspace changes
space_window_observer:subscribe("aerospace_workspace_change", function(env)
    focused_workspace = env.FOCUSED_WORKSPACE
    refresh_workspace_icons()
end)

-- front_app_switched fires before aerospace updates its window list,
-- so we refresh immediately and again after a short delay
space_window_observer:subscribe("front_app_switched", function(env)
    focused_app = env.INFO
    -- Get the focused window ID
    sbar.exec("aerospace list-windows --focused --format '%{window-id}'", function(result)
        local id_str = result:gsub("%s+$", "")
        focused_window_id = tonumber(id_str)
        refresh_workspace_icons()
    end)
    sbar.exec("sleep 0.3", function()
        sbar.exec("aerospace list-windows --focused --format '%{window-id}'", function(result)
            local id_str = result:gsub("%s+$", "")
            focused_window_id = tonumber(id_str)
            refresh_workspace_icons()
        end)
    end)
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
    local currently_on = spaces_indicator:query().icon.value == icons.switch.on
    spaces_indicator:set({
        icon = currently_on and icons.switch.off or icons.switch.on
    })
end)

spaces_indicator:subscribe("mouse.entered", function(env)
    sbar.animate("tanh", 30, function()
        spaces_indicator:set({
            background = {
                color = {
                    alpha = 0.1
                }
            },
            icon = {
                color = colors.white
            },
            label = {
               width = "dynamic"
            }
        })
    end)
end)

spaces_indicator:subscribe("mouse.exited", function(env)
    sbar.animate("tanh", 30, function()
        spaces_indicator:set({
            background = {
                color = {
                    alpha = 0.0
                }
            },
            icon = {
                color = colors.grey
            },
            label = {
                width = 0
            }
        })
    end)
end)

spaces_indicator:subscribe("mouse.clicked", function(env)
    sbar.trigger("swap_menus_and_spaces")
end)
