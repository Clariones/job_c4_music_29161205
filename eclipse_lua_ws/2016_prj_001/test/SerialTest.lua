-- to fix luars232 issue
-- luadist remove rs232
-- luadis install rs232
--require("xopen")
require("HC800Simulation")
local socket = require("socket")

function readRs232(rs232, times)
  for i=1,times do
    local read_len = 250 -- read one byte
    local timeout = 1000 -- in miliseconds
    local err, data_read, size = rs232:read(read_len, timeout)
--    print ("err is " .. getErrMsg(err))
    if data_read~=nil then
      print("received from RS232")
      hexdump(data_read)
      return
    else
      --print("read nothing")
    end
  end
  print("Nothing read from RS232")
end

local function main()

  local rs232 = require("luars232")
  
  --local pop3 = require("pop3")
  
  --rs232.init()
  
  local port_name="COM3"
  local e, p = rs232.open(port_name)
  if e ~= rs232.RS232_ERR_NOERROR then
  -- handle error
    print(string.format("can't open serial port '%s', error: '%s'\n",
        port_name, rs232.error_tostring(e)))
    return
  end
  assert(p:set_baud_rate(rs232.RS232_BAUD_9600) == rs232.RS232_ERR_NOERROR)
  assert(p:set_data_bits(rs232.RS232_DATA_8) == rs232.RS232_ERR_NOERROR)
  assert(p:set_parity(rs232.RS232_PARITY_NONE) == rs232.RS232_ERR_NOERROR)
  assert(p:set_stop_bits(rs232.RS232_STOP_1) == rs232.RS232_ERR_NOERROR)
  assert(p:set_flow_control(rs232.RS232_FLOW_OFF)  == rs232.RS232_ERR_NOERROR)

  print ("start to read from rs232")
  
  ----------------------------
--  local str = TEST:lrc16("7E 01 F9 04 02 23 45")
--    hexdump(str)
--    p:write(str)
    
  ----------------------------------------------
  local cmdStrs = {
    "00 E2 09 08 01 02 03 04 05 06 07 08 FF DD",
    "55 AA 01 AB CD",
    "00 E1 09 01 11 22 33 44 55 66 77 88 FF DD",
--    "55 AA 02 AB CD",
--    "55 AA 03 AB CD",
--    "55 AA 04 AB CD",
--    "55 AA 05 AB CD",
--    "00 E3 09 20 11 22 33 44 55 66 77 88 FF DD",
--    "55 AA 06 AB CD",
--    "55 AA 07 AB CD",
  }

  local pos = 1;
  
  while true do
  local str = tohex(cmdStrs[pos])
    print("sent")
    hexdump(str)
    p:write(str)
    pos = pos +1
    if (pos > #cmdStrs) then pos = 1 end
    readRs232(p, 8)
  end
  
 
  print("hello world")
  --print(package.path..'\n'..package.cpath)
end

function getErrMsg(errCode)
  local msg = { "RS232_ERR_NOERROR",
  "RS232_ERR_UNKNOWN",
  "RS232_ERR_OPEN",
  "RS232_ERR_CLOSE", 
  "RS232_ERR_FLUSH", 
  "RS232_ERR_CONFIG", 
  "RS232_ERR_READ", 
  "RS232_ERR_WRITE", 
  "RS232_ERR_SELECT", 
  "RS232_ERR_TIMEOUT", 
  "RS232_ERR_IOCTL", 
  "RS232_ERR_PORT_CLOSED", }
  return tostring(msg[errCode+1])
end

main()
