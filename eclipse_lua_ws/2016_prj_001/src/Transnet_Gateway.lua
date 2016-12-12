DEVICE_CFG = {
  toAddress = 0,
  srcAddress = 0,
  controlAll = false,
  sceneNo = 2,
  areaNo = 0,
  relayBatchOnOff = "00000000",
  relayBatchMask = "11111111",
  protocolVersion = 0x64,
  CONNECTION_RS232 = 1,
  CONNECTION_TRANSNET = 2,
  CONNECTION_RELAY_BASE = 2,
  eventCnt = 1,
  FanCoilControlCmdParamRule = {
    ["modbusDeviceName"] = {type="Number", range={0,0xFFFF}},
    ["state"]={type="List", values={["NoChange"]=0, ["Off"]=1, ["On"]=2}},
    ["mode"]={type="List", values={["NoChange"]=0, ["Cool"]=1, ["Heat"]=2,["FanOnly"]=3,["Dehumidifier"]=4}},
    ["temperature"] = {type="Number", range={0,0xFFFF}},
    ["fanSpeed"]={type="List", values={["NoChange"]=0, ["High"]=1, ["Medium"]=2,["Low"]=3,["Auto"]=4,["UltraLow"]=5,["UltraHigh"]=6,["Off"]=7}},
  },
  FanCoilReplyValues = {
    ["state"] = {[0]=Utils.OFF, [1] = Utils.ON},
    ["mode"] = {[0]="Cool", [1]="Heat", [2]="FanOnly", [3]="Dehumidifier"},
    ["fanSpeed"]={[0]="NoChange", [1]="High", [2]="Medium",[3]="Low",[4]="Auto",[5]="UltraLow",[6]="UltraHigh",[7]="Off"},
  },
  connectedDrivers = {},
  connectedDevices = {
    DIMMER = {},
    RELAY = {},
    FAN_COIL = {},
    ENVIRONMENT = {},
  },
  properties = {
    ["To Address"] = function(name, value) DEVICE_CFG.toAddress = tonumber(value) or DEVICE_CFG.toAddress end,
    ["Source Address"] = function(name, value) DEVICE_CFG.srcAddress = tonumber(value) or DEVICE_CFG.srcAddress end,
    ["Scene Number"] = function(name, value) DEVICE_CFG.sceneNo = tonumber(value) or DEVICE_CFG.sceneNo end,
    ["Area Number"] = function(name, value) DEVICE_CFG.areaNo = tonumber(value) or DEVICE_CFG.areaNo end,
    ["Relay Batch On Off"] = function(name, value)
        if (not isValidRelayBatchArg(value)) then return end
        DEVICE_CFG.relayBatchOnOff = value
      end,
    ["Relay Batch Mask"] = function(name, value)
        if (not isValidRelayBatchArg(value)) then return end
        DEVICE_CFG.relayBatchMask = value
      end,
    
  }
}

RELAY_PARAM_MSG = "For example, \"11110000\", Relay on/Off and Mask should be 8-digit string"

function OnRS232MessageRecieved(idBinding, strData)
  local msg = decodeMessage(strData)
  if (msg == nil) then 
    if (Utils.dumpData == Utils.DUMP_DATA_ALL) then
      print("There is some data in RS232 bus, but not for me:")
      hexdump(strData)
    end
    return
  end
  if (Utils.dumpData == Utils.DUMP_DATA_RECIEVED) or (Utils.dumpData == Utils.DUMP_DATA_ALL) then
    print("Recieved data from RS232 bus:")
    hexdump(strData)
  end
  cmdResponseProcess(idBinding, msg)
end
function promptMsg(strMsg)
  if (strMsg == nil) then return end
  C4:UpdateProperty("Prompt Message",strMsg)
end
function isValidRelayBatchArg(value)
  if (string.len(value) ~= 8) then promptMsg(RELAY_PARAM_MSG) return false end
  for i=1,8 do
    local char = string.sub(value,i,i)
    if (char ~= '0') and (char ~= '1') then
      promptMsg(RELAY_PARAM_MSG)
      return false
    end
  end
  return true
end
function convertToRelayParam(strValue)
  if (strValue == nil) then return nil end
  if (not isValidRelayBatchArg(strValue)) then return nil end
  local rst = 0
  for i=1,8 do
    local char = string.sub(strValue, i, i)
    if (char == '1') then
      rst = rst + bit.lshift(1, 9-i)
    end
  end
  return rst
