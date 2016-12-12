local regPtn = "(%d+)%-(%d+)-(%d+)"
local _,_,y,m,d =string.find("1234-34-56",regPtn)
print(tonumber(y),m,d)

local bit = require("bit")

local x = bit.lshift(1,3)
print(x)

function foo(level)
  local intensity = math.ceil(level * 255 / 100)
  print(intensity)
end

function TemperatureF2C(fahrenheit)
  return (tonumber(fahrenheit) - 32) / 1.8
end

function TemperatureC2F(celsius)
  return tonumber(celsius) * 1.8 + 32
end

print(TemperatureC2F(0),TemperatureC2F(100))