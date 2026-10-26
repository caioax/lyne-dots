-- Colors in the code shown with their color: #RGB, #RRGGBB, rgb()/hsl()
-- (also Hyprland's rgba(RRGGBBAA) in its Lua config) in every file. QML
-- reads 8 digits as #AARRGGBB (alpha first, Qt's way), CSS as #RRGGBBAA.
-- Color names (red, steelblue) only where they are colors: CSS and QML.
-- <leader>uc turns it off and on in the buffer
return {
    "catgoose/nvim-colorizer.lua",
    event = { "BufReadPre", "BufNewFile" },
    cmd = { "ColorizerToggle" },
    keys = {
        { "<leader>uc", "<cmd>ColorizerToggle<cr>", desc = "Color preview (toggle)" },
    },
    opts = {
        options = {
            parsers = {
                names = { enable = false },
                rgb = { enable = true },
                hsl = { enable = true },
            },
        },
        filetypes = {
            "*",
            css = { parsers = { css = true, hex = { rrggbbaa = true } } },
            qml = {
                parsers = { names = { enable = true }, hex = { hash_aarrggbb = true } },
                hooks = {
                    -- Qt.rgba(1, 0, 0, 1) takes 0 to 1, not CSS's 0 to 255:
                    -- read as rgba() it would show black
                    should_highlight_color = function(_, parser, ctx)
                        return not (parser == "rgb" or parser == "hsl")
                            or ctx.line:sub(ctx.col - 3, ctx.col - 1) ~= "Qt."
                    end,
                },
            },
        },
    },
}
