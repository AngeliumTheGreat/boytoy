local test = require "util.test"
test.enable()

local _, settings = pcall(require, "settings")
local keybindings = settings.keybindings

local love = require "love"
local vm = require "emulator.vm"

-- current screen
local screen = "menu"

-- in hertz
local CPU_FREQUENCY = 200

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

local romData = nil
local romPath = nil

local function mouseOnButton(x,y,button)
    if x >= buttons[button].x
            and x <= buttons[button].x + buttons[button].width
            and y >= buttons[button].y
            and y <= buttons[button].y + buttons[button].height then return true else return false end
end

function love.keypressed(key)
    for keyboardKey, gameboyButton in pairs(keybindings) do
        if key == keyboardKey then
            -- IMPLEMENT: press da key in the emulator
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        -- Check if the Load ROM button was clicked
        if mouseOnButton(x,y,"Load") then
            -- implement loading
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
end

function love.load()
    love.window.setTitle("Game Boy Emulator")
    love.window.setMode(640, 480)
end

function love.draw()
    if screen == "menu" then
        drawMenu()
    end
end

local cycle_accumulator = 0
local cycle = vm.cycle
function love.update(dt)
    cycle_accumulator = cycle_accumulator + CPU_FREQUENCY * dt
    while cycle_accumulator > 1 do
        cycle()
        cycle_accumulator = cycle_accumulator - 1
    end
end
