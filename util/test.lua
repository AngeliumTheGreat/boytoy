local test = {}

local tests_ran = {}
local tests_failed = {}

test.failed = tests_failed

local label

local function unittest(name)
   return function(func)
      if tests_ran[name] then return end
      tests_ran[name] = true

      label = nil

      local result, trace = pcall(func)

      if result then
         print("[TEST] [SUCCESS] " .. name)
      else
         print("[TEST] [FAILURE] " .. name .. (label and " -- " .. label or ""))
         print(trace)
         tests_failed[name] = trace
      end
   end
end

local function dummy()
   return function() end
end

local unitfunc = dummy

function test.unit(...)
   return unitfunc(...)
end

function test.enable()
   print "==== Unit tests enabled ===="
   unitfunc = unittest
end

function test.disable()
   print "==== Unit tests disabled ===="
   unitfunc = dummy
end

local function equal(a, b)
   if type(a) == "table" and type(b) == "table" then
      for k, v in pairs(a) do
         if not equal(v, b[k]) then
            return false
         end
      end
      return true
   else
      return a == b
   end
end

function test.assert_error(func, ...)
   assert(not pcall(func, ...))
end

function test.assert_equal(a, b)
   assert(equal(a, b), string.format("values are unequal: got %q and %q", a, b))
end

function test.assert_unequal(a, b)
   assert(not equal(a, b), string.format("values are equal: got %q and %q", a, b))
end

function test.label(content)
   label = content
end

return test
