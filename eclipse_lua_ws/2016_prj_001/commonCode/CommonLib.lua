require("bit")

function hexdump(buf, printFunc)
  local outtable = {}
  for byte=1, #buf, 16 do
    local chunk = buf:sub(byte, byte+15)
    table.insert(outtable, string.format('%08X  ',byte-1))
    local chunkleft = chunk:sub(1, 8)
    local chunkright = chunk:sub(9)
    chunkleft:gsub('.', function (c) table.insert(outtable, string.format('%02X ',string.byte(c))) end)
  table.insert(outtable, ' ')
    chunkright:gsub('.', function (c) table.insert(outtable, string.format('%02X ',string.byte(c))) end)
    table.insert(outtable, string.rep(' ',3*(16-#chunk)))
    table.insert(outtable, ' ' .. chunk:gsub('%W','.') .. '\r\n')
  end

  -- Print out to Print Function if exists... use print otherwise...
  if (nil ~= printFunc) then
    printFunc(table.concat(outtable))
  else
    print(table.concat(outtable))
  end
end

function tohex(str)
  local offset,dif = string.byte("0"), string.byte("A") - string.byte("9") - 1
  local hex = ""
  str = str:upper()
  for a,b in str:gfind "(%S)(%S)%s*" do
  a,b = a:upper():byte() - offset, b:upper():byte()-offset
  a,b = a>10 and a - dif or a, b>10 and b - dif or b
  local code = a*16+b
  hex = hex .. string.char(code)
  end
  return hex
end

function bytesToUInt(input)
  local rst = 0;
  for i = 1, 4, 1 do
    rst = rst*256 + string.byte(input, i, i)
  end
  return rst
end

function bytesToInt(input)
  local rst = 0;
  for i = 1, 4, 1 do
    rst = bit.lshift(rst, 8) + string.byte(input, i, i)
  end
  return rst
end

function bytesToUShort(input)
  local rst = 0;
  for i = 1, 2, 1 do
    rst = rst*256 + string.byte(input, i, i)
  end
  return rst
end

function bytesToShort(input)
  local rst = bytesToUShort(input)
  if (rst > 0x7FFF) then
    return rst - 0x10000
  end
  return rst
end

function intToBytes(value)
  return string.char(bit.band(bit.rshift(value, 24), 0xFF),
      bit.band(bit.rshift(value, 16), 0xFF),
      bit.band(bit.rshift(value, 8), 0xFF),
      bit.band(bit.rshift(value, 0), 0xFF))
end

function shortToBytes(value)
  return string.char(bit.band(bit.rshift(value, 8), 0xFF),
      bit.band(bit.rshift(value, 0), 0xFF))
end

function printTable(tbl, prefix)
  prefix = prefix or ""
  local keyTbl = {}
  for k,v in pairs(tbl) do
    table.insert(keyTbl,k)
  end
  table.sort(keyTbl)
  
  for i,k in pairs(keyTbl) do
    local v = tbl[k]
    if (type(v) == "table") then
      print (prefix .. k .. " = {")
      printTable(v, prefix .. "    ")
      print (prefix .."}")
    elseif (type(v) == "function") then
      print (prefix .. k .. "() is a function")
    else
      print (prefix .. k .. " = " .. tostring(v))
    end
  end
end