local test = require "util.test"
local utf8 = require "utf8"
test.enable()

local _, conf = pcall(require, "conf")
local keybindings = conf.keybindings

local love = require "love"
local apu = require "emulator.apu"
local vm = require "emulator.vm"

-- current screen
local screen = "menu"

-- in hertz
local cpu_frequency = 4194304
local max_dt = 1/20   -- stops a lag spike from snowballing

local buttons = {
        Load = {
            text = "Load ROM",
            x = 220,
            y = 180,
            width = 200,
            height = 50
        },

        Settings = {
            text = "Settings",
            x = 220,
            y = 250,
            width = 200,
            height = 50
        },

        Exit = {
            text = "Exit",
            x = 220,
            y = 320,
            width = 200,
            height = 50
        },
    }
local input = { text = "", focused = false,
                x = 220, y = 130, width = 200, height = 36 }

local function romLoad(filename)
    local file, err = io.open(filename, "rb")
    if not file then return nil, err end
    local data = file:read("*a")
    file:close()

    if not data or #data == 0 then
        return nil, "ROM is empty or could not be read"
    end
    if #data > 0x8000 then return nil, "ROM too large (needs bank switching)" end

    vm.initVM()
    for i = 1, #data do
        vm.memory[i] = data:byte(i)
    end
    print("file loaded successfully :3")
    return #data
end

local statusMsg = ""
local function tryLoad()
    local name = input.text:match("^%s*(.-)%s*$"):gsub('^"(.*)"$', "%1")
    local n, err = romLoad(name)
    if n then statusMsg = ""; screen = "emulator"
    else statusMsg = tostring(err) end
end

local function mouseOnButton(x,y,button)
    if x >= buttons[button].x
            and x <= buttons[button].x + buttons[button].width
            and y >= buttons[button].y
            and y <= buttons[button].y + buttons[button].height then return true else return false end
end

function love.textinput(t)
    if screen == "menu" and input.focused then
        input.text = input.text .. t
    end
end

function love.keypressed(key)
    if screen == "menu" and input.focused then
        if key == "backspace" then
            local cut = utf8.offset(input.text, -1)
            if cut then input.text = input.text:sub(1, cut - 1) end
        elseif key == "return" then
            tryLoad()
        end
        return  -- don't pass keys on to the emulator
    end

    for keyboardKey, gameboyButton in pairs(keybindings) do
        if key == keyboardKey then
            -- IMPLEMENT: press da key in the emulator
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        input.focused = x >= input.x and x <= input.x + input.width
            and y >= input.y and y <= input.y + input.height
        -- Check if the Load ROM button was clicked
        if mouseOnButton(x,y,"Load") then
            tryLoad()
        end

        if mouseOnButton(x,y,"Settings") then
            -- implement settings
        end

        if mouseOnButton(x,y,"Exit") then
            love.event.quit()
        end
    end
end

local function drawMenu()
    -- title
    love.graphics.printf(
        "BOYTOY :3",
        0,
        80,
        640,
        "center"
    )

    love.graphics.rectangle("line", input.x, input.y, input.width, input.height)
    love.graphics.printf(input.text, input.x + 6, input.y + 10,
                     input.width - 12, "left")
    if input.focused and math.floor(love.timer.getTime() * 2) % 2 == 0 then
        local w = love.graphics.getFont():getWidth(input.text)
        love.graphics.line(input.x + 6 + w, input.y + 6,
                       input.x + 6 + w, input.y + input.height - 6)
    end

    -- Buttons
    for _, button in pairs(buttons) do
        love.graphics.rectangle(
            "line",
            button.x,
            button.y,
            button.width,
            button.height
        )

        love.graphics.printf(
            button.text,
            button.x,
            button.y + 15,
            button.width,
            "center"
        )
    end

    love.graphics.printf(statusMsg, 0, 400, 640, "center")
end

function love.load()
    love.keyboard.setKeyRepeat(true)
    love.window.setTitle("Game Boy Emulator")
    love.window.setMode(640, 480)
end

function love.draw()
    if screen == "menu" then
        drawMenu()
    end
end

local cycle_accumulator = 0
local cpu_cycle = vm.cycle
local apu_cycle = apu.cycle
local apu_queue = apu.queue
function love.update(dt)
    if screen ~= "emulator" then return end
    cycle_accumulator = cycle_accumulator + cpu_frequency * math.min(dt, max_dt)
    while cycle_accumulator > 1 do
        cpu_cycle()
        apu_cycle()
        cycle_accumulator = cycle_accumulator - 1
    end
    apu_queue() -- push any rendered audio to the source. this guarantees only one push per cycle
end
