local test = require "util.test"
local love = require "love"
local vm = require "emulator.vm"

test.enable()

-- current screen
local screen = "menu"

-- in hertz
local CPU_FREQUENCY = 200

local buttons = {
        ["Load"] = {
            text = "Load ROM",
            x = 220,
            y = 180,
            width = 200,
            height = 50
        },
        ["Settings"] = {
            text = "Settings",
            x = 220,
            y = 250,
            width = 200,
            height = 50
        },
        ["Exit"] = {
            text = "Exit",
            x = 220,
            y = 320,
            width = 200,
            height = 50
        }
    }

local romData = nil
local romPath = nil

function love.mousepressed(x, y, button)
    if button == 1 then
        -- Check if the Load ROM button was clicked
        if x >= buttons["Load"].x
            and x <= buttons["Load"].x + buttons["Load"].width
            and y >= buttons["Load"].y
            and y <= buttons["Load"].y + buttons["Load"].height then

            love.window.showFileDialog(
                "openfile",
                function(files, filtername, errorstring)

                    -- User cancelled
                    if #files == 0 then
                        return
                    end

                    if errorstring then
                        print("File dialog error: " .. errorstring)
                        return
                    end

                    -- First selected file
                    romPath = files[1]

                    -- Open the ROM
                    local file, err = love.filesystem.openNativeFile(
                        romPath,
                        "r"
                    )

                    if not file then
                        print("Failed to open ROM: " .. tostring(err))
                        return
                    end

                    -- Read the entire ROM
                    romData = file:read()

                    file:close()

                    print("Loaded ROM: " .. romPath)
                    print("ROM size: " .. #romData .. " bytes")

                    -- Your emulator can start using romData here
                    -- emulator.load(romData)
                end,
                {
                    title = "Load ROM",
                    acceptlabel = "Load",
                    cancellabel = "Cancel",
                    multiselect = false,
                    attachtowindow = true,

                    filters = {
                        ["ROM Files"] = "*.nes;*.gb;*.gbc;*.gba;*.smc;*.sfc",
                        ["All Files"] = "*"
                    }
                }
            )
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

function love.update(dt)
end

function love.draw()
    if screen == "menu" then
        drawMenu()
    end
end

local cycle_accumulator = 0
local cycle = vm.cycle
function love.update(delta)
    cycle_accumulator = cycle_accumulator + CPU_FREQUENCY * delta
    while cycle_accumulator > 1 do
        cycle()
        cycle_accumulator = cycle_accumulator - 1
    end
end
