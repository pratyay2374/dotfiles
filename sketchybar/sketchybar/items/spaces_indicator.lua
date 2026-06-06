-- spaces_indicator.lua — Toggle widget for the spaces/menus indicator.
-- Displays a small switch icon that toggles between spaces and menus views.
local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

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

-- React to swap event: toggle the switch icon
spaces_indicator:subscribe("swap_menus_and_spaces", function()
    local query = spaces_indicator:query()
    if not query or not query.icon then return end
    local currently_on = query.icon.value == icons.switch.on
    spaces_indicator:set({
        icon = currently_on and icons.switch.off or icons.switch.on
    })
end)

-- Click → trigger the swap event
spaces_indicator:subscribe("mouse.clicked", function()
    sbar.trigger("swap_menus_and_spaces")
end)
