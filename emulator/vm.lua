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

local function setSP(x) sp = x end
local function getSP() return sp end

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

opcodes[0x00+1] = function() end

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

local function op_rl(value)
    local b7 = bit.band(value,0x80) ~= 0
    local C = getFlagC() and 1 or 0
    local result = (bit.lshift(value,1)+C)%0x100
    setFlags(result == 0, false, false, b7)
    return result
end
local function op_rr(value)
    local b0 = bit.band(value,0x01)
    local C = getFlagC() and 1 or 0
    local result = (bit.rshift(value,1)+bit.lshift(C,7))%0x100
    setFlags(result == 0, false, false, b0==1)
    return result
end
local function op_rlc(value)
    local b7 = bit.band(value,0x80) ~= 0
    local result = (bit.lshift(value,1)+(b7 and 1 or 0))%0x100
    setFlags(result == 0, false, false, b7)
    return result
end
local function op_rrc(value)
    local b0 = bit.band(value,0x01)
    local result = (bit.rshift(value,1)+bit.lshift(b0,7))%0x100
    setFlags(result == 0, false, false, b0==1)
    return result
end

-- RLCA, RLA, RRCA, RRA, 0x07 0x17 0x0F 0x1F
opcodes[0x07 + 1] = function()
    setRegA(op_rlc(getRegA()))
    resetFlagZ()
end
opcodes[0x17 + 1] = function()
    setRegA(op_rl(getRegA()))
    resetFlagZ()
end
opcodes[0x0F + 1] = function()
    setRegA(op_rrc(getRegA()))
    resetFlagZ()
end
opcodes[0x1F + 1] = function()
    setRegA(op_rr(getRegA()))
    resetFlagZ()
end

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

local function op_adc(value)
    local a = getRegA()
    local carry = getFlagC() and 1 or 0
    local result = a + value + carry

    setRegA(result % 0x100)
    setFlags(
        result % 0x100 == 0,
        false,
        (a % 0x10) + (value % 0x10) + carry > 0x0F,
        result > 0xFF
    )
end

-- ADC, 0x88-0x8F
opcodes[0x88 + 1] = function() op_adc(getRegB()) end
opcodes[0x89 + 1] = function() op_adc(getRegC()) end
opcodes[0x8A + 1] = function() op_adc(getRegD()) end
opcodes[0x8B + 1] = function() op_adc(getRegE()) end
opcodes[0x8C + 1] = function() op_adc(getRegH()) end
opcodes[0x8D + 1] = function() op_adc(getRegL()) end
opcodes[0x8E + 1] = function() op_adc(getIndRegHL()) end
opcodes[0x8F + 1] = function() op_adc(getRegA()) end

local function op_sub(value)
    local a = getRegA()
    local result = a - value

    setRegA(result % 0x100)
    setFlags(
        result % 0x100 == 0,
        true,
        (a % 0x10) < (value % 0x10),
        a < value
    )
end

-- SUB, 0x90-0x97
opcodes[0x90 + 1] = function() op_sub(getRegB()) end
opcodes[0x91 + 1] = function() op_sub(getRegC()) end
opcodes[0x92 + 1] = function() op_sub(getRegD()) end
opcodes[0x93 + 1] = function() op_sub(getRegE()) end
opcodes[0x94 + 1] = function() op_sub(getRegH()) end
opcodes[0x95 + 1] = function() op_sub(getRegL()) end
opcodes[0x96 + 1] = function() op_sub(getIndRegHL()) end
opcodes[0x97 + 1] = function() op_sub(getRegA()) end

local function op_sbc(value)
    local a = getRegA()
    local carry = getFlagC() and 1 or 0
    local result = a - value - carry

    setRegA(result % 0x100)
    setFlags(
        result % 0x100 == 0,
        true,
        (a % 0x10) < ((value % 0x10) + carry),
        a < (value + carry)
    )
end

