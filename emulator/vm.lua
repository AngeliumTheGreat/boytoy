local test = require "util.test"
local vm = {}
local pc = 1
local sp = 0

-- memory 
local memory = {}
for i=1,0x10000 do memory[i]=0 end

local function getMem(x) return memory[(x % 0x10000) + 1] end
local function setMem(x,val) memory[(x % 0x10000) + 1] = val % 0x100 end
local function getOpcode()
    local value = memory[pc]
    pc = (pc % 0x10000) + 1
    return value
end

-- idle for a certain amount of M-cycles
local function idle(cycles)
    for i=1, cycles * 4 do
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

local function setRegA(x) reg_A=x%0x100 end
local function setRegF(x) reg_F=bit.band(x, 0xF0) end
local function setRegB(x) reg_B=x%0x100 end
local function setRegC(x) reg_C=x%0x100 end
local function setRegD(x) reg_D=x%0x100 end
local function setRegE(x) reg_E=x%0x100 end
local function setRegH(x) reg_H=x%0x100 end
local function setRegL(x) reg_L=x%0x100 end

local function setRegAF(x) x=x%0x10000; reg_A=math.floor(x/256); reg_F = bit.band(x % 256, 0xF0) end
local function setRegBC(x) x=x%0x10000; reg_B=math.floor(x/256); reg_C=x%256 end
local function setRegDE(x) x=x%0x10000; reg_D=math.floor(x/256); reg_E=x%256 end
local function setRegHL(x) x=x%0x10000; reg_H=math.floor(x/256); reg_L=x%256 end

local function getIndRegHL() idle(1); return getMem(getRegHL()) end
local function setIndRegHL(x) idle(1); setMem(getRegHL(), x) end

local function setFlagZ() setRegF(bit.bor(getRegF(), 0x80)) end
local function setFlagN() setRegF(bit.bor(getRegF(), 0x40)) end
local function setFlagH() setRegF(bit.bor(getRegF(), 0x20)) end
local function setFlagC() setRegF(bit.bor(getRegF(), 0x10)) end
local function resetFlagZ() setRegF(bit.band(getRegF(), 0x7F)) end
local function resetFlagN() setRegF(bit.band(getRegF(), 0xBF)) end
local function resetFlagH() setRegF(bit.band(getRegF(), 0xDF)) end
local function resetFlagC() setRegF(bit.band(getRegF(), 0xEF)) end
local function getFlagZ() return bit.band(getRegF(), 0x80) ~= 0 end
local function getFlagN() return bit.band(getRegF(), 0x40) ~= 0 end
local function getFlagH() return bit.band(getRegF(), 0x20) ~= 0 end
local function getFlagC() return bit.band(getRegF(), 0x10) ~= 0 end

local function setFlags(z, n, h, c)
    local f = 0
    if z then f = f + 0x80 end
    if n then f = f + 0x40 end
    if h then f = f + 0x20 end
    if c then f = f + 0x10 end
    setRegF(f)
end

-- reset
local function resetVM()
    for i=1,0x10000 do memory[i]=0 end
    reg_A=0; reg_F=0; reg_B=0; reg_C=0; reg_D=0; reg_E=0; reg_H=0; reg_L=0; reg_IE=0; reg_IR=0
    pc = 1
    IME = 0
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
    assert(getRegF() == 0xA0)
    resetFlagZ()
    assert(getRegF() == 0x20)
    setFlagZ()
    assert(getFlagZ())
    setFlagC()
    setFlagN()
    assert(getFlagN())
    assert(getRegF() == 0xF0)
    resetFlagZ(); assert(getRegF() == 0x70)
    resetFlagN(); assert(getRegF() == 0x30)
    resetFlagH(); assert(getRegF() == 0x10)
    assert(not getFlagH())
    resetFlagC(); assert(getRegF() == 0x00)
    resetVM()
end)

-------------------------------------
-- core vm loop + helper functions --
-------------------------------------

local opcodes = {}

local function _cycle()
    opcodes[getOpcode() + 1]()
    idle(1)
