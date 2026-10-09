local getMem = vm.getMem

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

local function getBit(byte, n)
	return (byte & bit.lshift(1,n))  ~= 0
end

local function scanline()

	-- run every 456 T-cycles
	
	-- OAM Scan (Mode 2)
	-- 80 T-cycles, 2 per sprite

	local sprite_buffer = {}

	local begin = 0xFE00  -- first byte of OAM memory
	for i=1,40 do
		-- get stuff from OAM
		local offset = (i-1)*4 -- how much we need to shift to get i'th sprite
		local y_pos = getMem(begin + offset)
		local x_pos = getMem(begin + offset + 1)
		local tile_number = getMem(begin + offset + 2)
		local sprite_flags = getMem(begin + offset + 3)
		-- add to buffer if conditions apply
		local LCD = getMem(0xFF40) -- flags
		local tall_sprites = getBit(LCD, 2) -- flag that says if sprites should be tall
		local sprite_height = tall_sprites and 16 or 8
		local current_sprites_number = 0
		if current_sprites_number < 10
			and x_pos > 0
			and LY + 16 >= y_pos
			and LY + 16 < y_pos + sprite_height 
		then
			sprite_place = current_sprites_number * 4
			sprite_buffer[sprite_place] = y_pos
			sprite_buffer[sprite_place + 1] = x_pos
			sprite_buffer[sprite_place + 2] = tile_number
			sprite_buffer[sprite_place + 3] = sprite_flags
		end
		idle(2)
	end

	
	-- Drawing (Mode 3)
	
	-- H-Blank (Mode 0)
end

