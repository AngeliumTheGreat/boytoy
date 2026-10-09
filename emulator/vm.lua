local test = require "util.test"
local vm = {}
local pc = 1

-- memory 
local memory = {}
for i=1,0x10000 do memory[i]=0 end

local function getMem(x) return memory[x+1] end
local function setMem(x,val) memory[x+1]=val end
local function getOpcode()
    local value = memory[pc]
    pc = pc + 1
    return value
end

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

-- interrupt master enable
local IME = 0

local function getRegA() return reg_A end
local function getRegF() return reg_F end
local function getRegB() return reg_B end
local function getRegC() return reg_C end
local function getRegD() return reg_D end
local function getRegE() return reg_E end
local function getRegH() return reg_H end
local function getRegL() return reg_L end

local function getRegAF() return (256*reg_A+reg_F) end
local function getRegBC() return (256*reg_B+reg_C) end
local function getRegDE() return (256*reg_D+reg_E) end
local function getRegHL() return (256*reg_H+reg_L) end

local function setRegA(x) reg_A=x end
local function setRegF(x) reg_F=x end
local function setRegB(x) reg_B=x end
local function setRegC(x) reg_C=x end
local function setRegD(x) reg_D=x end
local function setRegE(x) reg_E=x end
local function setRegH(x) reg_H=x end
local function setRegL(x) reg_L=x end

local function setRegAF(x) x=x%0x10000; reg_A=math.floor(x/256); reg_F=x%256 end
local function setRegBC(x) x=x%0x10000; reg_B=math.floor(x/256); reg_C=x%256 end
local function setRegDE(x) x=x%0x10000; reg_D=math.floor(x/256); reg_E=x%256 end
local function setRegHL(x) x=x%0x10000; reg_H=math.floor(x/256); reg_L=x%256 end

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
    opcodes[getOpcode() + 1]()
    coroutine.yield()
end

local cycle = coroutine.wrap(function() while true do _cycle() end end)
vm.cycle = cycle

-- sets the program it is passed as the rom and runs it. replaces fully, so rom
-- must be reset afterwards. only runs until the rom ends, so it's good to keep it short
local function testRun(program)
    for i = 1, #program do
        memory[i] = program[i]
    end
    local c = coroutine.wrap(function()
        while true do
            _cycle()
        end
    end)
    for i = 1, #program + 10 do
        local ok = pcall(c)
        if not ok then
            break
        end
    end
end

-- time how many M-cycles it takes an opcode to run
-- based on how many times it yields
-- every opcode takes at least one cycle since the vm yields between instructions
local function timeInstruction(instruction)
    local instruction = opcodes[instruction + 1]
    local instruction = coroutine.wrap(instruction)
    local i = 0
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

-- LD, 0xX2
opcodes[0x02+1] = function() setMem(getRegBC(), getRegA()); idle(1)  end
opcodes[0x12+1] = function() setMem(getRegDE(), getRegA()); idle(1) end
opcodes[0x22+1] = function() setMem(getRegHL(), getRegA()); setRegHL(getRegHL()+1); idle(1) end
opcodes[0x32+1] = function() setMem(getRegHL(), getRegA()); setRegHL(getRegHL()-1); idle(1) end

-- LD, 0xX6
opcodes[0x06+1] = function() setRegB(getOpcode()); idle(1) end
opcodes[0x16+1] = function() setRegD(getOpcode()); idle(1) end
opcodes[0x26+1] = function() setRegH(getOpcode()); idle(1) end
opcodes[0x36+1] = function() setMem(getRegHL(),getOpcode()); idle(2) end

-- LD, 0xXA
opcodes[0x0A+1] = function() setRegA(getMem(getRegBC())); idle(1) end
opcodes[0x1A+1] = function() setRegA(getMem(getRegDE())); idle(1) end
opcodes[0x2A+1] = function() setRegA(getMem(getRegHL())); setRegHL(getRegHL()+1); idle(1) end
opcodes[0x3A+1] = function() setRegA(getMem(getRegHL())); setRegHL(getRegHL()-1); idle(1) end

-- LD, 0xXE
opcodes[0x0E+1] = function() setRegC(getOpcode()); idle(1) end
opcodes[0x1E+1] = function() setRegE(getOpcode()); idle(1) end
opcodes[0x2E+1] = function() setRegL(getOpcode()); idle(1) end
opcodes[0x3E+1] = function() setRegA(getOpcode()); idle(1) end

-- LDH, 0xE0, 0xF0, 0xE2, 0xF2
opcodes[0xE0+1] = function() setMem(getOpcode()+0xFF00,getRegA()); idle(2) end
opcodes[0xF0+1] = function() setRegA(getMem(getOpcode()+0xFF00)); idle(2) end
opcodes[0xE2+1] = function() setMem(getRegC()+0xFF00,getRegA()); idle(1) end
opcodes[0xF2+1] = function() setRegA(getMem(getRegC()+0xFF00)); idle(1) end

-- LD, 0xEA, 0xFA
opcodes[0xEA+1] = function()
    local lo = getOpcode()
    local hi = getOpcode()
    setMem(hi * 0x100 + lo, getRegA()); idle(3) end
opcodes[0xFA+1] = function()
    local lo = getOpcode()
    local hi = getOpcode()
    setRegA(getMem(hi * 0x100 + lo)); idle(3) end

