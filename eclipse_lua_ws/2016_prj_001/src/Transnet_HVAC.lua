DEVICE_CFG = {
  idx = 1,
  gatewayId = -1,
  CONNECTION_TRANSNET = 1,
  gotDeviceInfo = false,
  PROXY_HVAC = 5001,
  eventCnt = 1,
  UNIT_TEMP_C = "C",
  UNIT_TEMP_F = "F",
  modbusAddr = 1,
  HVAC_DATA = {
    mode = "Off",
    fanSpeed = "Off",
    unit = nil,
    setTempInC = 0,
    setTempInF = 32,
    roomTempInC = 0,
    roomTempInF = 32,
    buttonLock = false,
  },
}
PropertyInfos = {
  ["Device Index"] = {
    verifyRule = {type="Number", range={1,255}},
    onPropertyChanged = function(info, name, value)
       DEVICE_CFG.idx = tonumber(value)
       promptMsg("")
    end,
  },
  ["Modbus Device"]= {
    verifyRule = {type="Number", range={0,65535}},
    onPropertyChanged = function(info, name, value)
       DEVICE_CFG.modbusAddr = tonumber(value)
       promptMsg("")
    end,
  },
  ["Temperature Scale"]= {
    verifyRule = {type="List", values={["CELSIUS"]="CELSIUS", ["FAHRENHEIT"]="FAHRENHEIT"}},
    onPropertyChanged = function(info, name, value)
       local tgtUnit = {
          ["C"]="CELSIUS",["CELSIUS"]="CELSIUS", ["Celsius"]="CELSIUS",
          ["F"]="FAHRENHEIT",["FAHRENHEIT"]="FAHRENHEIT", ["Fahrenheit"]="FAHRENHEIT"}
       updateControlUI("SET_SCALE", {SCALE=tgtUnit[value]})
    end,
  },
  ["Mode"] = {
    verifyRule = {type="List", values={["Off"]="Off",["Heat"]="Heat",["Cool"]="Cool",["FanOnly"]="FanOnly",["Dehumidifier"]="Dehumidifier"}},
    onPropertyChanged = function(info, name, value)
      local tParams = {MODE=value}
      updateControlUI("SET_MODE_HVAC", tParams)
      if (Utils.initStep < 6) then return end
      -- If mode is heat or cool, also need set the set-point, because this device only has one set-temperature
      tParams.CELSIUS = DEVICE_CFG.HVAC_DATA.setTempInC
      tParams.FAHRENHEIT = DEVICE_CFG.HVAC_DATA.setTempInF
      tParams.SETPOINT = (DEVICE_CFG.HVAC_DATA.unit == DEVICE_CFG.UNIT_TEMP_C) and DEVICE_CFG.HVAC_DATA.setTempInC or DEVICE_CFG.HVAC_DATA.setTempInF
      local workingMode = DEVICE_CFG.HVAC_DATA.mode
      if (workingMode == "Heat") then
        updateControlUI("SET_SETPOINT_HEAT", tParams)
      elseif (workingMode == "Cool") then
        updateControlUI("SET_SETPOINT_COOL", tParams)
      end
      execRealFunc(convertToCmdParam("SET_MODE_HVAC", tParams))
    end,
  },
  ["Fan Speed"] = {
    verifyRule = {type="List", values={["High"]="High",["Medium"]="Medium",["Low"]="Low",["Auto"]="Auto",["UltraLow"]="UltraLow",["UltraHigh"]="UltraHigh",["Off"]="Off"}},
    onPropertyChanged = function(info, name, value)
      local tParams = {MODE=value}
      updateControlUI("SET_MODE_FAN", tParams)
      execRealFunc(convertToCmdParam("SET_MODE_FAN", tParams))
    end,
  },
  ["Set Temperature"] = {
    verifyRule = {type="Number", range={0, 212.0}},
    onPropertyChanged = function(info, name, value)
      -----------------      Rules for set temperature:
      --1. Only Heat/Cool can set temperature. If in other working mode, will setback to old value and show error message.
      --2. If current in C, will treat the value in C. Same logical for F.
      if (DEVICE_CFG.HVAC_DATA.unit == nil) then
        DEVICE_CFG.HVAC_DATA.setTempInC = tonumber(value)
        DEVICE_CFG.HVAC_DATA.setTempInF = tonumber(value)
        promptMsg("Temperature unit not decided, nothing can do")
        return
      end
      
      local tParams = {CELSIUS=0, FAHRENHEIT=0, SETPOINT=0}
      if (DEVICE_CFG.HVAC_DATA.unit == DEVICE_CFG.UNIT_TEMP_C) then
        DEVICE_CFG.HVAC_DATA.setTempInC = tonumber(value)
        DEVICE_CFG.HVAC_DATA.setTempInF = Utils.TemperatureC2F(DEVICE_CFG.HVAC_DATA.setTempInC)
        tParams.CELSIUS = DEVICE_CFG.HVAC_DATA.setTempInC
        tParams.FAHRENHEIT = DEVICE_CFG.HVAC_DATA.setTempInF
        tParams.SETPOINT = DEVICE_CFG.HVAC_DATA.setTempInC
      else
        DEVICE_CFG.HVAC_DATA.setTempInF = tonumber(value)
        DEVICE_CFG.HVAC_DATA.setTempInC = Utils.TemperatureF2C(DEVICE_CFG.HVAC_DATA.setTempInF)
        tParams.CELSIUS = DEVICE_CFG.HVAC_DATA.setTempInC
        tParams.FAHRENHEIT = DEVICE_CFG.HVAC_DATA.setTempInF
        tParams.SETPOINT = DEVICE_CFG.HVAC_DATA.setTempInF
      end
      
      local workingMode = DEVICE_CFG.HVAC_DATA.mode
      if (workingMode == "Heat") then
        updateControlUI("SET_SETPOINT_HEAT", tParams)
        execRealFunc(convertToCmdParam("SET_SETPOINT_HEAT", tParams))
      elseif (workingMode == "Cool") then
        updateControlUI("SET_SETPOINT_COOL", tParams)
        execRealFunc(convertToCmdParam("SET_SETPOINT_COOL", tParams))
      else
        updateControlUI("SET_SETPOINT_HEAT", tParams)
        updateControlUI("SET_SETPOINT_COOL", tParams)
        promptMsg("Only Heat/Cool can set temperature")
        return
      end
    end,
  },
  
}
function promptMsg(strMsg)
  strMsg = strMsg or ""
  print("MESSAGE: " .. strMsg)
  C4:UpdateProperty("Prompt Message", strMsg)
