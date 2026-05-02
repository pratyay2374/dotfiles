local colors = require("colors")
local icons = require("icons")

return {
    paddings = 3,
    group_paddings = 5,
    modes = {
        main = {
            icon = icons.apple,
            color = colors.rainbow[13]
        },
        service = {
            icon = icons.service,
            color = colors.rainbow[1]
        }
    },
    bar = {
        -- height = 32,
        height = 34,
        padding = {
            x_left = 10,
            x_right = 10,
            y = 0,
        },
        background = colors.bar.bg
    },
    items = {
        -- height = 28,
        height = 30,
        gap = 5,
        padding = {
            right = 16,
            left = 12,
            top = 0,
            bottom = 0
        },
        default_color = colors.white,
        highlight_color = colors.with_alpha(colors.white, 0.8),

        -- -- For items that have popups, use the same color for the popup background as the item background
        -- default_color = function(workspace)
        --     return colors.rainbow[workspace + 1]
        -- end,
        -- highlight_color = function(workspace)
        --     return colors.yellow
        -- end,
        colors = {
            background = colors.background.normal
        },
        corner_radius = 8
    },

    -- Workspace background colors
    background = {
        default_color = colors.background.normal,
        highlight_color = colors.background.highlight,
    },



    app = {
        background = {
            color = colors.with_alpha(colors.black, 0.3),
        }
    },

    icons = "sketchybar-app-font:Regular:14.0", -- alternatively available: NerdFont

    font = {
        icon = "FiraCode Nerd Font Mono", -- Used for icons
        text = "SF Pro Display", -- Used for text
        numbers = "SF Pro Display", -- Used for numbers
        style_map = {
            ["Regular"] = "Regular",
            ["Semibold"] = "Medium",
            ["Bold"] = "SemiBold",
            ["Heavy"] = "Bold",
            ["Black"] = "Black"
        }
    }
}
