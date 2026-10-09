-- config file for settings. use this. please ;w;
function love.conf(t)
    t.console = true
end

return {
    keybindings = {
        up     = "up",
        down   = "down",
        left   = "left",
        right  = "right",

        x      = "a",
        z      = "b",

        ["return"]  = "start",
        backspace = "select"
    }
}