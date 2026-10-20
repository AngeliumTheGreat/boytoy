local apu = {}

--[[  TODO:
   - unused bits in regs handled properly
   - store all reg values
   - synth everything
]]

-- imports
local test = require "util.test"
local vm = require "emulator.vm"
local getMem = vm.getMem
local setMemDirect = vm.setMemDirect

-- constants
local TAU = math.pi * 2
local SAMPLERATE = 44100
local REGISTERS = {
   0xFF25, 0xFF24, 0xFF10, 0xFF11, 0xFF12, 0xFF13, 0xFF14, 0xFF16,
   0xFF17, 0xFF18, 0xFF19, 0xFF1A, 0xFF1B, 0xFF1C, 0xFF1D, 0xFF1E,
   0xFF20, 0xFF21, 0xFF22, 0xFF23,
}

local DEFAULTS = {
   [0xFF10] = 0x80, [0xFF11] = 0xBF, [0xFF12] = 0xF3, [0xFF13] = 0xFF,
   [0xFF14] = 0xBF, [0xFF16] = 0x3F, [0xFF17] = 0x00, [0xFF18] = 0xFF,
   [0xFF19] = 0xBF, [0xFF1A] = 0x7F, [0xFF1B] = 0xFF, [0xFF1C] = 0x9F,
   [0xFF1D] = 0xFF, [0xFF1E] = 0xBF, [0xFF20] = 0xFF, [0xFF21] = 0x00,
   [0xFF22] = 0x00, [0xFF23] = 0xBF, [0xFF24] = 0x77, [0xFF25] = 0xF3,
   [0xFF26] = 0xF1,
}

-- variables
local apu_off
local queue
local buffer

----------------------
-- helper functions --
----------------------

function apu.reset()
   -- reset variables
   apu_off = false
   queue = love.audio.newQueueableSource(44100, 8, 2, 8)
   buffer = {}

   -- reset registers
   for addr, val in pairs(DEFAULTS) do
      setMemDirect(addr, val)
   end
end

----------------
-- main cycle --
----------------

local function _cycle()
   local regs = {}

   coroutine.yield()
end

local cycle = coroutine.wrap(function() while true do _cycle() end end)
apu.cycle = cycle

-------------------------------------
-- handlers for setting audio regs --
-------------------------------------

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

handlers[0xFF26] = function(val)
   if bit.band(val, 0x80) == 0 then
      setMemDirect(0xFF26, bit.band(getMem(0xFF26), 0x7F))
   else
      setMemDirect(0xFF26, bit.bor(getMem(0xFF26), 0x80))
   end
end

return apu