end
function EX_CMD.GetDriverInfo(tParams)
  local resp = {
    type = "FAN_COIL",
    c4DriverId = C4:GetDeviceID(),
    deviceIdx = DEVICE_CFG.idx,
  }
  DEVICE_CFG.gatewayId = tonumber(tParams.deviceId)
  C4:SendToDevice(tParams.deviceId, "connectDriver", resp)
end


----------------------- functional methos -----------------
function convertToCmdParam(cmdName, tParams)
--Command inteface defined as below:
--FanCoilControlCmdParamRule = {
--    ["modbusDeviceName"] = {type="Number", range={0,0xFFFF}},
--    ["state"]={type="List", values={["NoChange"]=0, ["Off"]=1, ["On"]=2}},
--    ["mode"]={type="List", values={["NoChange"]=0, ["Cool"]=1, ["Heat"]=2,["FanOnly"]=3,["Dehumidifier"]=4}},
--    ["temperature"] = {type="Number", range={0,0xFFFF}},
--    ["fanSpeed"]={type="List", values={["NoChange"]=0, ["High"]=1, ["Medium"]=2,["Low"]=3,["Auto"]=4,["UltraLow"]=5,["UltraHigh"]=6,["Off"]=7}},
--    ["keyboardLock"]={type="List", values={["NoChange"]=0, ["Off"]=1, ["On"]=2}},
--  },
  -- TODO
  local data = DEVICE_CFG.HVAC_DATA
  local tParams = {
    modbusDeviceName = DEVICE_CFG.modbusAddr,
    state="NoChange",
    mode="NoChange",
    temperature = 0,
    fanSpeed="NoChange",
    keyboardLock="NoChange",
  }
  if (cmdName=="SET_MODE_HVAC") then
    if (DEVICE_CFG.HVAC_DATA.mode == "Off") then
      tParams.state = "Off"
    elseif (DEVICE_CFG.HVAC_DATA.mode == "Heat") then
      tParams.temperature = math.floor(data.setTempInC + 0.5)
      tParams.state = "On"
      tParams.mode = "Heat"
    elseif (DEVICE_CFG.HVAC_DATA.mode == "Cool") then
      tParams.temperature = math.floor(data.setTempInC + 0.5)
      tParams.state = "On"
      tParams.mode = "Cool"
    else
      tParams.state = "On"
      tParams.mode = DEVICE_CFG.HVAC_DATA.mode
    end
  elseif (cmdName=="SET_MODE_FAN") then
    tParams.fanSpeed = data.fanSpeed
  elseif (cmdName=="SET_SCALE") then
    -- set scale will not change physical device
    return nil
  elseif (cmdName=="SET_SETPOINT_HEAT") then
    tParams.temperature = math.floor(data.setTempInC + 0.5)
  elseif (cmdName=="SET_SETPOINT_COOL") then
    tParams.temperature = math.floor(data.setTempInC + 0.5)
  elseif (cmdName=="SET_BUTTONS_LOCK") then
    tParams.keyboardLock = data.buttonLock and "On" or "Off"
  end
  return tParams
