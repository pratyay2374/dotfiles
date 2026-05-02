local settings = require("settings")

-- Equivalent to the --bar domain
sbar.bar({
    topmost = "window",
    height = settings.bar.height,
    color = settings.bar.background,
    blur_radius = 3,
    padding_right = settings.bar.padding.x_right,
    padding_left = settings.bar.padding.x_left,
    -- padding_top = settings.bar.padding.y,
    -- padding_bottom = settings.bar.padding.y,
    sticky = true,
    position = "top",
    shadow = false
})
