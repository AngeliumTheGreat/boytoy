local vm = {}

-- idle for a certain amount of M-cycles
local function idle(cycles)

end

local opcodes = {}

for i=1, 0xFF do
    table.insert(opcodes, function() end)
end

local function _cycle()
    coroutine.yield()
end

local cycle = coroutine.wrap(function() while true do _cycle() end end)
vm.cycle = cycle

return vm
