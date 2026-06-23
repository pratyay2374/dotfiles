-- workspace_item.lua — Factory for creating a single workspace's UI components.
-- Each workspace consists of: a number label, N app-icon slots, a bracket, and padding.
local colors = require("colors")
local settings = require("settings")
local bundle_resolver = require("items.spaces.bundle_resolver")

local M = {}

-- ---------------------------------------------------------------------------
-- Private helpers
-- ---------------------------------------------------------------------------

--- Create the workspace number label item.
-- @param workspace string   Workspace name/number
-- @param is_selected boolean  Whether this workspace is currently focused
-- @return userdata  The sketchybar item
local function create_number_item(workspace, is_selected)
    local ws_prefix = "ws." .. workspace

    local item = sbar.add("item", ws_prefix .. ".num", {
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
            highlight = is_selected
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

    -- Click → switch to this workspace
    item:subscribe("mouse.clicked", function()
        sbar.exec("aerospace workspace " .. workspace)
    end)

    -- Highlight on workspace focus change
    item:subscribe("aerospace_workspace_change", function(env)
        local is_focused = env.FOCUSED_WORKSPACE == workspace
        item:set({ icon = { highlight = is_focused } })
    end)

    return item
end

--- Attach hover (mouse.entered / mouse.exited) handlers to an app icon slot.
-- @param app_item userdata  The sketchybar item
-- @param ws_data table      Workspace data table
-- @param app_idx number     1-based slot index
local function attach_hover_handlers(app_item, ws_data, app_idx)
    local is_hovered = false

    app_item:subscribe("mouse.entered", function()
        if not ws_data.app_names[app_idx] then return end
        if is_hovered then return end
        is_hovered = true
        -- Defer :set() to avoid deadlock: sketchybar sends mouse event via
        -- Mach IPC and blocks; if the callback calls :set() synchronously it
        -- sends a Mach message back → both sides wait forever.
        sbar.delay(0, function()
            local window_id = ws_data.window_ids[app_idx]
            local is_focused = (window_id == ws_data.get_focused_window_id())
            if not is_focused and is_hovered then
                app_item:set({
                    background = { color = colors.with_alpha(colors.solid_white, 0.5) }
                })
            end
        end)
    end)

    app_item:subscribe("mouse.exited", function()
        if not ws_data.app_names[app_idx] then return end
        if not is_hovered then return end
        is_hovered = false
        -- Defer :set() to avoid the same Mach IPC deadlock as mouse.entered.
        sbar.delay(0, function()
            if is_hovered then return end
            local window_id = ws_data.window_ids[app_idx]
            local is_focused = (window_id == ws_data.get_focused_window_id())
            if not is_focused then
                app_item:set({
                    background = { color = colors.transparent }
                })
            end
        end)
    end)
end

--- Create a single app-icon slot (hidden by default).
-- @param workspace string   Workspace name
-- @param app_idx number     1-based slot index
-- @param ws_data table      Workspace data table (for click/hover closures)
-- @param on_refresh function  Callback to trigger a full refresh after focus
-- @return userdata  The sketchybar item
local function create_app_slot(workspace, app_idx, ws_data, on_refresh)
    local ws_prefix = "ws." .. workspace

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
            color = settings.app.background.color,
            border_width = 0,
            corner_radius = 7,
            image = {
                scale = 0.66,
                padding_left = 1,
                padding_right = 1,
                border_width = 0,
            }
        }
    })

    -- Click → focus the specific window
    app_item:subscribe("mouse.clicked", function()
        local window_id = ws_data.window_ids[app_idx]
        if window_id then
            sbar.exec("aerospace focus --window-id " .. window_id, function()
                ws_data.set_focused_window_id(window_id)
                on_refresh()
            end)
        end
    end)

    attach_hover_handlers(app_item, ws_data, app_idx)

    return app_item
end

--- Create the bracket that groups the workspace number + app icons.
-- @param workspace string    Workspace name
-- @param bracket_items table  List of item names to group
-- @param is_selected boolean
-- @return userdata  The sketchybar bracket item
local function create_bracket(workspace, bracket_items, is_selected)
    local ws_prefix = "ws." .. workspace

    local bracket = sbar.add("bracket", ws_prefix .. ".bracket", bracket_items, {
        background = {
            color = is_selected and settings.background.highlight_color or settings.background.default_color,
            height = settings.items.height,
            corner_radius = settings.items.corner_radius,
            border_width = 0
        }
    })

    -- Update bracket highlight on workspace focus change
    bracket:subscribe("aerospace_workspace_change", function(env)
        local is_focused = env.FOCUSED_WORKSPACE == workspace
        bracket:set({
            background = {
                color = is_focused and settings.background.highlight_color or settings.background.default_color
            }
        })
    end)

    return bracket