-- SBC, 0x98-0x9F
opcodes[0x98 + 1] = function() op_sbc(getRegB()) end
opcodes[0x99 + 1] = function() op_sbc(getRegC()) end
opcodes[0x9A + 1] = function() op_sbc(getRegD()) end
opcodes[0x9B + 1] = function() op_sbc(getRegE()) end
opcodes[0x9C + 1] = function() op_sbc(getRegH()) end
opcodes[0x9D + 1] = function() op_sbc(getRegL()) end
opcodes[0x9E + 1] = function() op_sbc(getIndRegHL()) end
opcodes[0x9F + 1] = function() op_sbc(getRegA()) end

-- ADD n SUB n ADC n SBC n, 0xC6 0xD6 0xCE 0xDE
opcodes[0xC6 + 1] = function() op_add(getOpcode()); idle(1) end
opcodes[0xD6 + 1] = function() op_sub(getOpcode()); idle(1) end
opcodes[0xCE + 1] = function() op_adc(getOpcode()); idle(1) end
opcodes[0xDE + 1] = function() op_sbc(getOpcode()); idle(1) end

-- 16-bit INC

local function op_inc_16(src, dest)
    idle(1)
    dest(bit.band(src() + 1, 0xFFFF))
end

opcodes[0x03 + 1] = function() op_inc_16(getRegBC, setRegBC) end
opcodes[0x13 + 1] = function() op_inc_16(getRegDE, setRegDE) end
opcodes[0x23 + 1] = function() op_inc_16(getRegHL, setRegHL) end
opcodes[0x33 + 1] = function() op_inc_16(getSP, setSP) end

local function op_dec_16(src, dest)
    idle(1)
    local b = src()
    dest(b == 0 and 0xFFFF or b - 1)
end

opcodes[0x0B + 1] = function() op_dec_16(getRegBC, setRegBC) end
opcodes[0x1B + 1] = function() op_dec_16(getRegDE, setRegDE) end
opcodes[0x2B + 1] = function() op_dec_16(getRegHL, setRegHL) end
opcodes[0x3B + 1] = function() op_dec_16(getSP, setSP) end

-- LD 16-bit
opcodes[0x01 + 1] = function() 
    local nn_lsb = getOpcode()
    local nn_msb = getOpcode()
    local nn = 256*nn_msb + nn_lsb
    setRegBC(nn)
    idle(2)
end
opcodes[0x11 + 1] = function() 
    local nn_lsb = getOpcode()
    local nn_msb = getOpcode()
    local nn = 256*nn_msb + nn_lsb
    setRegDE(nn)
    idle(2)
end
opcodes[0x21 + 1] = function() 
    local nn_lsb = getOpcode()
    local nn_msb = getOpcode()
    local nn = 256*nn_msb + nn_lsb
    setRegHL(nn)
    idle(2)
end
opcodes[0x31 + 1] = function() 
    local nn_lsb = getOpcode()
    local nn_msb = getOpcode()
    local nn = 256*nn_msb + nn_lsb
    setSP(nn)
    idle(2)
end

opcodes[0x08 + 1] = function()
    local nn_lsb = getOpcode()
    local nn_msb = getOpcode()
    local nn = 256 * nn_msb + nn_lsb
    local sp = getSP()

    setMem(nn, sp % 0x100)
    setMem((nn + 1) % 0x10000, math.floor(sp / 0x100))
    idle(4)
end

opcodes[0xF8 + 1] = function()
    local offset = getOpcode()
    local sp = getSP()
    local result = (sp + toSigned8(offset)) % 0x10000
    setFlags(
        false,
        false,
        (sp % 0x10) + (offset % 0x10) > 0x0F,
        (sp % 0x100) + offset > 0xFF
    )
    setRegHL(result)
    idle(2)
end
opcodes[0xF9 + 1] = function() 
    setSP(getRegHL())
    idle(1)
end

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

-- SRA, 0x28 to 0x2F

