return {
    black = 0xff181819,
    white = 0xffe2e2e3,
    red = 0xfffc5d7c,
    green = 0xff9ed072,
    blue = 0xff005ab0,
    yellow = 0xffe7c664,
    orange = 0xfff39660,
    magenta = 0xffb39df3,
    catppuccinno = 0xffc69ff5,
    grey = 0xff7f8490,
    transparent = 0x00000000,
    solid_white = 0xffffffff,
    ayu = 0xffe6b450,
    mocha = 0xffCBA6F7,

    bar = {
        -- bg = 0x4a000000,
        bg = 0xb1000000,
        border = 0xff2c2e34
    },
    popup = {
        bg = 0xc02c2e34,
        border = 0xff7f8490
    },
    bg1 = 0x1affffff,
    -- bg1 = 0xff363944,
    bg2 = 0xff414550,

    rainbow = {0xffff007c, 0xffc53b53, 0xffff757f, 0xff41a6b5, 0xff4fd6be, 0xffc3e88d, 0xffffc777, 0xff9d7cd8,
               0xffff9e64, 0xffbb9af7, 0xff7dcfff, 0xff7aa2f7, 0x00000000},

    background = {
        -- light modeÍ
        -- highlight = 0x66ffffff,
        -- normal = 0x1affffff,

        -- dark mode
        highlight = 0x44ffffff,
        normal = 0x11ffffff,
    },

    with_alpha = function(color, alpha)
        if alpha > 1.0 or alpha < 0.0 then
            return color
        end
        return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
    end
}
