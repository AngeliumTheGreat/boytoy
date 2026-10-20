local vm = require "emulator.vm"
local ppu = require "emulator.ppu"
local apu = require "emulator.apu"

-- function to get and set memory at the address
local getMem = vm.getMem
local setMem = vm.setMemDirect

-- global variables
-- fetcher-internal variable
local x_position_fetcher
local window_line_counter
local window_fetching_mode
-- queue for holding stuff to be rendered
local bg_fifo = {}

local sprite_fifo = {}

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

-- get a bit of a byte in boolean form
local function getBitBool(byte, n)
	return bit.band(byte, bit.lshift(1,n))  ~= 0
end

-- background and window pixel Fetcher
local function fetchBg()

	local LCDC = getMem(0xFF40) -- flags

	if not getBitBool(LCDC, 0) then -- bg/window disabled, everything rendered as white

		bg_fifo = {}
		for i=1,16 do
			bg_fifo[i] = {}
		end
		for i = 1,16 do
			bg_fifo[i].color = 0
			bg_fifo[i].palette = 0
		end

	else

		local LY = getMem(0xFF44)
		local SCX = getMem(0xFF43)
		local SCY = getMem(0xFF42)

		-- fetch tile number
		local map_at_9C00_not_9800
		local scx_div_by_8
		local tn_x_offset
		local tn_y_offset
		local td_offset

		if window_fetching_mode then
			map_at_9C00_not_9800 = getBitBool(LCDC, 6)
			scx_div_by_8 = 0
			tn_y_offset = 32 * bit.rshift(window_line_counter, 3) -- 32 * (WINDOW_LINE_COUNTER / 8)
			td_offset = 2 * bit.band(window_line_counter, 0x7) -- 2 * (WINDOW_LINE_COUNTER mod 8)
		else -- background fetching mode
			map_at_9C00_not_9800 = getBitBool(LCDC, 3)
			scx_div_by_8 = bit.rshift(SCX, 3) -- SCX / 8
			tn_y_offset = 32 * bit.rshift(bit.band((LY + SCY), 0xFF), 3) -- 32 * (((LY + SCY) & 0xFF) / 8)
			td_offset = 2 * bit.band((LY + SCY), 0x7) -- 2 * ((LY + SCY) mod 8)
		end

		tn_x_offset = bit.band((x_position_fetcher + scx_div_by_8), 0x1F) -- add and wrap around scx
		local tn_offset = bit.band((tn_x_offset + tn_y_offset), 0x3ff)
		local tile_number_address

		if map_at_9C00_not_9800 then
			tile_number_address = 0x9C00 + tn_offset
		else
			tile_number_address = 0x9800 + tn_offset
		end

		local tile_number = getMem(tile_number_address)

		-- fetch tile data
		local tile_data_low
		local tile_data_high
		local method_8000_not_8800 = getBitBool(LCDC, 4)
		-- low
		-- high
		-- push to fifo
	end
end

-- sprite pixel Fetcher
local function fetchSprite()
	-- fetch tile number
	-- fetch tile data (low)
	-- fetch tile data (high)
	-- push to fifo
end

-- doing one line of 160 pixels
local function scanline()

	-- run every 456 T-cycles
	
	-- OAM Scan (Mode 2)
	-- 80 T-cycles, 2 per sprite
	setMem(0xFF41, bit.bor(bit.band(getMem(0xFF41), 0xFE), 0x02)) -- set bits 1-2 of LCD status register to 10 (OAM Scan mode)

	local sprite_buffer = {}
	local current_sprites_number = 0
	local OAM_begin = 0xFE00  -- first byte of OAM memory
	local LY = getMem(0xFF44)
	local LCDC = getMem(0xFF40) -- flags
	local tall_sprites = getBitBool(LCDC, 2) -- flag that says if sprites should be tall, converted to boolean
	local sprite_height = tall_sprites and 16 or 8
	for i=1,40 do
		-- get stuff from OAM
		local OAM_offset = (i - 1) * 4 -- how much we need to shift to get i'th sprite
		local y_pos = getMem(OAM_begin + OAM_offset)
		local x_pos = getMem(OAM_begin + OAM_offset + 1)
		local tile_number = getMem(OAM_begin + OAM_offset + 2)
		local sprite_flags = getMem(OAM_begin + OAM_offset + 3)
		-- add to buffer if conditions apply
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

	bg_fifo = {}
	sprite_fifo = {}

	local x_position = 0
	-- reset fetcher internal variables
	x_position_fetcher = 0
	window_line_counter = 0
	window_fetching_mode = false

	-- TODO: implement drawing loop
	while x_position < 160 do
		break
	end

	-- H-Blank (Mode 0)
	setMem(0xFF41, bit.band(getMem(0xFF41), 0xFC)) -- set bits 1-2 of LCD status register to 00 (H-Blank mode)
end