local function op_sra(src, dest)
    local b = src()
    setFlags(false, false, false, bit.band(b, 0x01) ~= 0)
    b = bit.band(b, 0x80) + bit.rshift(b, 1)
    if b == 0x00 then setFlagZ() end
    dest(b)
end

do
    local srcs = { getRegB, getRegC, getRegD, getRegE, getRegH, getRegL, getIndRegHL, getRegA }
    local dests = { setRegB, setRegC, setRegD, setRegE, setRegH, setRegL, setIndRegHL, setRegA }

    for i=1, 8 do
        prefixed_opcodes[0x28 + (i-1) + 1] = function() op_sra(srcs[i], dests[i]) end
    end
end

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

-- SRL, 0x38 to 0x3F

local function op_srl(src, dest)
    local b = src()
    setFlags(false, false, false, bit.band(b, 0x01) ~= 0)
    b = bit.rshift(b, 1)
    if b == 0x00 then setFlagZ() end
    dest(b)
end

do
    local srcs = { getRegB, getRegC, getRegD, getRegE, getRegH, getRegL, getIndRegHL, getRegA }
    local dests = { setRegB, setRegC, setRegD, setRegE, setRegH, setRegL, setIndRegHL, setRegA }

    for i=1, 8 do
        prefixed_opcodes[0x38 + (i-1) + 1] = function() op_srl(srcs[i], dests[i]) end
    end
end

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

-- return extra goodies

vm.getMem = getMem

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

