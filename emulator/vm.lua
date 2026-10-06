local vm = {}

local function cycle()
    print "meow"
    coroutine.yield()
end

vm.cycle = coroutine.wrap(cycle)

return vm