end
function convertAllToCmdParam()
  local data = DEVICE_CFG.HVAC_DATA
  local tParams = {
    modbusDeviceName = DEVICE_CFG.modbusAddr,
    mode="NoChange",
  }
  if (DEVICE_CFG.HVAC_DATA.mode == "Off") then
    tParams.state = "Off"
  elseif (DEVICE_CFG.HVAC_DATA.mode == "Heat") then
    tParams.state = "On"
    tParams.mode = "Heat"
  elseif (DEVICE_CFG.HVAC_DATA.mode == "Cool") then
    tParams.state = "On"
    tParams.mode = "Cool"
  else
    tParams.state = "On"
    tParams.mode = DEVICE_CFG.HVAC_DATA.mode
  end
  tParams.temperature = math.floor(data.setTempInC + 0.5)
  tParams.fanSpeed = data.fanSpeed
  tParams.keyboardLock = data.buttonLock and "On" or "Off"
  return tParams
end
-------------- Transnet functional communication -------------
function execRealFunc(tParams)
  if (not DEVICE_CFG.gotDeviceInfo) then return end
  if (tParams == nil) then return end
  Dbg:Debug("Will execute " .. Utils.tableToString(tParams))
  if (DEVICE_CFG.gatewayId <= 0) then
    promptMsg("Gateway not connected. Cannot execute any command")
    return
  end
  tParams.fromDevice = DEVICE_CFG.idx
  C4:SendToDevice(DEVICE_CFG.gatewayId, "fanCoilDirectControl", tParams)
end
function refreshHVACStatus()
  if (DEVICE_CFG.gatewayId <= 0) then
    promptMsg("Gateway not connected. Cannot execute any command")
    return
  end
  C4:SendToDevice(DEVICE_CFG.gatewayId, "readFanCoil", {fromDevice = DEVICE_CFG.idx, modbusDeviceName=DEVICE_CFG.modbusAddr})
end
--TODO
function updateHVACWithReplay(tParams)
--example: {buttonLock="Off", fanSpeed="High", mode="Heat", roomTemperature="27", setTemperature="25"}
  local data = DEVICE_CFG.HVAC_DATA
  if (tParams.fanSpeed ~= "NoChange") then
    data.fanSpeed = tParams.fanSpeed
  end
  data.buttonLock = tParams.buttonLock == "On"
  data.mode = tParams.mode
  data.roomTempInC = tonumber(tParams.roomTemperature)
  data.roomTempInF = Utils.TemperatureC2F(data.roomTempInC)
  data.setTempInC = tonumber(tParams.setTemperature)
  data.setTempInF = Utils.TemperatureC2F(data.setTempInC)