end
function makeSendCmdWithAddr(toAddr, srcAddr, strCmdData)
  if (type(toAddr) ~= 'number') or (type(srcAddr) ~= 'number') then
    print("toAddr or srcAddr not number")
    print("makeSendCmd():", type(toAddr), type(srcAddr), type(strCmdData))
    return
  end
  return string.char(0xAA, 0x55, toAddr, srcAddr, #strCmdData) .. strCmdData .. string.char(0x0D, 0x0A)
end
function makeSendCmd(strCmdData, canToAll)
  if (canToAll and DEVICE_CFG.controlAll) then
    return makeSendCmdWithAddr(0xFF, DEVICE_CFG.srcAddress, strCmdData)
  else
    return makeSendCmdWithAddr(DEVICE_CFG.toAddress, DEVICE_CFG.srcAddress, strCmdData)
  end
end
function getFanCoilControlCmd(tParams)
  local paramRule = DEVICE_CFG.FanCoilControlCmdParamRule
  local errMsg = Utils.verifyTableParams(paramRule,tParams)
  if (errMsg ~= nil) then
    print("Wrong parameter: " .. errMsg)
    return nil
  end
  local setTemp = math.floor(tParams.temperature * 10)
  return string.char(Utils.byte0(tParams.modbusDeviceName),Utils.byte1(tParams.modbusDeviceName),
            paramRule.state.values[tParams.state],
            paramRule.mode.values[tParams.mode],
            Utils.byte0(setTemp),Utils.byte1(setTemp),
            paramRule.fanSpeed.values[tParams.fanSpeed], 0)
end

function decodeMessage(strCmd)
  local len = #strCmd
  if (len < 9) then return nil end  -- at least 9 bytes
  local startCode = Utils.LEtoUShort(string.sub(strCmd,1,2))
  local endCode = Utils.LEtoUShort(string.sub(strCmd,len-1,len))
  local dataSize = string.byte(strCmd,5,5)
  if (startCode ~= 0x55AA) or (endCode ~= 0x0A0D) then return nil end
  if (len-7) ~= dataSize then return nil end
  local fromAddr = string.byte(strCmd,4,4)
  local replyToAddr = string.byte(strCmd,3,3)
  if (replyToAddr ~= DEVICE_CFG.srcAddress) then return nil end
  local result = {deviceAddr=fromAddr}
  result.cmdCode = string.byte(strCmd,6,6)
  result.cmdData = string.sub(strCmd,7,len-2)
  return result
end

function cmdResponseProcess(idBinding, msg)
--  print("TODO: process command response")
  local cmd = {addr=msg.deviceAddr, code=msg.cmdCode, data=msg.cmdData}
  local cmdHandlers = {
    [0x07] = handlerReplyDimmerIntensity,
    [0x92] = {[4]=handlerEventDimmerState,[2]=handlerEventRelayState,[12]=handlerEventDimmerState},
    [0x06] = handlerReplyRelayState,
    [0x52] = handlerReplyFanCoil,
    [0x56] = handlerReplyEnvStatus,
  }
  local cmdHandler = cmdHandlers[cmd.code]
  if (cmdHandler == nil) then return end
  if (type(cmdHandler) == "function") then
    cmdHandler(idBinding, cmd.addr, cmd.data)
  elseif (type(cmdHandler) == "table") then
    cmdHandler = cmdHandler[#(cmd.data)]
    if (cmdHandler == nil) then return end
    cmdHandler(idBinding, cmd.addr, cmd.data)
  end
end
function handlerReplyDimmerIntensity(idBinding, addr, data)
  -- 3.1. Read Dimmer IntensityRead
  local len = #data
  for i=3,len do
    updateDimmerState(i-2, string.byte(data,i,i))
  end
end
function handlerEventDimmerState(idBinding, addr, data)
  -- 3.2. Dimmer Auto State Send
  local len = #data
  for i=1,len do
    updateDimmerState(i, string.byte(data,i,i))
  end
end
function _handlerRelayState(bState)
  for i=1,8 do
    local state = bit.band(bit.rshift(bState, i-1), 1)
    updateRelayState(i, state)
  end
end
function handlerReplyRelayState(idBinding, addr, data)
  -- 4.1. Read Relay state 
  local byteState = string.byte(data,3,3)
  _handlerRelayState(byteState)
end
function handlerEventRelayState(idBinding, addr, data)
  -- 4.2. Relay Auto State Send 
  local byteState = string.byte(data,1,1)
  _handlerRelayState(byteState)
end
function handlerReplyFanCoil(idBinding, addr, data)
  -- 5.1. Read Fan Coil
  local function _handlerBit(data,bitPos, val0, val1)
    return (bit.band(bit.rshift(data, bitPos), 1) == 0) and val0 or val1
  end
  local function _covertFromList(nVal, tList)
    return tList[nVal]
  end
  local result = {}
  result.modbusDeviceName = Utils.LEtoUShort(string.sub(data,3,4))
  
  result.state = _covertFromList(string.byte(data,5,5),DEVICE_CFG.FanCoilReplyValues["state"])
  result.mode = _covertFromList(string.byte(data,6,6),DEVICE_CFG.FanCoilReplyValues["mode"])
  result.fanSpeed = _covertFromList(string.byte(data,7,7),DEVICE_CFG.FanCoilReplyValues["fanSpeed"])
  if (result.state == nil) or (result.state == nil) or (result.state == nil) then
    print("Cannot parse fan-coil response: state,mode,fanspeed=", string.byte(data,5,7))
    return
  end
  
  result.setTemperature = Utils.LEtoUShort(string.sub(data,9,10)) / 10
  result.roomTemperature = Utils.LEtoUShort(string.sub(data,11,12)) / 10
  local coilState = Utils.LEtoUShort(string.sub(data,13,14))
  result.coilCoolOn = _handlerBit(coilState, 0, Utils.OFF, Utils.ON)
  result.coilHeatOn = _handlerBit(coilState, 1, Utils.OFF, Utils.ON)
  result.coilFanHighSpeed = _handlerBit(coilState, 2, Utils.OFF, Utils.ON)
  result.coilFanMidSpeed = _handlerBit(coilState, 3, Utils.OFF, Utils.ON)
  result.coilFanLowSpeed = _handlerBit(coilState, 4, Utils.OFF, Utils.ON)
  result.coilKBLockSpeed = _handlerBit(coilState, 5, Utils.OFF, Utils.ON)
  result.coilMode = _handlerBit(coilState, 6, "Manual", "Auto")
  updateHVACState(addr, result)
end
function handlerReplyEnvStatus(idBinding, addr, data)
  -- 5.4. Reply Environmental Status & Auto Send
  local result = {}
  result.modbusDeviceName = Utils.LEtoUShort(string.sub(data,3,4))
  result.roomTemperature = Utils.LEtoUShort(string.sub(data,5,6))
  result.co2PPM = Utils.LEtoUShort(string.sub(data,7,8))
  result.pm2d5 = Utils.LEtoUShort(string.sub(data,9,10))
  result.humidity = string.byte(data,11,11)
  updateEnvState(addr, result)
end

function updateDimmerState(dimmerId, intensity)
--  print(string.format("TODO: Dimmer %d intensity is %d(%.1f%%)",dimmerId, intensity, math.ceil(intensity/255*1000)/10))
  local connDeviceId = DEVICE_CFG.connectedDevices.DIMMER[dimmerId]
  if (connDeviceId == nil) then
    Dbg:Debug("Dimmer " .. dimmerId .. " not connected")
    return
  end
  local connDriver = DEVICE_CFG.connectedDrivers[connDeviceId]
  connDriver.intensity = intensity
  C4:SendToDevice(connDeviceId,"updateDimmerIntensity",{intensity=intensity})
end
function updateRelayState(relayId, state)
--  print(string.format("TODO: Relay %d state is %s",relayId, (state == 0) and "Off" or "On"))
  relayId = tonumber(relayId)
  local relay = getRelayDriver(relayId)
  if (relay == nil) then
    Dbg:Debug("Relay " .. relayId .. " not connected")
    return
  end
  if (state == 1) then
    relay.state = Utils.ON
    C4:SendToProxy(DEVICE_CFG.CONNECTION_RELAY_BASE+relayId,"STATE_OPENED", "", "NOTIFY")
  else
    relay.state = Utils.OFF
    C4:SendToProxy(DEVICE_CFG.CONNECTION_RELAY_BASE+relayId,"STATE_CLOSED", "", "NOTIFY")
  end
end
function updateHVACState(addr, data)
  if (Utils.dumpData == Utils.DUMP_DATA_ALL) or (Utils.dumpData == Utils.DUMP_DATA_RECIEVED) then
    print("updateHVACState() with " .. Utils.tableToString(data))
  end
  
  local fanCoilDrvId = nil
  local fanCoilDriver = nil
  for drvId,drvData in pairs(DEVICE_CFG.connectedDrivers) do
    if (drvData.type=="FAN_COIL") then
      if (drvData.modbusDeviceName == data.modbusDeviceName) then
        fanCoilDrvId = drvId
        fanCoilDriver = drvData
        break
      end
    end
  end
  local fanCoilDriver = DEVICE_CFG.connectedDrivers[fanCoilDrvId]
  if (fanCoilDriver == nil) then
    Dbg:Debug("FanCoil driver with modebus name " .. data.modbusDeviceName .. " not connected")
    return
  end
  fanCoilDriver.status = data
  local tParams = {
    mode = data.mode,
    fanSpeed = data.fanSpeed,
    setTemperature = data.setTemperature,
    roomTemperature = data.roomTemperature,
    bottonLock = data.coilKBLockSpeed,
  }
  if (data.state == Utils.OFF) then
    tParams.mode = "Off"
  end
  C4:SendToDevice(fanCoilDrvId,"UpdateHVAC",tParams)
end
function updateEnvState(addr, data)
  if (Utils.dumpData == Utils.DUMP_DATA_ALL) or (Utils.dumpData == Utils.DUMP_DATA_RECIEVED) then
    print("updateEnvState() with " .. Utils.tableToString(data))
  end
  
  local driverId = nil
  local driver = nil
  for drvId,drvData in pairs(DEVICE_CFG.connectedDrivers) do
    if (drvData.type=="ENVIRONMENT") then
      if (drvData.modbusDeviceName == data.modbusDeviceName) then
        driverId = drvId
        driver = drvData
        break
      end
    end
  end
  local driver = DEVICE_CFG.connectedDrivers[driverId]
  if (driver == nil) then
    Dbg:Debug("Environmental driver with modebus name " .. data.modbusDeviceName .. " not connected")
    return
  end
  driver.status = data
  C4:SendToDevice(driverId,"UpdateEnvironmentStatus",data)
end

cmdMaker = {
   commandCode = nil,
   commandParams = nil,
   -------------------------- Scene related command -------------------------
   cmdActivateScene= {
      command = function(tParams)
          local strCmd = string.char(0x12, Utils.byte0(tParams.sceneNumber),Utils.byte1(tParams.sceneNumber))
          return makeSendCmd(strCmd, true)
        end,
      responseHandler = cmdResponseProcess
   },
   cmdIncScene= {
      command = function(tParams)
          local strCmd = string.char(0x13, Utils.byte0(tParams.sceneNumber),Utils.byte1(tParams.sceneNumber))
          return makeSendCmd(strCmd, false)
        end,
      responseHandler = cmdResponseProcess
   },
   cmdDecScene= {
      command = function(tParams)
          local strCmd = string.char(0x14, Utils.byte0(tParams.sceneNumber),Utils.byte1(tParams.sceneNumber))
          return makeSendCmd(strCmd, false)
        end,
      responseHandler = cmdResponseProcess
   },
   cmdStopFadeScene= {
      command = function(tParams)
          local strCmd = string.char(0x12, Utils.byte0(61440),Utils.byte1(61440))
          return makeSendCmd(strCmd, false)
        end,
      responseHandler = cmdResponseProcess
   },
   cmdSaveStateAsScene= {
      command = function(tParams)
          local options = {["Save"]=0, ["Trigger"]=1, ["Delete"]=2}
          if (options[tParams.option] == nil) then
            print("cmdSaveStateAsScene(): can only support action Save/Trigger/Delete")
            return
          end
          local strCmd = string.char(0x0D, Utils.byte0(tParams.sceneNumber),Utils.byte1(tParams.sceneNumber), options[tParams.option], tParams.areaNo)
          return makeSendCmd(strCmd, true)
        end,
      responseHandler = cmdResponseProcess
   },
   -------------------------- Dimmer related command -------------------------
   cmdReadDimmerIntensity= {
      command = function(tParams)
          local strCmd = string.char(0x07, Utils.byte0(DEVICE_CFG.protocolVersion),Utils.byte1(DEVICE_CFG.protocolVersion))
          return makeSendCmd(strCmd, false)
        end,
      responseHandler = cmdResponseProcess
   },
   cmdDimmerDirectControl= {
      command = function(tParams)
          local actions = {["StopFade"]=0, ["Inc"]=1, ["Dec"]=2,["AbsoluteLevel"]=3}
          if (actions[tParams.action] == nil) then
            print("cmdDimmerDirectControl(): can only support action StopFade/Inc/Dec/AbsoluteLevel")
            return
          end
          local strCmd = string.char(0x1C, actions[tParams.action], tParams.dimmerIdx, tParams.adjustment, tParams.secondsToFade)
          return makeSendCmd(strCmd, false)
        end,
      responseHandler = cmdResponseProcess
   },
   -------------------------- Relay related command -------------------------
   cmdReadRelayState= {
      command = function(tParams)
          local strCmd = string.char(0x06, Utils.byte0(DEVICE_CFG.protocolVersion),Utils.byte1(DEVICE_CFG.protocolVersion))
          return makeSendCmd(strCmd, false)
        end,
      responseHandler = cmdResponseProcess
   },
   cmdRelayDirectControl= {
      command = function(tParams)
          local actions = {["On"]=0x19, ["Off"]=0x1E}
          if (actions[tParams.action] == nil) then
            print("cmdRelayDirectControl(): can only support action On/Off")
            return
          end
          local strCmd = string.char(actions[tParams.action], tParams.relayOnOff, tParams.relayMask)
          return makeSendCmd(strCmd, false)
        end,
      responseHandler = cmdResponseProcess
   },
   cmdRelayNewDirectControl= {
      command = function(tParams)
          local actions = {["Toggle"]=1, ["DirectControl"]=3}
          local onOffFlags = {[Utils.OFF]=0, [Utils.ON]=1}
          local strCmd = string.char(0x1C,actions[tParams.action], tParams.relayIdx,  onOffFlags[tParams.onOffFlag])
          return makeSendCmd(strCmd, false)
        end,
      responseHandler = cmdResponseProcess
   },
   -------------------------- HVAC related command -------------------------
   cmdReadFanCoil= {
      command = function(tParams)
          local strCmd = string.char(0x52, 
              Utils.byte0(DEVICE_CFG.protocolVersion),Utils.byte1(DEVICE_CFG.protocolVersion),
              Utils.byte0(tParams.modbusDeviceName),Utils.byte1(tParams.modbusDeviceName))
          return makeSendCmd(strCmd, false)
        end,
      responseHandler = cmdResponseProcess
   },
   cmdFanCoilDirectControl= {
      command = function(tParams)
          local fanCDCStr = getFanCoilControlCmd(tParams)
          if (fanCDCStr == nil) then return nil end
          local strCmd = string.char(0x50, 
              Utils.byte0(DEVICE_CFG.protocolVersion),Utils.byte1(DEVICE_CFG.protocolVersion)) .. fanCDCStr
          return makeSendCmd(strCmd, false)
        end,
      responseHandler = cmdResponseProcess
   },
   cmdReadEnvironmentalStatus= {
      command = function(tParams)
          local strCmd = string.char(0x56, 
              Utils.byte0(DEVICE_CFG.protocolVersion),Utils.byte1(DEVICE_CFG.protocolVersion),
              Utils.byte0(tParams.modbusDeviceName),Utils.byte1(tParams.modbusDeviceName))
          return makeSendCmd(strCmd, false)
        end,
      responseHandler = cmdResponseProcess
   },
}

function sendOneCommand(cmdName, tParams)
  local cmdHandler = cmdMaker[cmdName]
  if (cmdHandler == nil) then
    print("Error: no command " .. cmdName .. " defined")
    return
  end
  local strCmd = cmdHandler.command(tParams)
  C4:SendToSerial(DEVICE_CFG.CONNECTION_RS232,strCmd)
  if (Utils.dumpData == Utils.DUMP_DATA_ALL) then
    print("Send data to RS232:")
    hexdump(strCmd)
  end
end
----------- C4 dirver COMMAND interfaces ----------
            ----- Scene related -----
function EX_CMD.activateScene(tParams)
  local cmdParamsRule = {
    ["sceneNumber"] = {type="Number", range={2,0xFFFF}},
  }
  local errMsg = Utils.verifyTableParams(cmdParamsRule, tParams)
  if (errMsg ~= nil) then
    Dbg:Error("Error execute command \"activateScene\": " .. errMsg)
    return
  end
  sendOneCommand("cmdActivateScene", tParams)
end

function EX_CMD.incScene(tParams) 
  local cmdParamsRule = {
    ["sceneNumber"] = {type="Number", range={2,0xFFFF}},
  }
  local errMsg = Utils.verifyTableParams(cmdParamsRule, tParams)
  if (errMsg ~= nil) then
    Dbg:Error("Error execute command \"incScene\": " .. errMsg)
    return
  end 
  sendOneCommand("cmdIncScene", tParams)
end

function EX_CMD.decScene(tParams) 
  local cmdParamsRule = {
    ["sceneNumber"] = {type="Number", range={2,0xFFFF}},
  }
  local errMsg = Utils.verifyTableParams(cmdParamsRule, tParams)
  if (errMsg ~= nil) then
    Dbg:Error("Error execute command \"decScene\": " .. errMsg)
    return
  end 
  sendOneCommand("cmdDecScene", tParams)
end

function EX_CMD.stopFadeScene(tParams) 
  sendOneCommand("cmdStopFadeScene", tParams)
end

function EX_CMD.saveStateAsScene(tParams) 
  local cmdParamsRule = {
    ["sceneNumber"] = {type="Number", range={0,0xFFFF}},
    ["option"]={type="List", values={["Save"]=0, ["Trigger"]=1, ["Delete"]=2}},
    ["areaNo"] = {type="Number", range={0,0xFF}},
  }
  local errMsg = Utils.verifyTableParams(cmdParamsRule, tParams)
  if (errMsg ~= nil) then
    Dbg:Error("Error execute command \"saveStateAsScene\": " .. errMsg)
    return
  end
  sendOneCommand("cmdSaveStateAsScene", tParams)
end

            ----- Dimmer related -----
function EX_CMD.readDimmerIntensity(tParams) 
  sendOneCommand("cmdReadDimmerIntensity", tParams)
end

function EX_CMD.dimmerDirectControl(tParams) 
  local cmdParamsRule = {
    ["action"]={type="List", values={["StopFade"]=0, ["Inc"]=1, ["Dec"]=2,["AbsoluteLevel"]=3}},
    ["dimmerIdx"] = {type="Number", range={1,12}},
    ["adjustment"] = {type="Number", range={0,255}},
    ["secondsToFade"] = {type="Number", range={0,255}},
  }
  local errMsg = Utils.verifyTableParams(cmdParamsRule, tParams)
  if (errMsg ~= nil) then
    Dbg:Error("Error execute command \"dimmerDirectControl\": " .. errMsg)
    return
  end
  sendOneCommand("cmdDimmerDirectControl", tParams)
end
   
            ----- relay related -----   
function EX_CMD.readRelayState(tParams) 
  sendOneCommand("cmdReadRelayState", tParams)
end

function EX_CMD.relayDirectControl(tParams) 
  local cmdParamsRule = {
    ["action"]={type="List", values={["On"]=0x19, ["Off"]=0x1E}},
    ["relayOnOff"] = {type="Number", range={0,255}},
    ["relayMask"] = {type="Number", range={0,255}},
  }
  local errMsg = Utils.verifyTableParams(cmdParamsRule, tParams)
  if (errMsg ~= nil) then
    Dbg:Error("Error execute command \"relayDirectControl\": " .. errMsg)
    return
  end
  sendOneCommand("cmdRelayDirectControl", tParams)
end
 
function EX_CMD.relayNewDirectControl(tParams) 
  local cmdParamsRule = {
    ["action"]={type="List", values={["Toggle"]=1, ["DirectControl"]=3}},
    ["relayIdx"] = {type="Number", range={1,8}},
    ["onOffFlag"] = {type="List", values={[Utils.OFF]=0, [Utils.ON]=1}},
  }
  local errMsg = Utils.verifyTableParams(cmdParamsRule, tParams)
  if (errMsg ~= nil) then
    Dbg:Error("Error execute command \"relayNewDirectControl\": " .. errMsg)
    return
  end
  sendOneCommand("cmdRelayNewDirectControl", tParams)
end  

            ----- HVAC related -----
function EX_CMD.readFanCoil(tParams) 
  local cmdParamsRule = {
    ["modbusDeviceName"] = {type="Number", range={0, 0xFFFF}},
  }
  local errMsg = Utils.verifyTableParams(cmdParamsRule, tParams)
  if (errMsg ~= nil) then
    Dbg:Error("Error execute command \"readFanCoil\": " .. errMsg)
    return
  end

  if (not updateModbusName("FAN_COIL", tParams.fromDevice, tParams.modbusDeviceName)) then return end
  sendOneCommand("cmdReadFanCoil", tParams)
end

function EX_CMD.fanCoilDirectControl(tParams) 
  local cmdParamsRule = DEVICE_CFG.FanCoilControlCmdParamRule
  local errMsg = Utils.verifyTableParams(cmdParamsRule, tParams)
  if (errMsg ~= nil) then
    Dbg:Error("Error execute command \"fanCoilDirectControl\": " .. errMsg)
    return
  end
  if (not updateModbusName("FAN_COIL", tParams.fromDevice, tParams.modbusDeviceName)) then return end
  sendOneCommand("cmdFanCoilDirectControl", tParams)
end

            ----- Environment status related -----
function EX_CMD.readEnvironmentalStatus(tParams) 
-- TODO
  local cmdParamsRule = {["modbusDeviceName"] = {type="Number", range={0,0xFFFF}},}
  local errMsg = Utils.verifyTableParams(cmdParamsRule, tParams)
  if (errMsg ~= nil) then
    Dbg:Error("Error execute command \"readEnvironmentalStatus\": " .. errMsg)
    return
  end
  if (not updateModbusName("ENVIRONMENT", tParams.fromDevice, tParams.modbusDeviceName)) then return end
  sendOneCommand("cmdReadEnvironmentalStatus", tParams)
end


----------------------------- Lua Actions --------------------------------
function LUA_ACTION.showDeviceStatus()
  local dvcs = DEVICE_CFG.connectedDevices
  for dvcType,data in pairs(dvcs) do
    if (not Utils.isEmpty(data)) then
      print(dvcType)
      for dvcId,drvId in pairs(data) do
        local strData = Utils.tableToString(DEVICE_CFG.connectedDrivers[drvId])
        print("", strData)
      end
    end
  end
end
function LUA_ACTION.readDimmerIntensity()
  sendOneCommand("cmdReadDimmerIntensity", {})
end
function LUA_ACTION.refreshConnections()
  _refreshDriverConnections()
end

function LUA_ACTION.saveScene()
  local tParams = {
    sceneNumber = tonumber(DEVICE_CFG.sceneNo),
    option = "Save",
    areaNo = tonumber(DEVICE_CFG.areaNo),
  }
  sendOneCommand("cmdSaveStateAsScene", tParams)
end
function LUA_ACTION.deleteScene()
  local tParams = {
    sceneNumber = tonumber(DEVICE_CFG.sceneNo),
    option = "Delete",
    areaNo = tonumber(DEVICE_CFG.areaNo),
  }
  sendOneCommand("cmdSaveStateAsScene", tParams)
end
function LUA_ACTION.activeScene()
  sendOneCommand("cmdActivateScene", {sceneNumber=tonumber(DEVICE_CFG.sceneNo)})
end
function LUA_ACTION.incScene()
  sendOneCommand("cmdIncScene", {sceneNumber=tonumber(DEVICE_CFG.sceneNo)})
end
function LUA_ACTION.decScene()
  sendOneCommand("cmdDecScene", {sceneNumber=tonumber(DEVICE_CFG.sceneNo)})
end
function LUA_ACTION.stopSceneFading()
  sendOneCommand("cmdStopFadeScene", {})
end
function LUA_ACTION.batchRelayOn()
  local onOff = convertToRelayParam(DEVICE_CFG.relayBatchOnOff)
  local mask = convertToRelayParam(DEVICE_CFG.relayBatchMask)
  if (onOff == nil) or (mask == nil) then return end
  local tParams = {action="On", relayOnOff=onOff, relayMask=mask}
  sendOneCommand("cmdRelayDirectControl", tParams)
end
function LUA_ACTION.batchRelayOff()
  local onOff = convertToRelayParam(DEVICE_CFG.relayBatchOnOff)
  local mask = convertToRelayParam(DEVICE_CFG.relayBatchMask)
  if (onOff == nil) or (mask == nil) then return end
  local tParams = {action="Off", relayOnOff=onOff, relayMask=mask}
  sendOneCommand("cmdRelayDirectControl", tParams)
end

----------------------- Relay proxy command ------------------------------
function  PRX_CMD.CLOSE(idBinding, tParams)
  setSingleRelay(idBinding, "CLOSE")
end

function  PRX_CMD.OPEN(idBinding, tParams)
  setSingleRelay(idBinding, "OPEN")
end

function  PRX_CMD.TOGGLE(idBinding, tParams)
  setSingleRelay(idBinding, "TOGGLE")
end
----------------------- Relay functional command -------------------------
function setSingleRelay(idBinding, action)
  Dbg:Debug("Calling " ..action.."(".. idBinding .. ", " .. Utils.tableToString(tParams) .. ")")
  local relayId = tonumber(idBinding)
  if (relayId == nil) then print(action .. " relay without idBinding") return end
  relayId = relayId - DEVICE_CFG.CONNECTION_RELAY_BASE
  if (relayId < 1) or (relayId > 8) then print("RelayId wrong:" .. relayId) return end
  
  local tParams = {relayIdx=relayId, action="DirectControl", onOffFlag=""}
  if (action == "OPEN") then
    tParams.onOffFlag = Utils.ON
  elseif (action == "CLOSE") then
    tParams.onOffFlag = Utils.OFF
  elseif (action == "TOGGLE") then
    tParams.action = "Toggle"
    local oldState = getCurrentRelayState(relayId)
    print("Relay " .. relayId .. " is " .. oldState)
    if (oldState == Utils.ON) then
      tParams.onOffFlag = Utils.OFF
    else
      tParams.onOffFlag = Utils.ON
    end
  end
  updateRelayControlUI(tParams)
  sendOneCommand("cmdRelayNewDirectControl", tParams)
end

function getRelayDriver(relayId)
  local driverId = DEVICE_CFG.connectedDevices.RELAY[tonumber(relayId)]
  if (driverId ==  nil) then return nil end
  return DEVICE_CFG.connectedDrivers[driverId]
end
function getCurrentRelayState(relayId)
  local driver = getRelayDriver(relayId)
  return driver.state or Utils.ON
end
function updateRelayControlUI(tParams)
  local relayId = tonumber(tParams.relayIdx)
  local driver = getRelayDriver(relayId)
  driver.state = tParams.onOffFlag
  local stateMsg = (tParams.onOffFlag == Utils.OFF) and "STATE_CLOSED" or "STATE_OPENED"
  --print("SendToProxy():", DEVICE_CFG.CONNECTION_RELAY_BASE+relayId, stateMsg)
  C4:SendToProxy(DEVICE_CFG.CONNECTION_RELAY_BASE+relayId,stateMsg, "", "NOTIFY")
end
function updateModbusName(deviceType, fromDevice, modbusDeviceName)
  -- special note: we use modebus-id to find connected devices, but it maybe changed
  -- so we need update it when got command
  local driverId = DEVICE_CFG.connectedDevices[deviceType][tonumber(fromDevice)]
  if (driverId == nil) then
    Dbg:Error("Cannot found " .. deviceType .. " driver " .. fromDevice)
    return false
  end
  local driverData = DEVICE_CFG.connectedDrivers[driverId]
  if (driverData == nil) then
    Dbg:Error(deviceType .. " " .. driverId .. " not connected")
    return false
  end
  driverData.modbusDeviceName = tonumber(modbusDeviceName)
  return true
end
------------------------- Connect to other drivers -----------------------
function _resetConnectedDrivers()
  DEVICE_CFG.connectedDrivers = {}
  for dvcType,dvcList in pairs(DEVICE_CFG.connectedDevices) do
    DEVICE_CFG.connectedDevices[dvcType] = {}
  end
end
function _connectDriver(tParams)
  Dbg:Info("Connect driver " .. Utils.tableToString(tParams))
  local deviceType = tParams.type
  local conDrvTbl = DEVICE_CFG.connectedDrivers
  conDrvTbl[tonumber(tParams.c4DriverId)] = {type=deviceType, idx=tonumber(tParams.deviceIdx)}
  if (type(DEVICE_CFG.connectedDevices[deviceType]) ~= "table") then
    print("Error: Cannot connect with " .. Utils.tableToString(tParams))
    return
  end
  local conDvcTbl = DEVICE_CFG.connectedDevices
  conDvcTbl[deviceType][tonumber(tParams.deviceIdx)] = tonumber(tParams.c4DriverId)
end
function OnBindingChanged(idBinding, strClass, bIsBound)
  if (not bIsBound) or (bIsBound == "false") then return end
  C4:SendToDevice(tonumber(idBinding),"GetDriverInfo",{deviceId=C4:GetDeviceID()})
end
function _refreshDriverConnections()
  _resetConnectedDrivers()
  
  -- refresh TRANSNET_PORT connections
  local devs = C4:GetBoundConsumerDevices(0, DEVICE_CFG.CONNECTION_TRANSNET)
  for id,name in pairs(devs) do
    C4:SendToDevice(id,"GetDriverInfo",{deviceId=C4:GetDeviceID()})
  end
  
  -- refresh RELAY1~8 connections
  for i=1,8 do
    local connId = DEVICE_CFG.CONNECTION_RELAY_BASE+i
    devs = C4:GetBoundConsumerDevices(0, connId)
    if (not Utils.isEmpty(devs)) then
      for id,name in pairs(devs) do
        _connectDriver({c4DriverId=id, type="RELAY", deviceIdx=i})
      end
    end
  end
end
function EX_CMD.connectDriver(tParams)
  _connectDriver(tParams)
end
function ON_DRIVER_LATEINIT.transnetConnection()
  _refreshDriverConnections()
end

----------------


------------------------ initial driver ----------------------
function DriverPollingTask()
  print("Polling task: TBC")
end
function ReceivedFromSerial(idBinding, strData)
  RS232Handler:onPieceRecieved(idBinding,strData)
end
function OnPropertyChanged4DriverExt(propName, propValue)
  Utils.handleDriverPropertyChange(DEVICE_CFG.properties, propName, propValue)
end
function OnTimer4DriverExt(idTimer)
  RS232Handler:onTimer(idTimer)
end
function ON_DRIVER_INIT.Transnet()
  C4:AddVariable("EventCount", 0, "NUMBER")
  RS232Handler:init({callBack=OnRS232MessageRecieved})
end

------------------------some method for debugging --------------
function LUA_ACTION.triggerEvent()
-- This is used for debugging purpose. Ignore it in product
  DEVICE_CFG.eventCnt = DEVICE_CFG.eventCnt + 1
  local newVal = DEVICE_CFG.eventCnt
  C4:SetVariable("EventCount", newVal)
end
function DebugSendCmd(strData)
  local len = #(tohex(strData))
  local cmd = string.format("AA 55 %02X %02X %02X %s 0D 0A",DEVICE_CFG.toAddress, DEVICE_CFG.srcAddress, len, strData)
  print("Will send this to RS232: " .. cmd)
  C4:SendToSerial(DEVICE_CFG.CONNECTION_RS232, tohex(cmd))
end
function DebugSendRS232(strData)
  C4:SendToSerial(DEVICE_CFG.CONNECTION_RS232, tohex(strData))
end
function DebugRecieveRS232(strData)
  OnRS232MessageRecieved(DEVICE_CFG.CONNECTION_RS232, tohex(strData))
end
-- -- Dimmer auto-report
--DebugSendRS232("00 E1 0C 01 AA 55 00 02 05 92 10 20 30 40 0D 0A FF DD")
-- -- Dimmer read-response
--DebugSendRS232("00 E2 0F 01 AA 55 00 02 07 07 64 00 14 20 30 40 0D 0A FF DD")
--C4:SendToProxy(3,"STATE_OPENED",0, "NOTIFY")



