local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

-- Launch the mem_load event provider (fires "mem_update" every 2s)
sbar.exec("killall mem_load 2>/dev/null; $CONFIG_DIR/helpers/event_providers/mem_load/bin/mem_load mem_update 2.0")

local mem = sbar.add("graph", "widgets.mem", 45, {
    position = "right",
    graph = {
        color = colors.green
    },
    background = {
        height = 22,
        color = {
            alpha = 0
        },
        border_color = {
            alpha = 0
        },
        drawing = true
    },
    icon = {
        y_offset = 1,
        string = icons.mem,
        font = {
            size = 17.0
        },
        padding_right = 6,   --8
    },
    label = {
        string = "mem ??%",
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Heavy"],
            size = 9.0
        },
        align = "right",
        padding_right = 3,
        width = 5,
        y_offset = 6,
    },
    padding_right = settings.paddings + 6
})

mem:subscribe("mem_update", function(env)
    local load = tonumber(env.pressure)
    -- Push scaled to 0.70 so bars max at ~15px, just under the label (at 16px from bottom)
    mem:push({(load / 100.) * 0.70})

    local color = colors.green
    if load > 30 then
        if load < 60 then
            color = colors.yellow
        elseif load < 80 then
            color = colors.orange
        else
            color = colors.red
        end
    end

    mem:set({
        graph = {
            color = color
        },
        label = "MEM  " .. env.pressure .. "%"
    })
end)

mem:subscribe("mouse.clicked", function(env)
    sbar.exec("open -a 'Activity Monitor'")
end)

-- Background bracket around the mem item
sbar.add("bracket", "widgets.mem.bracket", { mem.name }, {
    background = {
        color = colors.background.normal,
        border_color = colors.rainbow[#colors.rainbow - 6],
        border_width = 0
    }
})

-- Padding item
sbar.add("item", "widgets.mem.padding", {
    position = "right",
    width = settings.group_paddings
})
