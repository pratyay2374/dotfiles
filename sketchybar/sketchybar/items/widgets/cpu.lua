local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

-- Execute the event provider binary which provides the event "cpu_update" for
-- the cpu load data, which is fired every 2.0 seconds.
sbar.exec("killall cpu_load >/dev/null; $CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0")

local cpu = sbar.add("graph", "widgets.cpu", 42, {
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
        string = icons.cpu,
        font = {
            size = 17.0
        },
        padding_right = 6, -- 8
    },
    label = {
        string = "cpu ??%",
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Heavy"],
            size = 9.0
        },
        align = "right",
        padding_right = 3,
        width = 5,
        y_offset = 6
    },
    padding_right = settings.paddings + 6
})

cpu:subscribe("cpu_update", function(env)
    -- Also available: env.user_load, env.sys_load
    local load = tonumber(env.total_load)
    cpu:push({load / 100.})

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

    cpu:set({
        graph = {
            color = color
        },
        label = "CPU  " .. env.total_load .. "%"
    })
end)

cpu:subscribe("mouse.clicked", function(env)
    sbar.exec("open -a 'Activity Monitor'")
end)

-- Background around the cpu item
sbar.add("bracket", "widgets.cpu.bracket", {cpu.name}, {
    background = {
        color = colors.background.normal,
        border_color = colors.rainbow[#colors.rainbow - 5],
        border_width = 0
    }
})

-- Background around the cpu item
sbar.add("item", "widgets.cpu.padding", {
    position = "right",
    width = settings.group_paddings
})