end
function updateAllControlUI()
  local data = DEVICE_CFG.HVAC_DATA
  C4:UpdateProperty("Mode", data.mode)
  C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"HVAC_MODE_CHANGED",{MODE=data.mode})
  C4:UpdateProperty("Fan Speed", data.fanSpeed)
  C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"FAN_MODE_CHANGED",{MODE=data.fanSpeed})
  if (data.unit == DEVICE_CFG.UNIT_TEMP_F) then
    C4:UpdateProperty("Set Temperature", DEVICE_CFG.HVAC_DATA.setTempInF)
    C4:UpdateProperty("Room Temperature", DEVICE_CFG.HVAC_DATA.roomTempInF)
    C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"HEAT_SETPOINT_CHANGED",{SETPOINT=DEVICE_CFG.HVAC_DATA.setTempInF, SCALE=DEVICE_CFG.UNIT_TEMP_F})
    C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"COOL_SETPOINT_CHANGED",{SETPOINT=DEVICE_CFG.HVAC_DATA.setTempInF, SCALE=DEVICE_CFG.UNIT_TEMP_F})
    C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"TEMPERATURE_CHANGED",{TEMPERATURE=DEVICE_CFG.HVAC_DATA.roomTempInF, SCALE=DEVICE_CFG.UNIT_TEMP_F})
  else
    C4:UpdateProperty("Set Temperature", DEVICE_CFG.HVAC_DATA.setTempInC)
    C4:UpdateProperty("Room Temperature", DEVICE_CFG.HVAC_DATA.roomTempInC)
    C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"HEAT_SETPOINT_CHANGED",{SETPOINT=DEVICE_CFG.HVAC_DATA.setTempInC, SCALE=DEVICE_CFG.UNIT_TEMP_C})
    C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"COOL_SETPOINT_CHANGED",{SETPOINT=DEVICE_CFG.HVAC_DATA.setTempInC, SCALE=DEVICE_CFG.UNIT_TEMP_C})
    C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"TEMPERATURE_CHANGED",{TEMPERATURE=DEVICE_CFG.HVAC_DATA.roomTempInC, SCALE=DEVICE_CFG.UNIT_TEMP_C})
  end
  C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"BUTTONS_LOCK_CHANGED",{LOCK=locked})