end

--- Create the inter-workspace padding item.
-- @param workspace string
-- @return userdata
local function create_padding(workspace)
    return sbar.add("item", "ws." .. workspace .. ".padding", {
        width = 5,
        background = { drawing = false }
    })
end

-- ---------------------------------------------------------------------------
-- App update logic
-- ---------------------------------------------------------------------------

--- Sort apps by name then window-id for stable, deterministic ordering.
-- @param apps table  Array of {["app-name"], ["window-id"]} tables
local function sort_apps(apps)
    table.sort(apps, function(a, b)
        local name_a = a["app-name"] or ""
        local name_b = b["app-name"] or ""
        if name_a ~= name_b then
            return name_a < name_b
        end
        return (a["window-id"] or 0) < (b["window-id"] or 0)
    end)
end

--- Apply a resolved bundle ID icon to an app slot.
-- @param app_item userdata
-- @param bid string  Bundle identifier
-- @param is_focused boolean
local function apply_icon(app_item, bid, is_focused)
    app_item:set({
        drawing = true,
        background = {
            image = "app." .. bid,
            color = is_focused and colors.with_alpha(colors.solid_white, 0.5) or colors.transparent
        }
    })
end

--- Update the app icons for a single workspace.
-- Called by the workspace manager whenever windows change.
-- @param ws_data table          Workspace data table
-- @param apps table             Array of window entries from aerospace
-- @param focused_window_id number|nil  Currently focused window ID
-- @param is_focused_workspace boolean  Whether this workspace is focused
-- @param max_apps number        Maximum app icon slots
function M.update_apps(ws_data, apps, focused_window_id, is_focused_workspace, max_apps)
    sort_apps(apps)

    local app_count = #apps

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

    for idx = 1, max_apps do
        local app_item = ws_data.app_items[idx]

        if idx <= app_count then
            local app = apps[idx]
            local app_name = app["app-name"]
            local window_id = app["window-id"]

            -- Store app name and window ID for click/hover handlers
            ws_data.app_names[idx] = app_name
            ws_data.window_ids[idx] = window_id

            -- Track last active window for optimistic UI
            local is_focused = (window_id == focused_window_id)
            if is_focused then
                ws_data.active_window_id = window_id
            end

            -- Resolve bundle ID and set icon
            local cached_bid = bundle_resolver.get_cached(app_name)
            if cached_bid then
                apply_icon(app_item, cached_bid, is_focused)
            else
                -- Show item immediately with cleared icon (prevent stale icon)
                app_item:set({
                    drawing = true,
                    background = {
                        image = "",
                        color = is_focused and colors.with_alpha(colors.solid_white, 0.5) or
                            settings.app.background.color
                    }
                })

                bundle_resolver.resolve(app_name, function(bid)
                    apply_icon(app_item, bid, is_focused)
                end)
            end
        else
            -- Hide unused slots
            ws_data.app_names[idx] = nil
            app_item:set({ drawing = false })
        end
    end
end

-- ---------------------------------------------------------------------------
-- Public factory
-- ---------------------------------------------------------------------------

--- Create all UI items for a single workspace.
-- @param workspace string       Workspace name/number
-- @param is_selected boolean    Whether currently focused
-- @param opts table             { max_apps, on_refresh, get_focused_window_id, set_focused_window_id }
-- @return table  ws_data with all item references and state
function M.create(workspace, is_selected, opts)
    local ws_data = {
        app_items = {},
        app_names = {},
        window_ids = {},
        bracket_items = {},
        active_window_id = nil,
        -- Accessor callbacks so hover/click handlers can read/write manager state
        get_focused_window_id = opts.get_focused_window_id,
        set_focused_window_id = opts.set_focused_window_id,
    }

    -- 1. Workspace number label
    ws_data.number_item = create_number_item(workspace, is_selected)
    table.insert(ws_data.bracket_items, ws_data.number_item.name)

    -- 2. Pre-create app icon slots (hidden by default)
    for i = 1, opts.max_apps do
        local app_item = create_app_slot(workspace, i, ws_data, opts.on_refresh)
        ws_data.app_items[i] = app_item
        ws_data.app_names[i] = nil
        table.insert(ws_data.bracket_items, app_item.name)
    end

    -- 3. Bracket grouping workspace number + app icons
    ws_data.bracket = create_bracket(workspace, ws_data.bracket_items, is_selected)

    -- 4. Inter-workspace padding
    ws_data.padding = create_padding(workspace)

    return ws_data
end

return M
