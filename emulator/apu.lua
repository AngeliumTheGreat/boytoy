local vm = require "emulator.vm"

local TAU = math.pi * 2
local SAMPLERATE = 44100
local REGISTERS = {
   0xFF25, 0xFF24, 0xFF10, 0xFF11, 0xFF12, 0xFF13, 0xFF14, 0xFF16,
   0xFF17, 0xFF18, 0xFF19, 0xFF1A, 0xFF1B, 0xFF1C, 0xFF1D, 0xFF1E,
   0xFF20, 0xFF21, 0xFF22, 0xFF23,
}

local apu = {}

local apu_off
local queue = love.audio.newQueueableSource(44100, 8, 2, 8)
local buffer = {}

local function _cycle()
   local regs = {}

   coroutine.yield()
end

local cycle = coroutine.wrap(function() while true do _cycle() end end)
apu.cycle = cycle

-------------------------------------
-- handlers for setting audio regs --
-------------------------------------

local setMemDirect = vm.setMemDirect

local function handler(addr)
   return function(val)
      if apu_off then return end
      setMemDirect(addr, val)
   end
end

local handlers = vm.reg_handlers

for _, v in ipairs(REGISTERS) do
   handlers[v] = handler(v)
end


return apu