test.unit "vm - ADC" (function()
    -- Normal addition, carry clear: 0x12 + 0x23 = 0x35
    setRegA(0x12)
    resetFlagC()
    op_adc(0x23)
    assert(getRegA() == 0x35)
    assert(not getFlagZ())
    assert(not getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- Carry-in contributes to the result: 0x12 + 0x23 + 1 = 0x36
    setRegA(0x12)
    setFlagC()
    op_adc(0x23)
    assert(getRegA() == 0x36)
    assert(not getFlagZ())
    assert(not getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- Half-carry caused by carry-in: 0x0F + 0x00 + 1 = 0x10
    setRegA(0x0F)
    setFlagC()
    op_adc(0x00)
    assert(getRegA() == 0x10)
    assert(not getFlagZ())
    assert(not getFlagN())
    assert(getFlagH())
    assert(not getFlagC())

    -- Full carry and zero result: 0xFF + 0x00 + 1 = 0x00
    setRegA(0xFF)
    setFlagC()
    op_adc(0x00)
    assert(getRegA() == 0x00)
    assert(getFlagZ())
    assert(not getFlagN())
    assert(getFlagH())
    assert(getFlagC())

    -- Full carry without half-carry: 0xF0 + 0x0F + 1 = 0x00
    setRegA(0xF0)
    setFlagC()
    op_adc(0x0F)
    assert(getRegA() == 0x00)
    assert(getFlagZ())
    assert(not getFlagN())
    assert(getFlagH())
    assert(getFlagC())

    -- No carry-in, maximum result: 0xFE + 0x01 = 0xFF
    setRegA(0xFE)
    resetFlagC()
    op_adc(0x01)
    assert(getRegA() == 0xFF)
    assert(not getFlagZ())
    assert(not getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- Zero plus zero plus carry-in: result is one
    setRegA(0x00)
    setFlagC()
    op_adc(0x00)
    assert(getRegA() == 0x01)
    assert(not getFlagZ())
    assert(not getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())
end)

test.unit "vm - SUB" (function()
    -- Normal subtraction: 0x35 - 0x12 = 0x23
    setRegA(0x35)
    op_sub(0x12)
    assert(getRegA() == 0x23)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- Equal operands: 0x42 - 0x42 = 0x00
    setRegA(0x42)
    op_sub(0x42)
    assert(getRegA() == 0x00)
    assert(getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- Half-borrow only: 0x10 - 0x01 = 0x0F
    setRegA(0x10)
    op_sub(0x01)
    assert(getRegA() == 0x0F)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(getFlagH())
    assert(not getFlagC())

    -- Full borrow: 0x00 - 0x01 = 0xFF
    setRegA(0x00)
    op_sub(0x01)
    assert(getRegA() == 0xFF)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(getFlagH())
    assert(getFlagC())

    -- Full borrow without half-borrow: 0x10 - 0x20 = 0xF0
    setRegA(0x10)
    op_sub(0x20)
    assert(getRegA() == 0xF0)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(getFlagC())

    -- Subtract zero: result unchanged
    setRegA(0xA5)
    op_sub(0x00)
    assert(getRegA() == 0xA5)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())
end)

test.unit "vm - SBC" (function()
    -- Normal subtraction with carry clear: 0x35 - 0x12 = 0x23
    setRegA(0x35)
    resetFlagC()
    op_sbc(0x12)
    assert(getRegA() == 0x23)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- Carry-in contributes to subtraction: 0x35 - 0x12 - 1 = 0x22
    setRegA(0x35)
    setFlagC()
    op_sbc(0x12)
    assert(getRegA() == 0x22)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- Half-borrow caused by carry-in: 0x10 - 0x00 - 1 = 0x0F
    setRegA(0x10)
    setFlagC()
    op_sbc(0x00)
    assert(getRegA() == 0x0F)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(getFlagH())
    assert(not getFlagC())

    -- Full borrow: 0x00 - 0x00 - 1 = 0xFF
    setRegA(0x00)
    setFlagC()
    op_sbc(0x00)
    assert(getRegA() == 0xFF)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(getFlagH())
    assert(getFlagC())

    -- Zero result: 0x01 - 0x00 - 1 = 0x00
    setRegA(0x01)
    setFlagC()
    op_sbc(0x00)
    assert(getRegA() == 0x00)
    assert(getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- Edge case: 0x00 - 0xFF - 1 = 0x00 modulo 256
    setRegA(0x00)
    setFlagC()
    op_sbc(0xFF)
    assert(getRegA() == 0x00)
    assert(getFlagZ())
    assert(getFlagN())
    assert(getFlagH())
    assert(getFlagC())

    -- Carry clear: 0xFF - 0x01 = 0xFE
    setRegA(0xFF)
    resetFlagC()
    op_sbc(0x01)
    assert(getRegA() == 0xFE)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())
end)

test.unit "vm - n arithmetic" (function()
    -- ADD A, d8: 0x12 + 0x23 = 0x35
    resetVM()
    testRun { 0xC6, 0x23 }
    setRegA(0x12)
    resetFlagZ(); resetFlagN(); resetFlagH(); resetFlagC()
    resetVM()
    setRegA(0x12)
    testRun { 0xC6, 0x23 }
    assert(getRegA() == 0x35)
    assert(not getFlagZ())
    assert(not getFlagN())
    assert(not getFlagH())
    assert(not getFlagC())

    -- SUB d8: 0x10 - 0x01 = 0x0F
    resetVM()
    setRegA(0x10)
    testRun { 0xD6, 0x01 }
    assert(getRegA() == 0x0F)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(getFlagH())
    assert(not getFlagC())

    -- ADC A, d8: 0x0F + 0x00 + carry = 0x10
    resetVM()
    setRegA(0x0F)
    setFlagC()
    testRun { 0xCE, 0x00 }
    assert(getRegA() == 0x10)
    assert(not getFlagZ())
    assert(not getFlagN())
    assert(getFlagH())
    assert(not getFlagC())

    -- SBC A, d8: 0x10 - 0x00 - carry = 0x0F
    resetVM()
    setRegA(0x10)
    setFlagC()
    testRun { 0xDE, 0x00 }
    assert(getRegA() == 0x0F)
    assert(not getFlagZ())
    assert(getFlagN())
    assert(getFlagH())
    assert(not getFlagC())
end)

test.unit "vm - 16 bit INC and DEC" (function()
    test.assert_equal(timeInstruction(0x13), 2)
    test.assert_equal(timeInstruction(0x1B), 2)

    test.label "INC"
    resetVM()
    setRegBC(0x0200)
    -- INC BC, INC BC
    testRun { 0x03, 0x03 }
    test.assert_equal(getRegBC(), 0x0202)

    test.label "DEC"
    resetVM()
    setRegHL(0x0002); setRegF(0x40)
    -- DEC HL, DEC HL, DEC HL
    testRun { 0x2B, 0x2B, 0x2B }
    test.assert_equal(getRegHL(), 0xFFFF)
    test.assert_equal(getRegF(), 0x40)
    resetVM()
end)

test.unit "vm - LD 16-bit instructions" (function()
    -- LD BC, 0x1234
    resetVM()
    testRun({0x01, 0x34, 0x12})
    assert(getRegBC() == 0x1234)

    -- LD DE, 0x5678
    resetVM()
    testRun({0x11, 0x78, 0x56})
    assert(getRegDE() == 0x5678)

    -- LD HL, 0xABCD
    resetVM()
    testRun({0x21, 0xCD, 0xAB})
    assert(getRegHL() == 0xABCD)

    -- LD SP, 0xFFFE
    resetVM()
    testRun({0x31, 0xFE, 0xFF})
    assert(getSP() == 0xFFFE)

    -- LD (0xC000), SP; SP = 0x1234
    resetVM()
    setSP(0x1234)
    testRun({0x08, 0x00, 0xC0})
    assert(getMem(0xC000) == 0x34)
    assert(getMem(0xC001) == 0x12)

    -- LD HL, SP+e8; SP = 0xFFF8, offset = +8
    resetVM()
    setSP(0xFFF8)
    testRun({0xF8, 0x08})
    assert(getRegHL() == 0x0000)
    assert(not getFlagZ())
    assert(not getFlagN())
    assert(getFlagH())
    assert(getFlagC())

    -- LD HL, SP+e8; SP = 0x0001, offset = -1 (0xFF)
    resetVM()
    setSP(0x0001)
    testRun({0xF8, 0xFF})
    assert(getRegHL() == 0x0000)
    assert(not getFlagZ())
    assert(not getFlagN())
    assert(getFlagH())
    assert(getFlagC())

    -- LD SP, HL
    resetVM()
    setRegHL(0xBEEF)
    testRun({0xF9})
    assert(getSP() == 0xBEEF)
end)

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

test.unit "vm - SRA" (function()
    test.assert_equal(timeInstruction(prefixed_opcodes[0x2F + 1]), 1)
    test.assert_equal(timeInstruction(prefixed_opcodes[0x2E + 1]), 3)

    resetVM()
    setRegD(0x01); setRegF(0x40)
    -- SRA D
    testRun { 0xCB, 0x2A }
    test.assert_equal(getRegD(), 0x00)
    test.assert_equal(getRegF(), 0x90)
    resetVM()
    setMem(0x100, 0x45); setRegHL(0x100); setRegF(0xE0)
    -- SRA [HL]
    testRun { 0xCB, 0x2E }
    test.assert_equal(getMem(0x100), 0x22)
    test.assert_equal(getRegF(), 0x10)
    resetVM()
end)

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

test.unit "vm - SRL" (function()
    test.assert_equal(timeInstruction(prefixed_opcodes[0x3F + 1]), 1)
    test.assert_equal(timeInstruction(prefixed_opcodes[0x3E + 1]), 3)

    resetVM()
    setRegH(0xFF); setRegF(0xF0)
    -- SRL H
    testRun { 0xCB, 0x3C }
    test.assert_equal(getRegH(), 0x7F)
    test.assert_equal(getRegF(), 0x10)
    resetVM()
    setMem(0x200, 0x01); setRegHL(0x200); setRegF(0x20)
    -- SRL [HL]
    testRun { 0xCB, 0x3E }
    test.assert_equal(getMem(0x200), 0x00)
    test.assert_equal(getRegF(), 0x90)
    resetVM()
end)

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

return vm
