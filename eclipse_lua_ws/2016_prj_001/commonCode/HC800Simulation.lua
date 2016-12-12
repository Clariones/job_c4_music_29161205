require("CommonLib")
socket=require("socket")
require("bit")
local function toHexString(strData)
  if (strData == nil) then return nil  end
  if (#strData == 0) then return "" end
  local rstStr = string.format("%02X", string.byte(strData,1,1))
  for i=2,#strData do
    rstStr = rstStr .. string.format(" %02X", string.byte(strData,i,i))
  end
  return rstStr
end

DEVICES = {}
C4 = {
  networkInfo = {},
  timers = 0,  
}
function C4:ErrorLog(msg) 
  print("                                                                       [ERROR*****]" .. msg) 
end
function C4:KillTimer(timerId)
  print("                                                                       [SYSTEM****]timer ".. timerId .. " is removed")
end
function C4:AddTimer(interval, unit, repear)
  print("                                                                       [SYSTEM****]a timer was created")
  self.timers = self.timers +1
  return self.timers
end
function C4:AddVariable(name, value, dataType)
  print("                                                                       [SYSTEM****]Add property " .. dataType .. " " .. name .. "=" .. value .. ",")
end
function C4:SetVariable(name, value)
  print("                                                                       [SYSTEM****]change property " .. name .. "=" .. value .. ",")
end
function C4:RegisterVariableListener(deviceId, variableId)
  print("                                                                       [SYSTEM****]Watch variable " .. variableId .. " at device " .. deviceId)
end
function C4:UnregisterVariableListener(deviceId, variableId)
  print("                                                                       [SYSTEM****]Don't care variable " .. variableId .. " at device " .. deviceId .. " any more")
end
function C4:UpdateProperty(name, value)
  Properties[name] = tostring(value or "nil")
  print("                                                                       [SYSTEM****]Property[" .. name .. "]=" .. tostring(value or "nil"))
end
function C4:Base64Encode(strData)
  return toHexString()
end
function C4:Base64Decode(strData)
  return tohex(strData)
end
function C4:SendToDevice(deviceId, cmdName, tParams)
  print("                                                                       [SYSTEM****]Invoke command " .. cmdName .. "(" .. Utils.tableToString(tParams) .. ") of device " .. deviceId)
end
function C4:FireEvent(name)
  print("                                                                       [SYSTEM****]Event " .. name .. " occurred ")
end
function C4:CreateNetworkConnection(idBinding, strAddress, strConnectionType )
  print("                                                                       [SYSTEM****]CreateNetworkConnection() with", idBinding, strAddress, strConnectionType )
  self.networkInfo[idBinding] = {host=strAddress, connType=strConnectionType}
end
function C4:GetBoundConsumerDevices(idDevice, idBinding)
  if idDevice == 0 then idDevice = DEVICES.currentDevice end
  local dvc = DEVICES[idDevice]
  local rst = {}
  if dvc.binding[idBinding] == nil then return rst end
  for k,v in pairs(dvc.binding[idBinding]) do
    rst[v] = DEVICES[v].name
  end
  return rst
end
function C4:NetConnect(idBinding, port, connType)
  local netInfo = self.networkInfo[idBinding]
  netInfo.udp = socket.udp()
  netInfo.udp:settimeout(2)
  netInfo.udp:setpeername(netInfo.host, port)
end

function C4:SendToProxy(idBinding, port, strMsg)
end
function C4:SendToSerial(idBinding, strData)
  print("--------------------------Send below data to RS232--------------------------")
  hexdump(strData)
  print("----------------------------------------------------------------------------")
end
function C4:SendToNetwork(idBinding, port, strMsg)
  local netInfo = self.networkInfo[idBinding]
  netInfo.udp:send(strMsg)
end
function C4:ReceiveFromNetwork(idBinding)
  local netInfo = self.networkInfo[idBinding]
  return netInfo.udp:receive()
end
function C4:GetDeviceDisplayName(idDevice)
  return DEVICES[idDevice].name
end
function C4:GetDeviceID()
  return DEVICES.currentDevice
end

TEST = {}
function TEST:Start()
  OnDriverInit()
  OnDriverLateInit()
end
function TEST:Command(name, tParams)
  print("\n\nTesting command " .. name .. " started ================================")
  ExecuteCommand(name, tParams)
  print("Testing command " .. name .. " ended   ================================\n\n")
end
function TEST:Action(name)
  print("\n\nTesting action " .. name .. " started =================================")
  ExecuteCommand("LUA_ACTION", {ACTION=name})
  print("Testing action " .. name .. " ended   =================================\n\n")
end
function TEST:Property(name, value)
  print("\n\nTesting change property " .. name .. " started =================================")
  Properties[name] = tostring(value)
  OnPropertyChanged(name)
  print("Testing change property " .. name .. " ended   =================================\n\n")
end
function TEST:lrc(strData, len)
  len = len or #strData
  local lrc = 0
  for i=1,len do
    lrc = lrc + string.byte(strData,i,i)
  end
  return string.char(bit.band(lrc, 0xFF))
end
function TEST:lrc8(strData)
  local str = tohex(strData)
  return str .. self:lrc(str)
end
function TEST:lrc_16(strData, len)
  len = len or #strData
  local lrc = 0
  for i=1,len do
    lrc = lrc + string.byte(strData,i,i)
  end
  return string.char(TEST:byte1(lrc), TEST:byte0(lrc))
end
function TEST:lrc16(strData)
  local str = tohex(strData)
  return str .. self:lrc_16(str)
end
function TEST:crc16 (buf, length)
  local crc = 0x0000ffff;
  local len = length or #buf
  for byte=1, len do
    local curByte = string.byte(buf,byte,byte)
    crc = bit.band(bit.bxor(crc, curByte), 0xFFFF)
    for j=1,8,1 do
      local f = bit.band(crc, 1)
      crc = bit.band(bit.rshift(crc, 1), 0x7FFF)
      if (f > 0) then
        crc = bit.bxor(crc, 0xa001)
      end
    end
  end
  -- 485 CRC is low-byte first, high-byte then
  return string.char(TEST:byte0(crc))..string.char(TEST:byte1(crc))
end
function TEST:byte0 (data) 
  return bit.band(data, 0xFF)
end

function TEST:byte1 (data)
  return bit.band(bit.rshift(data, 8), 0xFF)
end

function TEST:crc(strData)
  local str = tohex(strData)
  return str .. self:crc16(str)
end
function TEST:AddDevice(deviceInfo)
  DEVICES[deviceInfo.id] = deviceInfo
end
function TEST:ConnectDevice(fromDvcId, fromDvcBinding, toDvcId, toDvcBinding)
  local fromDvc = DEVICES[fromDvcId]
  local toDvc = DEVICES[toDvcId]
  if fromDvc.binding == nil then fromDvc.binding = {} end
  if fromDvc.binding[fromDvcBinding] == nil then
    fromDvc.binding[fromDvcBinding] = {toDvcId}
  else
    table.insert(fromDvc.binding[fromDvcBinding],toDvcId)
  end
  if toDvc.binding == nil then toDvc.binding = {} end
  if toDvc.binding[toDvcBinding] == nil then
    toDvc.binding[toDvcBinding] = {fromDvcId}
  else
    table.insert(toDvc.binding[toDvcBinding],fromDvcId)
  end

end
function TEST:ReceiveData(strData)
  print("\n\nTesting ReceiveData " .. toHexString(strData) .. " started =================================")
  OnSerialDataReceived(strData)
  print("Testing ReceiveData " .. toHexString(strData) .. " ended   =================================\n\n")
end
function TEST:DeviceVariable(deviceId, varId, varValue)
  print("\n\nTesting DeviceVariable " .. deviceId .. "." .. varId .. "=" .. tostring(varValue or "nil") .. " started =================================")
  OnWatchedVariableChanged(deviceId, varId, varValue)
  print("Testing DeviceVariable " .. deviceId .. "." .. varId .. "=" .. tostring(varValue or "nil") .. " ended   =================================\n\n")
end
function TEST:ReceiveFromNetwork(idBinding)
  local data,msg=C4:ReceiveFromNetwork(idBinding)
  if (data ~= nil) then
    ReceivedFromNetwork(idBinding, 0, data)
  else
    print("Error when wait for receive from network: " .. msg)
  end
end
function TEST:WorkOnDevice(idDevice)
  DEVICES.currentDevice = idDevice
end
function TEST:Proxy(idBinding, strCommand, tParams)
  print("\n\nTesting Receive from proxy " .. strCommand.. "(" .. DriverLib.tableToString(tParams,"").. ") started =================================")
  ReceivedFromProxy(idBinding, strCommand, tParams)
  print("Testing Receive from proxy " .. strCommand .. "(" .. DriverLib.tableToString(tParams,"").. ") ended   =================================\n\n")
end