-- DI, disable interrupts, 0xF3

opcodes[0xF3+1] = function() IME=0 end

---------------------
-- unit test silly --
---------------------

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
    assert(getRegB(), getRegA())
    -- indirect get / set instructions take one extra M-cycle
    assert(timeInstruction(0x77) == 2 and timeInstruction(0x46) == 2)

    resetVM()
end)

test.unit "vm - LD loads" (function()
    -- LD [BC], A
    resetVM()
    setRegBC(0xC000); setRegA(0x42)
    testRun {0x02}
    assert(getMem(0xC000) == 0x42)
    assert(timeInstruction(0x02) == 2)

    -- LD [DE], A
    resetVM()
    setRegDE(0xC001); setRegA(0x43)
    testRun {0x12}
    assert(getMem(0xC001) == 0x43)
    assert(timeInstruction(0x12) == 2)

    -- LD [HL+], A
    resetVM()
    setRegHL(0xC002); setRegA(0x44)
    testRun {0x22}
    assert(getMem(0xC002) == 0x44)
    assert(getRegHL() == 0xC003)
    assert(timeInstruction(0x22) == 2)

    -- LD [HL-], A
    resetVM()
    setRegHL(0xC003); setRegA(0x45)
    testRun {0x32}
    assert(getMem(0xC003) == 0x45)
    assert(getRegHL() == 0xC002)
    assert(timeInstruction(0x32) == 2)

    -- LD B, d8
    resetVM()
    testRun {0x06, 0x12}
    assert(getRegB() == 0x12)
    assert(timeInstruction(0x06) == 2)

    -- LD D, d8
    resetVM()
    testRun {0x16, 0x23}
    assert(getRegD() == 0x23)
    assert(timeInstruction(0x16) == 2)

    -- LD H, d8
    resetVM()
    testRun {0x26, 0x34}
    assert(getRegH() == 0x34)
    assert(timeInstruction(0x26) == 2)

    
    -- LD [HL], d8
    resetVM()
    setRegHL(0xC004)
    testRun {0x36, 0x56}
    assert(getMem(0xC004) == 0x56)
    assert(timeInstruction(0x36) == 3)
    
    -- LD A, [BC]
    resetVM()
    setRegBC(0xC005); setMem(0xC005, 0x67)
    testRun {0x0A}
    assert(getRegA(),0x67)
    assert(timeInstruction(0x0A) == 2)

    -- LD A, [DE]
    resetVM()
    setRegDE(0xC006); setMem(0xC006, 0x78)
    testRun {0x1A}
    assert(getRegA()==0x78)
    assert(timeInstruction(0x1A) == 2)

    -- LD A, [HL+]
    resetVM()
    setRegHL(0xC007); setMem(0xC007, 0x89)
    testRun {0x2A}
    assert(getRegA() == 0x89)
    assert(getRegHL() == 0xC008)
    assert(timeInstruction(0x2A) == 2)

    -- LD A, [HL-]
    resetVM()
    setRegHL(0xC008); setMem(0xC008, 0x9A)
    testRun {0x3A}
    assert(getRegA() == 0x9A)
    assert(getRegHL() == 0xC007)
    assert(timeInstruction(0x3A) == 2)

    -- LD C, d8
    resetVM()
    testRun {0x0E, 0xAB}
    assert(getRegC() == 0xAB)
    assert(timeInstruction(0x0E) == 2)

    -- LD E, d8
    resetVM()
    testRun {0x1E, 0xBC}
    assert(getRegE() == 0xBC)
    assert(timeInstruction(0x1E) == 2)

    -- LD L, d8
    resetVM()
    testRun {0x2E, 0xCD}
    assert(getRegL() == 0xCD)
    assert(timeInstruction(0x2E) == 2)

    -- LD A, d8
    resetVM()
    testRun {0x3E, 0xDE}
    assert(getRegA() == 0xDE)
    assert(timeInstruction(0x3E) == 2)

    -- LDH [a8], A
    resetVM()
    setRegA(0x5A)
    testRun {0xE0, 0x80}
    assert(getMem(0xFF80) == 0x5A)
    assert(timeInstruction(0xE0) == 3)

    -- LDH A, [a8]
    resetVM()
    setMem(0xFF81, 0x6B)
    testRun {0xF0, 0x81}
    assert(getRegA() == 0x6B)
    assert(timeInstruction(0xF0) == 3)

    -- LD [C], A
    resetVM()
    setRegC(0x82); setRegA(0x7C)
    testRun {0xE2}
    assert(getMem(0xFF82) == 0x7C)
    assert(timeInstruction(0xE2) == 2)

    -- LD A, [C]
    resetVM()
    setRegC(0x83); setMem(0xFF83, 0x8D)
    testRun {0xF2}
    assert(getRegA() == 0x8D)
    assert(timeInstruction(0xF2) == 2)

    -- LD [a16], A
    resetVM()
    setRegA(0x9E)
    testRun {0xEA, 0x00, 0xC0}
    assert(getMem(0xC000) == 0x9E)
    assert(timeInstruction(0xEA) == 4)

    -- LD A, [a16]
    resetVM()
    setMem(0xC001, 0xAF)
    testRun {0xFA, 0x01, 0xC0}
    assert(getRegA() == 0xAF)
    assert(timeInstruction(0xFA) == 4)

    resetVM()
end)

return vm
