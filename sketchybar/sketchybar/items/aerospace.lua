-- aerospace.lua — Aerospace window manager helpers
-- Provides functions to query workspaces, monitors, and visibility state.
local M = {}

--- Pretty-print a Lua value (table or scalar) for debugging.
function M.dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. M.dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

--- Split a string by a delimiter into a table of substrings.
function M.explode(div, str)
    if (div == '') then
        return false
    end
    local pos, arr = 0, {}
    for st, sp in function()
        return string.find(str, div, pos, true)
    end do
        table.insert(arr, string.sub(str, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(str, pos))
    return arr
end

--- Parse a newline-separated string into a table of lines.
function M.parse_string_to_table(s)
    local result = {}
    for line in s:gmatch("([^\n]+)") do
        table.insert(result, line)
    end
    return result
end

--- Return a table of all aerospace workspace names.
function M.get_workspaces()
    local file = io.popen("aerospace list-workspaces --all")
    if not file then
        return {}
    end
    local result = file:read("*a")
    file:close()

    return M.parse_string_to_table(result)
end

--- Return the name of the currently focused workspace.
function M.get_current_workspace()
    local file = io.popen("aerospace list-workspaces --focused")
    if not file then
        return nil
    end
    local result = file:read("*a")
    file:close()

    return M.parse_string_to_table(result)[1]
end

--- Return a table of monitor IDs.
function M.get_monitors()
    local file = io.popen("aerospace list-monitors | awk '{print $1}'")
    if not file then
        return {}
    end
    local result = file:read("*a")
    file:close()

    return M.parse_string_to_table(result)
end

--- Return all workspace names assigned to the given monitor.
function M.get_workspaces_on_monitor(monitor)
    local file = io.popen("aerospace list-workspaces --monitor " .. monitor)
    if not file then
        return {}
    end
    local result = file:read("*a")
    file:close()

    return M.parse_string_to_table(result)
end

--- Return the visible workspace name on the given monitor.
function M.get_visible_workspace_on_monitor(monitor)
    local file = io.popen("aerospace list-workspaces --monitor " .. monitor .. " --visible")
    if not file then
        return nil
    end
    local result = file:read("*a")
    file:close()

    return M.parse_string_to_table(result)[1]
end

--- Check whether a workspace is currently visible on any monitor.
function M.is_workspace_selected(workspace)
    local available_monitors = M.get_monitors()
    for _, monitor in ipairs(available_monitors) do
        local visible_workspace = M.get_visible_workspace_on_monitor(monitor)
        if visible_workspace == workspace then
            return true
        end
    end

    return false
end

return M