end
------------------------ UI related functions ----------------
UIHandlers = {
  SET_MODE_HVAC = function(tParams)
    DEVICE_CFG.HVAC_DATA.mode = tParams.MODE
    C4:UpdateProperty("Mode", tParams.MODE)
    C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"HVAC_MODE_CHANGED",{MODE=tParams.MODE}) --TODO
    promptMsg("HVAC Mode set")
  end,
  SET_MODE_FAN = function(tParams)
    DEVICE_CFG.HVAC_DATA.fanSpeed = tParams.MODE
    C4:UpdateProperty("Fan Speed", tParams.MODE)
    C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"FAN_MODE_CHANGED",{MODE=tParams.MODE})
    promptMsg("Fan Speed set")
  end,
  SET_SCALE = function(tParams)
    C4:UpdateProperty("Temperature Scale",tParams.SCALE)
    C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"SCALE_CHANGED",{SCALE=tParams.SCALE})
    
    local newUnit = nil
    if (tParams.SCALE == "CELSIUS") then
      newUnit = DEVICE_CFG.UNIT_TEMP_C
    elseif (tParams.SCALE == "FAHRENHEIT") then
      newUnit = DEVICE_CFG.UNIT_TEMP_F
    end
    if (newUnit == nil) then
      promptMsg("Unknown temperature unit: " .. tParams.SCALE)
      return
    end

    DEVICE_CFG.HVAC_DATA.unit = newUnit
    if (Utils.initStep < 6) then return end
    if (newUnit == DEVICE_CFG.UNIT_TEMP_F) then
      C4:UpdateProperty("Set Temperature", DEVICE_CFG.HVAC_DATA.setTempInF)
      C4:UpdateProperty("Room Temperature", DEVICE_CFG.HVAC_DATA.roomTempInF)
    else
      C4:UpdateProperty("Set Temperature", DEVICE_CFG.HVAC_DATA.setTempInC)
      C4:UpdateProperty("Room Temperature", DEVICE_CFG.HVAC_DATA.roomTempInC)
    end
    promptMsg("Temperature Scale Set")
  end,
  SET_SETPOINT_HEAT = function(tParams)
    if (DEVICE_CFG.HVAC_DATA.unit ==nil) then
      promptMsg("Temperature unit not decided. Reject any command")
      return
    end
    DEVICE_CFG.HVAC_DATA.setTempInC = tParams.CELSIUS
    DEVICE_CFG.HVAC_DATA.setTempInF = tParams.FAHRENHEIT
    if (DEVICE_CFG.HVAC_DATA.unit == DEVICE_CFG.UNIT_TEMP_C) then
      C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"HEAT_SETPOINT_CHANGED",{SETPOINT=tParams.CELSIUS, SCALE=DEVICE_CFG.UNIT_TEMP_C})
      C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"COOL_SETPOINT_CHANGED",{SETPOINT=tParams.CELSIUS, SCALE=DEVICE_CFG.UNIT_TEMP_C})
      C4:UpdateProperty("Set Temperature", DEVICE_CFG.HVAC_DATA.setTempInC)
    else
      C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"HEAT_SETPOINT_CHANGED",{SETPOINT=tParams.FAHRENHEIT, SCALE=DEVICE_CFG.UNIT_TEMP_F})
      C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"COOL_SETPOINT_CHANGED",{SETPOINT=tParams.FAHRENHEIT, SCALE=DEVICE_CFG.UNIT_TEMP_F})
      C4:UpdateProperty("Set Temperature", DEVICE_CFG.HVAC_DATA.setTempInF)
    end
    promptMsg("Heat set-point set")
  end,
  SET_SETPOINT_COOL = function(tParams)
    if (DEVICE_CFG.HVAC_DATA.unit ==nil) then
      promptMsg("Temperature unit not decided. Reject any command")
      return
    end
    DEVICE_CFG.HVAC_DATA.setTempInC = tParams.CELSIUS
    DEVICE_CFG.HVAC_DATA.setTempInF = tParams.FAHRENHEIT
    if (DEVICE_CFG.HVAC_DATA.unit == DEVICE_CFG.UNIT_TEMP_C) then
      C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"HEAT_SETPOINT_CHANGED",{SETPOINT=tParams.CELSIUS, SCALE=DEVICE_CFG.UNIT_TEMP_C})
      C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"COOL_SETPOINT_CHANGED",{SETPOINT=tParams.CELSIUS, SCALE=DEVICE_CFG.UNIT_TEMP_C})
      C4:UpdateProperty("Set Temperature", DEVICE_CFG.HVAC_DATA.setTempInC)
    else
      C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"HEAT_SETPOINT_CHANGED",{SETPOINT=tParams.FAHRENHEIT, SCALE=DEVICE_CFG.UNIT_TEMP_F})
      C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"COOL_SETPOINT_CHANGED",{SETPOINT=tParams.FAHRENHEIT, SCALE=DEVICE_CFG.UNIT_TEMP_F})
      C4:UpdateProperty("Set Temperature", DEVICE_CFG.HVAC_DATA.setTempInF)
    end
    promptMsg("Cool set-point set")
  end,
  SET_BUTTONS_LOCK = function(tParams)
    --C4:SendToProxy(5001,"BUTTONS_LOCK_CHANGED",{LOCK=true})
    local values = {[true]=true, [1]=true, ["1"]=true}
    local locked = values[tParams.LOCK] or false
    DEVICE_CFG.HVAC_DATA.buttonLock = locked
    C4:SendToProxy(DEVICE_CFG.PROXY_HVAC,"BUTTONS_LOCK_CHANGED",{LOCK=locked})
    promptMsg("Keyboard lock state set")
  end,
}
function updateControlUI(cmdName, tParams)
  Dbg:Debug("Calling " .. cmdName .. "(".. cmdName .. ", " .. Utils.tableToString(tParams) .. ")")
  local handler = UIHandlers[cmdName]
  if (type(handler) ~= "function") then return end
  handler(tParams)
end
------------------------ Light proxy commands ----------------
function  PRX_CMD.SET_MODE_HVAC(idBinding, tParams)
  updateControlUI("SET_MODE_HVAC", tParams)
  execRealFunc(convertToCmdParam("SET_MODE_HVAC", tParams))
end
function  PRX_CMD.SET_MODE_FAN(idBinding, tParams)
  updateControlUI("SET_MODE_FAN", tParams)
  execRealFunc(convertToCmdParam("SET_MODE_FAN", tParams))
end 
function  PRX_CMD.SET_MODE_HOLD(idBinding, tParams)
--  updateControlUI("SET_MODE_HOLD", tParams)
--  execRealFunc(convertToCmdParam("SET_MODE_HOLD", tParams))
  print("This device don't support holding functions")