end

local cycle = coroutine.wrap(function() while true do _cycle() end end)
vm.cycle = cycle

-- how long does testRun run past the end of program length
local testLenBuffer = 10

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
    for i = 1, (#program + testLenBuffer) * 4 do
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
    if type(instruction) ~= "function" then
        instruction = opcodes[instruction + 1]
    end
    instruction = coroutine.wrap(instruction)
    local i = -1
    while pcall(instruction) do
        i = i + 1
    end
    return (i / 4) + 1
end

-- converts unsigned to signed 8 bit
local function toSigned8(value)
    if value >= 0x80 then
        return value - 0x100
    end
    return value
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

-- AND, 0xA0 to 0xA7, 0xE6

local function op_and(src)
    resetFlagN(); setFlagH(); resetFlagC()
    local r = bit.band(getRegA(), src())
    setRegA(r)
    if r == 0 then
        setFlagZ()
    else
        resetFlagZ()
    end
end

for i, src in ipairs { getRegB, getRegC, getRegD, getRegE, getRegH, getRegL, getIndRegHL, getRegA } do
    opcodes[0xA0 + (i-1) + 1] = function() op_and(src) end
end

opcodes[0xE6 + 1] = function() idle(1); op_and(getOpcode) end

test.unit "vm - AND" (function()
    test.label "timings"
    test.assert_equal(timeInstruction(0xA2), 1)
    test.assert_equal(timeInstruction(0xA6), 2)
    test.assert_equal(timeInstruction(0xE6), 2)

    test.label "arithmetic and flags"
    resetVM()
    setRegA(0x88); setRegB(0x0F)
    -- AND B
    testRun { 0xA0 }
    test.assert_equal(getRegA(), 0x08)
    test.assert_equal(getRegF(), 0x20)
    resetVM()
    setRegA(0x12)
    -- AND n8; 0x00
    testRun { 0xE6, 0x00 }
    test.assert_equal(getRegA(), 0x00)
    test.assert_equal(getRegF(), 0xA0)
    resetVM()
end)

-- XOR, 0xA8 to 0xAF, 0xEE

local function op_xor(src)
    resetFlagN(); resetFlagH(); resetFlagC()
    local r = bit.bxor(getRegA(), src())
    setRegA(r)
    if r == 0 then
        setFlagZ()
    else
        resetFlagZ()
    end
end

for i, src in ipairs { getRegB, getRegC, getRegD, getRegE, getRegH, getRegL, getIndRegHL, getRegA } do
    opcodes[0xA8 + (i-1) + 1] = function() op_xor(src) end
end

opcodes[0xEE + 1] = function() idle(1); op_xor(getOpcode) end

test.unit "vm - XOR" (function()
    test.label "timings"
    test.assert_equal(timeInstruction(0xAA), 1)
    test.assert_equal(timeInstruction(0xAE), 2)
    test.assert_equal(timeInstruction(0xEE), 2)

    test.label "arithmetic and flags"
    resetVM()
    setRegA(0xAA); setRegD(0x0F)
    -- XOR D
    testRun { 0xAA }
    test.assert_equal(getRegA(), 0xA5)
    test.assert_equal(getRegF(), 0x00)
    resetVM()
    setRegA(0x0F)
    -- XOR n8; 0x0F
    testRun { 0xEE, 0x0F }
    test.assert_equal(getRegA(), 0x00)
    test.assert_equal(getRegF(), 0x80)
    resetVM()
end)

-- OR, 0xB0 to 0xB7, 0xF6

local function op_or(src)
    resetFlagN(); resetFlagH(); resetFlagC()
    local r = bit.bor(getRegA(), src())
    setRegA(r)
    if r == 0 then
        setFlagZ()
    else
        resetFlagZ()
    end
end

for i, src in ipairs { getRegB, getRegC, getRegD, getRegE, getRegH, getRegL, getIndRegHL, getRegA } do
    opcodes[0xB0 + (i-1) + 1] = function() op_or(src) end
end

opcodes[0xF6 + 1] = function() idle(1); op_or(getOpcode) end

test.unit "vm - OR" (function()
    test.label "timings"
    test.assert_equal(timeInstruction(0xB2), 1)
    test.assert_equal(timeInstruction(0xB6), 2)
    test.assert_equal(timeInstruction(0xF6), 2)

    test.label "arithmetic and flags"
    resetVM()
    setRegA(0x40); setRegH(0x12); setRegF(0x40)
    -- OR H
    testRun { 0xB4 }
    test.assert_equal(getRegA(), 0x52)
    test.assert_equal(getRegF(), 0x00)
    resetVM()
    -- OR B
    testRun { 0xB0 }
    test.assert_equal(getRegA(), 0x00)
    test.assert_equal(getRegF(), 0x80)
    resetVM()
    setRegA(0xF0); setRegF(0x10)
    -- OR n8; 0xFF
    testRun { 0xF6, 0xFF }
    test.assert_equal(getRegA(), 0xFF)
    test.assert_equal(getRegF(), 0x00)
    resetVM()
end)

-- JP nn, 0xC3
opcodes[0xC3+1] = function()
    local nn_lsb = getOpcode()
    local nn_msb = getOpcode()
    local nn = 256*nn_msb + nn_lsb
    pc = nn+1
    idle(3)
end

-- JP HL, 0xE9
opcodes[0xE9+1] = function()
    pc = getRegHL() + 1
end

-- JP cc, nn, 0xC2 0xD2 0xCA 0xDA
for opcode, condition in pairs({
    [0xC2] = function() return not getFlagZ() end, -- JP NZ,nn
    [0xD2] = function() return not getFlagC() end, -- JP NC,nn
    [0xCA] = function() return getFlagZ() end,     -- JP Z,nn
    [0xDA] = function() return getFlagC() end      -- JP C,nn
}) do
    opcodes[opcode + 1] = function()
        local lo = getOpcode()
        local hi = getOpcode()
        local addr = hi * 0x100 + lo

        if condition() then
            pc = addr + 1
            idle(3)
        else
            idle(2)
        end
    end
end

-- JR e, 0x18
opcodes[0x18+1] = function()
    local e = getOpcode()
    pc = pc + toSigned8(e)
    idle(2)
end

-- JR cc, e, 0x20 0x30 0x28 0x38
for opcode, condition in pairs({
    [0x20] = function() return not getFlagZ() end, -- JR NZ,e
    [0x30] = function() return not getFlagC() end, -- JR NC,e
    [0x28] = function() return getFlagZ() end,     -- JR Z,e
    [0x38] = function() return getFlagC() end      -- JR C,e
}) do
    opcodes[opcode + 1] = function()
        local offset = toSigned8(getOpcode())

        if condition() then
            pc = pc + offset
            idle(2)
        else
            idle(1)
        end
    end
end

test.unit "vm - JP and JR" (function()
    -- These tests check the PC immediately after an instruction.
    -- Avoid executing extra NOPs after the program ends.
    local oldTestLenBuffer = testLenBuffer
    testLenBuffer = 0

    -- JP a16 (0xC3)
    resetVM()
    testRun {0xC3, 0x34, 0x12}
    test.assert_equal(pc, 0x1234 + 1)
    assert(timeInstruction(0xC3) == 4)

    -- JP HL (0xE9)
    resetVM()
    setRegHL(0x4567)
    testRun {0xE9}
    test.assert_equal(pc, 0x4567 + 1)
    assert(timeInstruction(0xE9) == 1)

    -- JP NZ,a16 (0xC2), taken when Z=0
    resetVM()
    resetFlagZ()
    testRun {0xC2, 0x00, 0xC0}
    test.assert_equal(pc, 0xC000 + 1)
    assert(timeInstruction(0xC2) == 4)

    -- JP NZ,a16, not taken when Z=1
    resetVM()
    setFlagZ()
    testRun {0xC2, 0x00, 0xC0}
    test.assert_equal(pc, 4)
    assert(timeInstruction(0xC2) == 3)

    -- JP NC,a16 (0xD2), taken when C=0
    resetVM()
    resetFlagC()
    testRun {0xD2, 0x00, 0xC1}
    test.assert_equal(pc, 0xC100 + 1)
    assert(timeInstruction(0xD2) == 4)

    -- JP NC,a16, not taken when C=1
    resetVM()
    setFlagC()
    testRun {0xD2, 0x00, 0xC1}
    test.assert_equal(pc, 4)
    assert(timeInstruction(0xD2) == 3)

    -- JP Z,a16 (0xCA), taken when Z=1
    resetVM()
    setFlagZ()
    testRun {0xCA, 0x00, 0xC2}
    test.assert_equal(pc, 0xC200 + 1)
    assert(timeInstruction(0xCA) == 4)

    -- JP Z,a16, not taken when Z=0
    resetVM()
    resetFlagZ()
    testRun {0xCA, 0x00, 0xC2}
    test.assert_equal(pc, 4)
    assert(timeInstruction(0xCA) == 3)

    -- JP C,a16 (0xDA), taken when C=1
    resetVM()
    setFlagC()
    testRun {0xDA, 0x00, 0xC3}
    test.assert_equal(pc, 0xC300 + 1)
    assert(timeInstruction(0xDA) == 4)

    -- JP C,a16, not taken when C=0
    resetVM()
    resetFlagC()
    testRun {0xDA, 0x00, 0xC3}
    test.assert_equal(pc, 4)
    assert(timeInstruction(0xDA) == 3)

    -- JR e8 (0x18), positive offset
    resetVM()
    testRun {0x18, 0x05}
    test.assert_equal(pc, 8)
    assert(timeInstruction(0x18) == 3)

    -- JR e8, negative offset
    resetVM()
    testRun {0x18, 0xFE}
    test.assert_equal(pc, 1)
    assert(timeInstruction(0x18) == 3)

    -- JR NZ,e8 (0x20), taken
    resetVM()
    resetFlagZ()
    testRun {0x20, 0x05}
    test.assert_equal(pc, 8)
    assert(timeInstruction(0x20) == 3)

    -- JR NZ,e8, not taken
    resetVM()
    setFlagZ()
    testRun {0x20, 0x05}
    test.assert_equal(pc, 3)
    assert(timeInstruction(0x20) == 2)

    -- JR NC,e8 (0x30), taken
    resetVM()
    resetFlagC()
    testRun {0x30, 0x05}
    test.assert_equal(pc, 8)
    assert(timeInstruction(0x30) == 3)

    -- JR NC,e8, not taken
    resetVM()
    setFlagC()
    testRun {0x30, 0x05}
    test.assert_equal(pc, 3)
    assert(timeInstruction(0x30) == 2)

    -- JR Z,e8 (0x28), taken
    resetVM()
    setFlagZ()
    testRun {0x28, 0x05}
    test.assert_equal(pc, 8)
    assert(timeInstruction(0x28) == 3)

    -- JR Z,e8, not taken
    resetVM()
    resetFlagZ()
    testRun {0x28, 0x05}
    test.assert_equal(pc, 3)
    assert(timeInstruction(0x28) == 2)

    -- JR C,e8 (0x38), taken
    resetVM()
    setFlagC()
    testRun {0x38, 0x05}
    test.assert_equal(pc, 8)
    assert(timeInstruction(0x38) == 3)

    -- JR C,e8, not taken
    resetVM()
    resetFlagC()
    testRun {0x38, 0x05}
    test.assert_equal(pc, 3)
    assert(timeInstruction(0x38) == 2)

    resetVM()
    testLenBuffer = oldTestLenBuffer
end)

local function op_cp(value)
    local a = getRegA()
    local result = a - value
    setFlags(result % 0x100 == 0, true, bit.band(a, 0x0F) < bit.band(value, 0x0F), a<value)
end

-- CP r/[HL], 0xB8 - 0xBF
opcodes[0xB8 + 1] = function() op_cp(getRegB()) end
opcodes[0xB9 + 1] = function() op_cp(getRegC()) end
opcodes[0xBA + 1] = function() op_cp(getRegD()) end
opcodes[0xBB + 1] = function() op_cp(getRegE()) end
opcodes[0xBC + 1] = function() op_cp(getRegH()) end
opcodes[0xBD + 1] = function() op_cp(getRegL()) end
opcodes[0xBE + 1] = function() op_cp(getIndRegHL()) end
opcodes[0xBF + 1] = function() op_cp(getRegA()) end

-- CP n, 0xFE
opcodes[0xFE + 1] = function() idle(1); op_cp(getOpcode()) end

test.unit "vm - CP" (function()

    -- Equal values: Z=1, N=1, H=0, C=0
    setRegA(0x42)
    resetFlagZ(); resetFlagN(); resetFlagH(); resetFlagC()
    op_cp(0x42)
    assert(getRegA() == 0x42)
    assert(getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- No borrow, nonzero result: Z=0, N=1, H=0, C=0
    setRegA(0x50)
    resetFlagZ(); resetFlagN(); resetFlagH(); resetFlagC()
    op_cp(0x10)
    assert(getRegA() == 0x50)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- Half-borrow only: Z=0, N=1, H=1, C=0
    setRegA(0x10)
    resetFlagZ(); resetFlagN(); resetFlagH(); resetFlagC()
    op_cp(0x01)
    assert(getRegA() == 0x10)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(getFlagH())
    assert(not getFlagC())

    -- Full borrow: Z=0, N=1, H=1, C=1
    setRegA(0x00)
    resetFlagZ(); resetFlagN(); resetFlagH(); resetFlagC()
    op_cp(0x01)
    assert(getRegA() == 0x00)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(getFlagH())
    assert(getFlagC())

    -- Full borrow without half-borrow: Z=0, N=1, H=0, C=1
    setRegA(0x10)
    resetFlagZ(); resetFlagN(); resetFlagH(); resetFlagC()
    op_cp(0x20)
    assert(getRegA() == 0x10)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(getFlagC())

    -- Maximum value compared with zero: no borrow
    setRegA(0xFF)
    resetFlagZ(); resetFlagN(); resetFlagH(); resetFlagC()
    op_cp(0x00)
    assert(getRegA() == 0xFF)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- Zero compared with zero
    setRegA(0x00)
    resetFlagZ(); resetFlagN(); resetFlagH(); resetFlagC()
    op_cp(0x00)
    assert(getRegA() == 0x00)
    assert(getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())
end)

-- RLCA, RLA, RRCA, RRA, 0x07 0x17 0x0F 0x1F
opcodes[0x07 + 1] = function()
    local a = getRegA()
    local b7 = bit.band(a,0x80) ~= 0
    setFlags(false, false, false, b7)
    setRegA((bit.lshift(a,1)+(b7 and 1 or 0))%0x100) 
end
opcodes[0x17 + 1] = function()
    local a = getRegA()
    local b7 = bit.band(a,0x80) ~= 0
    local C = getFlagC() and 1 or 0
    setFlags(false, false, false, b7)
    setRegA((bit.lshift(a,1)+C)%0x100) 
end
opcodes[0x0F + 1] = function()
    local a = getRegA()
    local b0 = bit.band(a,0x01)
    setFlags(false, false, false, b0==1)
    setRegA((bit.rshift(a,1)+bit.lshift(b0,7))%0x100) 
end
opcodes[0x1F + 1] = function()
    local a = getRegA()
    local b0 = bit.band(a,0x01)
    local C = getFlagC() and 1 or 0
    setFlags(false, false, false, b0==1)
    setRegA((bit.rshift(a,1)+bit.lshift(C,7))%0x100) 
end

test.unit "vm - Rotate" (function()
    -- Equal values: Z=1, N=1, H=0, C=0
    setRegA(0x42)
    resetFlagZ(); resetFlagN(); resetFlagH(); resetFlagC()
    op_cp(0x42)
    assert(getRegA() == 0x42)
    assert(getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- No borrow, nonzero result: Z=0, N=1, H=0, C=0
    setRegA(0x50)
    resetFlagZ(); resetFlagN(); resetFlagH(); resetFlagC()
    op_cp(0x10)
    assert(getRegA() == 0x50)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- Half-borrow only: Z=0, N=1, H=1, C=0
    setRegA(0x10)
    resetFlagZ(); resetFlagN(); resetFlagH(); resetFlagC()
    op_cp(0x01)
    assert(getRegA() == 0x10)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(getFlagH())
    assert(not getFlagC())

    -- Full borrow: Z=0, N=1, H=1, C=1
    setRegA(0x00)
    resetFlagZ(); resetFlagN(); resetFlagH(); resetFlagC()
    op_cp(0x01)
    assert(getRegA() == 0x00)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(getFlagH())
    assert(getFlagC())

    -- Full borrow without half-borrow: Z=0, N=1, H=0, C=1
    setRegA(0x10)
    resetFlagZ(); resetFlagN(); resetFlagH(); resetFlagC()
    op_cp(0x20)
    assert(getRegA() == 0x10)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(getFlagC())

    -- Maximum value compared with zero: no borrow
    setRegA(0xFF)
    resetFlagZ(); resetFlagN(); resetFlagH(); resetFlagC()
    op_cp(0x00)
    assert(getRegA() == 0xFF)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- Zero compared with zero
    setRegA(0x00)
    resetFlagZ(); resetFlagN(); resetFlagH(); resetFlagC()
    op_cp(0x00)
    assert(getRegA() == 0x00)
    assert(getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())
end)

local function op_add(value)
    local a = getRegA()
    local result = a + value

    setRegA(result % 0x100)
    setFlags(
        result % 0x100 == 0,
        false,
        (a % 0x10) + (value % 0x10) > 0x0F,
        result > 0xFF
    )
end

-- ADD, 0x80-0x87
opcodes[0x80 + 1] = function() op_add(getRegB()) end
opcodes[0x81 + 1] = function() op_add(getRegC()) end
opcodes[0x82 + 1] = function() op_add(getRegD()) end
opcodes[0x83 + 1] = function() op_add(getRegE()) end
opcodes[0x84 + 1] = function() op_add(getRegH()) end
opcodes[0x85 + 1] = function() op_add(getRegL()) end
opcodes[0x86 + 1] = function() op_add(getIndRegHL()) end
opcodes[0x87 + 1] = function() op_add(getRegA()) end

test.unit "vm - ADD" (function()
    -- Normal addition: 0x12 + 0x23 = 0x35
    setRegA(0x12)
    op_add(0x23)
    assert(getRegA() == 0x35)
    assert(not getFlagZ())
    assert(not getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- Zero result with 8-bit overflow: 0xFF + 0x01 = 0x00
    setRegA(0xFF)
    op_add(0x01)
    assert(getRegA() == 0x00)
    assert(getFlagZ())
    assert(not getFlagN())
    assert(getFlagH())
    assert(getFlagC())

    -- Half-carry only: 0x0F + 0x01 = 0x10
    setRegA(0x0F)
    op_add(0x01)
    assert(getRegA() == 0x10)
    assert(not getFlagZ())
    assert(not getFlagN())
    assert(getFlagH())
    assert(not getFlagC())

    -- Carry only: 0xF0 + 0x10 = 0x00
    -- This also produces zero, so both Z and C are set.
    setRegA(0xF0)
    op_add(0x10)
    assert(getRegA() == 0x00)
    assert(getFlagZ())
    assert(not getFlagN())
    assert(not getFlagH())
    assert(getFlagC())

    -- Maximum result without overflow: 0xFE + 0x01 = 0xFF
    setRegA(0xFE)
    op_add(0x01)
    assert(getRegA() == 0xFF)
    assert(not getFlagZ())
    assert(not getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- Adding zero to zero: result is zero, no carry
    setRegA(0x00)
    op_add(0x00)
    assert(getRegA() == 0x00)
    assert(getFlagZ())
    assert(not getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- Half-carry and carry: 0x8F + 0x81 = 0x10
    setRegA(0x8F)
    op_add(0x81)
    assert(getRegA() == 0x10)
    assert(not getFlagZ())
    assert(not getFlagN())
    assert(getFlagH())
    assert(getFlagC())
end)

----------------------
-- prefixed opcodes --
----------------------

local prefixed_opcodes = {}

opcodes[0xCB+1] = function() idle(1); prefixed_opcodes[getOpcode() + 1]() end

-- SLA, 0x20 to 0x27

local function op_sla(src, dest)
    local b = bit.lshift(src(), 1)
    setFlags(false, false, false, b > 0xFF)
    b = bit.band(b, 0xFF)
    if b == 0x00 then setFlagZ() end
    dest(b)
end

do
    local srcs = { getRegB, getRegC, getRegD, getRegE, getRegH, getRegL, getIndRegHL, getRegA }
    local dests = { setRegB, setRegC, setRegD, setRegE, setRegH, setRegL, setIndRegHL, setRegA }

    for i=1, 8 do
        prefixed_opcodes[0x20 + (i-1) + 1] = function() op_sla(srcs[i], dests[i]) end
    end
end

test.unit "vm - SLA" (function()
    test.assert_equal(timeInstruction(prefixed_opcodes[0x27 + 1]), 1)
    test.assert_equal(timeInstruction(prefixed_opcodes[0x26 + 1]), 3)

    resetVM()
    setRegD(0x80)
    -- SLA D
    testRun { 0xCB, 0x22 }
    test.assert_equal(getRegD(), 0x00)
    test.assert_equal(getRegF(), 0x90)  -- zero flag + carry flag
    resetVM()
    setMem(0x80, 0x44); setRegHL(0x80); setRegF(0xF0)
    -- SLA [HL]
    testRun { 0xCB, 0x26 }
    test.assert_equal(getMem(0x80), 0x88)
    test.assert_equal(getRegF(), 0x00)
    resetVM()
end)

-- SWAP, 0x30 to 0x37

local function op_swap(src, dest)
    local l = src()
    local h = bit.lshift(l, 4)
    l = bit.rshift(l, 4)
    local b = h + l
    setFlags(b == 0x00, false, false, false)
    dest(b)
end

do
    local srcs = { getRegB, getRegC, getRegD, getRegE, getRegH, getRegL, getIndRegHL, getRegA }
    local dests = { setRegB, setRegC, setRegD, setRegE, setRegH, setRegL, setIndRegHL, setRegA }

    for i=1, 8 do
        prefixed_opcodes[0x30 + (i-1) + 1] = function() op_swap(srcs[i], dests[i]) end
    end
end

test.unit "vm - SWAP" (function()
    test.assert_equal(timeInstruction(prefixed_opcodes[0x37 + 1]), 1)
    test.assert_equal(timeInstruction(prefixed_opcodes[0x36 + 1]), 3)

    resetVM()
    setRegL(0xF0); setRegF(0xF0)
    -- SWAP L
    testRun { 0xCB, 0x35 }
    test.assert_equal(getRegL(), 0x0F)
    test.assert_equal(getRegF(), 0x00)
    resetVM()
    setMem(0x300, 0x12); setRegHL(0x300)
    -- SWAP [HL]
    testRun { 0xCB, 0x36 }
    test.assert_equal(getMem(0x300), 0x21)
    resetVM()
    setRegB(0x00)
    -- SWAP B
    testRun { 0xCB, 0x30 }
    test.assert_equal(getRegB(), 0x00)
    test.assert_equal(getRegF(), 0x80)
    resetVM()
end)

-- BIT, 0xCB 0x40 to 0xCB 0x7F

local function op_bit(mask, src)
    resetFlagN(); setFlagH()
    if bit.band(src(), mask) == 0 then
        setFlagZ()
    else
        resetFlagZ()
    end
end

for i, mask in ipairs { 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80 } do
    for j, src in ipairs { getRegB, getRegC, getRegD, getRegE, getRegH, getRegL, getIndRegHL, getRegA } do
        prefixed_opcodes[0x40 + (i-1) * 8 + (j-1) + 1] = function() op_bit(mask, src) end
    end
end

test.unit "vm - BIT" (function()
    test.assert_equal(timeInstruction(prefixed_opcodes[0x40 + 1]), 1)
    test.assert_equal(timeInstruction(prefixed_opcodes[0x66 + 1]), 2)

    resetVM()
    setRegE(0x20)
    -- BIT 2 E
    testRun { 0xCB, 0x53 }
    assert(getFlagZ())
    resetVM()
    setRegE(0x20)
    -- BIT 5 E
    testRun { 0xCB, 0x6B }
    assert(not getFlagZ())
    resetVM()
end)

-- RES, 0xCB 0x80 to 0xCB 0xBF

local function op_res(mask, src, dest)
    dest(bit.band(mask, src()))
end

for i, mask in ipairs { 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80 } do
    local srcs = { getRegB, getRegC, getRegD, getRegE, getRegH, getRegL, getIndRegHL, getRegA }
    local dests = { setRegB, setRegC, setRegD, setRegE, setRegH, setRegL, setIndRegHL, setRegA }

    mask = bit.bxor(mask, 0xFF)

    for j=1, 8 do
        prefixed_opcodes[0x80 + (i-1) * 8 + (j-1) + 1] = function() op_res(mask, srcs[j], dests[j]) end
    end
end

test.unit "vm - RES" (function()
    test.assert_equal(timeInstruction(prefixed_opcodes[0x82 + 1]), 1)
    test.assert_equal(timeInstruction(prefixed_opcodes[0x86 + 1]), 3)

    resetVM()
    setRegH(0xF0); setRegF(0x80)
    -- RES 6 H; RES 4 H
    testRun { 0xCB, 0xB4, 0xCB, 0xA4 }
    test.assert_equal(getRegH(), 0xA0)
    test.assert_equal(getRegF(), 0x80)
    resetVM()
    setRegHL(0x0200); setMem(0x200, 0x18)
    -- RES 4 [HL]
    testRun { 0xCB, 0xA6 }
    test.assert_equal(getMem(0x200), 0x08)
    resetVM()
end)

-- SET, 0xCB 0xC0 to 0xCB 0xFF

local function op_set(mask, src, dest)
    dest(bit.bor(mask, src()))
end

for i, mask in ipairs { 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80 } do
    local srcs = { getRegB, getRegC, getRegD, getRegE, getRegH, getRegL, getIndRegHL, getRegA }
    local dests = { setRegB, setRegC, setRegD, setRegE, setRegH, setRegL, setIndRegHL, setRegA }

    for j=1, 8 do
        prefixed_opcodes[0xC0 + (i-1) * 8 + (j-1) + 1] = function() op_set(mask, srcs[j], dests[j]) end
    end
end

test.unit "vm - SET" (function()
    test.assert_equal(timeInstruction(prefixed_opcodes[0xC2 + 1]), 1)
    test.assert_equal(timeInstruction(prefixed_opcodes[0xC6 + 1]), 3)

    resetVM()
    setRegF(0x30)
    -- SET 4 C; SET 2 C
    testRun { 0xCB, 0xE1, 0xCB, 0xD1 }
    test.assert_equal(getRegC(), 0x14)
    test.assert_equal(getRegF(), 0x30)
    resetVM()
    setRegHL(0x0100)
    -- SET 6 [HL]
    testRun { 0xCB, 0xF6 }
    test.assert_equal(getMem(0x0100), 0x40)
end)

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
    assert(getRegB() == getRegA())
    -- indirect get / set instructions take one extra M-cycle
    assert(timeInstruction(0x77) == 2 and timeInstruction(0x46) == 2)

    resetVM()
end)

test.unit "vm - LD part 2" (function()
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
    assert(getRegA() == 0x67)
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

-- return extra goodies

vm.getMem = getMem

return vm
