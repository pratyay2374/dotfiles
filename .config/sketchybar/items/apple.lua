local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

-- Register custom events for aerospace service mode
sbar.add("event", "aerospace_enter_service_mode")
sbar.add("event", "aerospace_leave_service_mode")

local apple = sbar.add("item", {
    icon = {
        font = {
            size = 26.0
        },
        string = settings.modes.main.icon,
        width = 32,
        align = "center",
        padding_right = 8,
        padding_left = 8,
        y_offset = 3
    },
    label = {
        drawing = false
    },
    background = {
        color = settings.items.colors.background,
        border_color = settings.modes.main.color,
        border_width = 1
    },

    padding_left = 1,
    padding_right = 1,
    click_script = "$CONFIG_DIR/helpers/menus/bin/menus -s 0"
})

apple:subscribe("aerospace_enter_service_mode", function(_)
    sbar.animate("tanh", 10, function()
        apple:set({
            icon = {
                string = settings.modes.service.icon
            },
            background = {
                color = colors.with_alpha(settings.modes.service.color, 0.2),                                                                                            
                border_color = settings.modes.service.color
            }
        })
    end)
end)

apple:subscribe("aerospace_leave_service_mode", function(_)
    sbar.animate("tanh", 10, function()
        apple:set({
            icon = {
                string = settings.modes.main.icon
            },
            background = {
                color = settings.items.colors.background,
                border_color = settings.modes.main.color
            }
        })
    end)
end)

-- Padding to the right of the main button
sbar.add("item", {
    width = 4
})
