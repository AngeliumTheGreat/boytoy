local test = require "util.test"
local math = require "math"
local vm = {}
local pc = 1

-- memory 
local memory = {}
for i=1,0x10000 do memory[i]=0 end

local function getMem(x) return memory[x-1] end
local function setMem(x,val) memory[x-1]=val end
local function getOpcode() pc = pc + 1; return memory[pc - 2] end

-- idle for a certain amount of M-cycles
local function idle(cycles)
    for i=1, cycles do
        coroutine.yield()
    end
end

-- registers
local reg_A = 0
local reg_F = 0
local reg_B = 0
local reg_C = 0
local reg_D = 0
local reg_E = 0
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

local function getIndRegHL() idle(1); return getMem(getRegHL()) end
local function setIndRegHL(x) idle(1); setMem(getRegHL(), x) end

local function setFlagZ() setRegF(bit.bor(getRegF(), 0x40)) end
local function setFlagN() setRegF(bit.bor(getRegF(), 0x20)) end
local function setFlagH() setRegF(bit.bor(getRegF(), 0x10)) end
local function setFlagC() setRegF(bit.bor(getRegF(), 0x08)) end
local function resetFlagZ() setRegF(bit.band(getRegF(), 0xBF)) end
local function resetFlagN() setRegF(bit.band(getRegF(), 0xDF)) end
local function resetFlagH() setRegF(bit.band(getRegF(), 0xEF)) end
local function resetFlagC() setRegF(bit.band(getRegF(), 0xF7)) end

-- reset
local function resetVM()
    for i=1,0x10000 do memory[i]=0 end
    reg_A=0; reg_F=0; reg_B=0; reg_C=0; reg_D=0; reg_E=0; reg_H=0; reg_L=0; reg_IE=0; reg_IR=0
    pc = 1
end

test.unit "vm - registers" (function()
    resetVM()
    setRegB(3)
    assert(getRegB() == 3)
    setRegBC(0x1234)
    assert(getRegBC() == 0x1234)
    resetVM()
end)

test.unit "vm - flags" (function()
    resetVM()
    assert(getRegF() == 0x00)
    setFlagH()
    setFlagZ()
    assert(getRegF() == 0x50)
    resetFlagZ()
    assert(getRegF() == 0x10)
    setFlagZ()
    setFlagC()
    setFlagN()
    assert(getRegF() == 0x78)
    resetFlagZ(); assert(getRegF() == 0x38)
    resetFlagN(); assert(getRegF() == 0x18)
    resetFlagH(); assert(getRegF() == 0x08)
    resetFlagC(); assert(getRegF() == 0x00)
    resetVM()
end)

-------------------------------------
-- core vm loop + helper functions --
-------------------------------------

local opcodes = {}

local function _cycle()
    pc = pc + 1
    opcodes[memory[pc - 1] + 1]()   -- two offsets because of 0-index to 1-index conversion
    coroutine.yield()
end

local cycle = coroutine.wrap(function() while true do _cycle() end end)
vm.cycle = cycle

-- sets the program it is passed as the rom and runs it. replaces fully, so rom
-- must be reset afterwards. only runs until the rom ends, so it's good to keep it short
local function testRun(program)
    memory = program
    local c = coroutine.wrap(function() while true do _cycle() end end)
    while pc <= #program + 1 do
        pcall(c)
    end
end

-- time how many M-cycles it takes an opcode to run
-- based on how many times it yields
-- every opcode takes at least one cycle since the vm yields between instructions
local function timeInstruction(instruction)
    local instruction = opcodes[instruction + 1]
    local instruction = coroutine.wrap(instruction)
    i = 0
    while pcall(instruction) do
        i = i + 1
    end
    return i
end

-------------
-- opcodes --
-------------

local function op_nop() end

for i=1, 0x100 do
    table.insert(opcodes, op_nop)
end

-- LD, 0x40 to 0x7F

for i, dest in ipairs {setRegB, setRegC, setRegD, setRegE, setRegH, setRegL, setIndRegHL, setRegA} do
    for j, src in ipairs {getRegB, getRegC, getRegD, getRegE, getRegH, getRegL, getIndRegHL, getRegA} do
        opcodes[0x40 + (i-1) * 8 + (j-1) + 1] = function() dest(src()) end
    end
end

test.unit "vm - LD" (function()
    resetVM()
    setRegB(0x12); setRegC(0x00);
    -- LD C, B;
    testRun {0x48}
    assert(getRegC() == 0x12)
    assert(timeInstruction(0x48) == 1)

    resetVM()
    setRegHL(0x0002); setRegA(0x67); setRegB(0x00);
    -- LD [HL], A; LD B, [HL]; NOP (which gets overwritten)
    testRun {0x77; 0x46; 0x00}
    assert(getRegB() == getRegA())
    -- indirect get / set instructions take one extra M-cycle
    assert(timeInstruction(0x77) == 2 and timeInstruction(0x46) == 2)

    resetVM()
end)

return vm
