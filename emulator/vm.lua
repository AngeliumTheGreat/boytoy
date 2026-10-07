local math = require("math")
local vm = {}
local pc = 1

-- registers
local reg_A = 0
local reg_B = 0
local reg_C = 0
local reg_D = 0
local reg_E = 0
local reg_F = 0
local reg_H = 0
local reg_L = 0
local reg_IE = 0
local reg_IR = 0

local function getRegA() return reg_A end
local function getRegF() return reg_F end
local function getRegB() return reg_B end
local function getRegC() return reg_C end
local function getRegD() return reg_D end
local function getRegE() return reg_E end
local function getRegH() return reg_H end
local function getRegL() return reg_L end

local function getRegAF() return (32*reg_A+reg_F) end
local function getRegBC() return (32*reg_B+reg_C) end
local function getRegDE() return (32*reg_D+reg_E) end
local function getRegHL() return (32*reg_H+reg_L) end

local function setRegA(x) reg_A=x end
local function setRegF(x) reg_F=x end
local function setRegB(x) reg_B=x end
local function setRegC(x) reg_C=x end
local function setRegD(x) reg_D=x end
local function setRegE(x) reg_E=x end
local function setRegH(x) reg_H=x end
local function setRegL(x) reg_L=x end

local function setRegAF(x) reg_A=math.floor(x/32); reg_F=x%32 end
local function setRegBC(x) reg_B=math.floor(x/32); reg_C=x%32 end
local function setRegDE(x) reg_D=math.floor(x/32); reg_E=x%32 end
local function setRegHL(x) reg_H=math.floor(x/32); reg_L=x%32 end

-- idle for a certain amount of M-cycles
local function idle(cycles)

end



local opcodes = {}

for i=1, 0xFF do
    table.insert(opcodes, function() end)
end

local function _cycle()
    pc = pc + 1
    coroutine.yield()
end

local cycle = coroutine.wrap(function() while true do _cycle() end end)
vm.cycle = cycle

return vm
