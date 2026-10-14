local vm = require "emulator.vm"
-- function to get and set memory at the address
local getMem = vm.getMem
local setMem = vm.setMem

-- do a certain number of yields
local function idle(n)
	for i=1,n do
		coroutine.yield()
	end
end

-- time how many yields it takes for stuff to run
local function timeInstruction(instruction)
	local instruction = coroutine.wrap(instruction)
	local i = 0
	while pcall(instruction) do
		i = i + 1
	end
	return i
end

-- get a bit of a byte
local function getBit(byte, n)
	return (bit.band(byte, bit.lshift(1,n)))  ~= 0
end

-- background and window pixel Fetcher
local function fetchBg()
	-- fetch tile number
	-- fetch tile data (low)
	-- fetch tile data (high)
	-- push to fifo
end

-- sprite pixel Fetcher
local function fetchSprite()
	-- fetch tile number
	-- fetch tile data (low)
	-- fetch tile data (high)
	-- push to fifo
end

-- doing one line of 160 pixels
local function scanline(LY)

	-- run every 456 T-cycles
	
	-- OAM Scan (Mode 2)
	-- 80 T-cycles, 2 per sprite
	setMem(0xFF41, bit.bor(bit.band(getMem(0xFF41), 0xFE), 0x02)) -- set bits 1-2 of LCD status register to 10 (OAM Scan mode)

	local sprite_buffer = {}

	local OAM_begin = 0xFE00  -- first byte of OAM memory
	for i=1,40 do
		-- get stuff from OAM
		local OAM_offset = (i - 1) * 4 -- how much we need to shift to get i'th sprite
		local y_pos = getMem(OAM_begin + OAM_offset)
		local x_pos = getMem(OAM_begin + OAM_offset + 1)
		local tile_number = getMem(OAM_begin + OAM_offset + 2)
		local sprite_flags = getMem(OAM_begin + OAM_offset + 3)
		-- add to buffer if conditions apply
		local LCDC = getMem(0xFF40) -- flags
		local tall_sprites = getBit(LCDC, 2) -- flag that says if sprites should be tall
		local sprite_height = tall_sprites and 16 or 8
		local current_sprites_number = 0
		-- ^ this resets every iteration. move somewhere else to fix
		if current_sprites_number < 10
			and x_pos > 0
			and LY + 16 >= y_pos
			and LY + 16 < y_pos + sprite_height 
		then
			local sprite_place = current_sprites_number * 4
			sprite_buffer[sprite_place] = y_pos
			sprite_buffer[sprite_place + 1] = x_pos
			sprite_buffer[sprite_place + 2] = tile_number
			sprite_buffer[sprite_place + 3] = sprite_flags
			current_sprites_number = current_sprites_number + 1
		end
		idle(2)
	end

	
	-- Drawing (Mode 3)
	setMem(0xFF41, bit.bor(getMem(0xFF41), 0x03)) -- set bits 1-2 of LCD status register to 11 (Drawing mode)

	local drawing_t_cycles = 0

	local bg_fifo = {}
	local sprite_fifo = {}

	local x_position_counter = 0

	while x_position_counter < 160 do
		-- implement drawing loop
	end


	-- H-Blank (Mode 0)
	setMem(0xFF41, bit.band(getMem(0xFF41), 0xFC)) -- set bits 1-2 of LCD status register to 00 (H-Blank mode)
end
