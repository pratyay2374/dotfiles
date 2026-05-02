local settings = require("settings")
local colors = require("colors")

sbar.add("item", {
    position = "right",
    width = settings.group_paddings + 0
})

local cal = sbar.add("item", {
    icon = {
        -- color = colors.white,
        -- padding_left = 8,
        -- padding_right = 7,
        -- font = {
        --     size = 16.0
        -- }
        drawing = "false"
    },
    label = {
        color = colors.white,
        padding_right = 8,
        padding_left = 8,
        -- width = 119,     -- 93
        align = "right",
        font = {
            family = settings.font.text,
            style = settings.font.style_map["Bold"],
        }
    },
    position = "right",
    update_freq = 30,
    padding_left = 0,
    padding_right = 0,
    background = {
        color = colors.background.normal,
        border_color = colors.rainbow[#colors.rainbow - 1],
        border_width = 0
    }
})

-- -- Double border for calendar using a single item bracket
-- sbar.add("bracket", { cal.name }, {
--   background = {
--     color = colors.transparent,
--     height = 30,
--     border_color = colors.grey,
--   }
-- })

-- Padding item required because of bracket
sbar.add("item", {
    position = "right",
    width = settings.group_paddings
})

cal:subscribe({"forced", "routine", "system_woke"}, function(env)
    cal:set({
        icon = "􀉉",
        label = os.date("%a  %b  %d,  %I:%M")
    })
end)