end
function  PRX_CMD.SET_SCALE(idBinding, tParams)
  updateControlUI("SET_SCALE", tParams) -- CELSIUS/FAHRENHEIT
  execRealFunc(convertToCmdParam("SET_SCALE", tParams))
end
function  PRX_CMD.SET_SETPOINT_HEAT(idBinding, tParams)
-- ReceivedFromProxy(): SET_SETPOINT_HEAT on binding 5001; Call Function SET_SETPOINT_HEAT(): {CELSIUS="21", FAHRENHEIT="70", KELVIN="2942", SETPOINT="70"}
--ReceivedFromProxy: Unhandled command = SET_SETPOINT_HEAT
  updateControlUI("SET_SETPOINT_HEAT", tParams)
  execRealFunc(convertToCmdParam("SET_SETPOINT_HEAT", tParams))
end 
function  PRX_CMD.SET_SETPOINT_COOL(idBinding, tParams)
--ReceivedFromProxy(): SET_SETPOINT_COOL on binding 5001; Call Function SET_SETPOINT_COOL(): {CELSIUS="6", FAHRENHEIT="42", KELVIN="2787", SETPOINT="42"}
  updateControlUI("SET_SETPOINT_COOL", tParams) -- CELSIUS/FAHRENHEIT
  execRealFunc(convertToCmdParam("SET_SETPOINT_COOL", tParams))
end
function  PRX_CMD.SET_BUTTONS_LOCK(idBinding, tParams)
  updateControlUI("SET_BUTTONS_LOCK", tParams) -- CELSIUS/FAHRENHEIT
  execRealFunc(convertToCmdParam("SET_BUTTONS_LOCK", tParams))
end
 
 
------------------------ Lua Action --------------------------
function LUA_ACTION.readAllStates()
  refreshHVACStatus()
end
function LUA_ACTION.sendAllParams()
  local tParams = convertAllToCmdParam()
  execRealFunc(tParams)
end

------------------------ Command interface ------------------
function EX_CMD.UpdateHVAC(tParams)
  updateHVACWithReplay(tParams)
  updateAllControlUI()
end
------------------------ initial driver ----------------------
--function DriverPollingTask()
--  print("Polling task: TBC")
--end
function AfterPropertiesInitialUpdate()
  local propNames = {"Device Index","Modbus Device","Temperature Scale","Mode","Fan Speed","Set Temperature"}
  print("Calling AfterPropertiesInitialUpdate()")
  for i=1,#propNames do
  local name = propNames[i]
    print("Set " .. name, Properties[name])
    OnPropertyChanged(name)
  end
end
function OnPropertyChanged4DriverExt(propName, propValue)
  if (Utils.initStep < 5) then return end
  local propInfo = PropertyInfos[propName]
  if (propInfo == nil) then
    Dbg:Error("Property " .. propName .. " not functional")
    return
  end
  if (propInfo.verifyRule.type == "List") then
    if (propInfo.verifyRule.values[propValue] == nil) then
      Dbg:Error("Property value" .. propValue .. " not valid for " .. propName)
      return
    end
  elseif (propInfo.verifyRule.type=="Number") then
    local value = tonumber(propValue)
    if (value == nil) then
      Dbg:Error("Property \"" .. propName .. "\" must be a number")
      return
    end
    if (type(propInfo.verifyRule.range) == "table") then
      if (value < propInfo.verifyRule.range[1]) or (value > propInfo.verifyRule.range[2]) then
        return "Property \"" .. propName .. "\" should be in range [" .. propInfo.verifyRule.range[1] .. "," .. propInfo.verifyRule.range[2] .. "]"
      end
    end
  end
  propInfo.onPropertyChanged(propInfo, propName, propValue)
end
--function OnTimer4DriverExt(idTimer)
--end
function ON_DRIVER_INIT.Transnet()
  C4:AddVariable("EventCount", 0, "NUMBER")
end
function ON_DRIVER_LATEINIT.Transnet()
  refreshHVACStatus()
  DEVICE_CFG.gotDeviceInfo = true
end
function LUA_ACTION.triggerEvent()
-- This is used for debugging purpose. Ignore it in product
  DEVICE_CFG.eventCnt = DEVICE_CFG.eventCnt + 1
  local newVal = DEVICE_CFG.eventCnt
  C4:SetVariable("EventCount", newVal)
end




