local vm = {}

local function _cycle()
    coroutine.yield()
end

local cycle = coroutine.wrap(function() while true do _cycle() end end)
vm.cycle = cycle

return vm
