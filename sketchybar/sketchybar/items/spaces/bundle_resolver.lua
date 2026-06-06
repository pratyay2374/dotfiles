-- bundle_resolver.lua — Resolves app names to macOS bundle identifiers.
-- Uses a two-step fallback (osascript → lsappinfo) and caches results
-- for the lifetime of the process to avoid repeated shell calls.
local M = {}

--- Internal cache: app_name → bundle_id
local cache = {}

--- Validate that a string looks like a real bundle ID.
-- Must be non-empty, non-null, contain a dot, and have no spaces.
-- @param s string  Candidate bundle ID
-- @return boolean
local function is_valid_bid(s)
    return s and s ~= "" and s ~= "(null)" and s:find("%.") ~= nil and s:find("%s") == nil
end

--- Resolve an app name to its bundle ID asynchronously.
-- Checks the cache first; on a miss, tries osascript, then lsappinfo.
-- @param app_name string  Display name of the application
-- @param callback function(bid)  Called with the resolved bundle ID
function M.resolve(app_name, callback)
    -- Fast path: cache hit
    local cached = cache[app_name]
    if cached then
        callback(cached)
        return
    end

    -- Slow path: shell out to osascript first
    sbar.exec('osascript -e \'id of app "' .. app_name .. '"\' 2>/dev/null', function(result)
        local bid = result:gsub("%s+$", "")
        if is_valid_bid(bid) then
            cache[app_name] = bid
            callback(bid)
        else
            -- Fallback: lsappinfo
            sbar.exec('lsappinfo info -only bundleid "' .. app_name .. '" | cut -d\'"\'  -f4',
                function(result2)
                    local bid2 = result2:gsub("%s+$", "")
                    if is_valid_bid(bid2) then
                        cache[app_name] = bid2
                        callback(bid2)
                    else
                        print("[WARN] Could not resolve bundle ID for: " .. app_name)
                    end
                end)
        end
    end)
end

--- Return the cached bundle ID for an app, or nil if not yet resolved.
-- @param app_name string
-- @return string|nil
function M.get_cached(app_name)
    return cache[app_name]
end

return M
