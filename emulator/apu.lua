local vm = require "emulator.vm"

local TAU = math.pi * 2
local phase = 0.0

local apu = {}

local queue_source = love.audio.newQueueableSource(44100, 8, 2, 8)
local queue_buffer = {}

local audio_src = love.sound.newSoundData(44100, 44100, 8, 2)
for i=0, 44100 - 1 do
   phase = phase + TAU * 440 / 44100
   audio_src:setSample(i, math.sin(phase))
end
queue_source:queue(audio_src)
queue_source:play()
queue_source:queue(audio_src)

local function _cycle()
   coroutine.yield()
end

local cycle = coroutine.wrap(function() while true do _cycle() end end)
apu.cycle = cycle

return apu
