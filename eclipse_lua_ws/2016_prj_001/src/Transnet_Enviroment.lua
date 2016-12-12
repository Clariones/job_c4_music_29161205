DEVICE_CFG = {
  idx = 1,
  gatewayId = -1,
  CONNECTION_TRANSNET = 1,
  eventCnt = 1,
  modbusAddr = 1,
  properties = {
    ["Modbus Device Address"] = function(name, value) DEVICE_CFG.modbusAddr = tonumber(value) end,
    ["Device Index"] = function(name, value) DEVICE_CFG.idx = tonumber(value) end,
  }
}
function EX_CMD.GetDriverInfo(tParams)
  local resp = {
    type = "ENVIRONMENT",
    c4DriverId = C4:GetDeviceID(),
    deviceIdx = DEVICE_CFG.idx,
  }
  DEVICE_CFG.gatewayId = tonumber(tParams.deviceId)
  C4:SendToDevice(tParams.deviceId, "connectDriver", resp)
end


----------------------- functional methos --------------------
function promptMsg(strMsg)
  if (strMsg == nil) then return end
  print("MESSAGE", strMsg)
  C4:UpdateProperty("Prompt Message",strMsg)
end
function readEnvironmentalStatus()
  execRealCmd()
end
function execRealCmd()
  if (DEVICE_CFG.gatewayId <= 0) then
    promptMsg("Gateway not connected. Cannot execute any command")
    return
  end
  Dbg:Debug("Will execute " .. Utils.tableToString(tParams))
  local tParams={fromDevice=DEVICE_CFG.idx, modbusDeviceName=DEVICE_CFG.modbusAddr}
  C4:SendToDevice(DEVICE_CFG.gatewayId, "readEnvironmentalStatus", tParams)
end
function updateEnvData(tParams)
  local function updateVar(name, value, unit, variable)
    value = value or 0
    C4:UpdateProperty(name,value .. " (" .. unit .. ")")
    C4:SetVariable(variable,value)
  end
  updateVar("Room Temperature", tParams.roomTemperature/10, "C", "Room Temperature")
  updateVar("CO2", tParams.co2PPM, "PPM", "CO2")
  updateVar("PM2.5", tParams.pm2d5, "ug", "PM2.5")
  updateVar("Humidity", tParams.humidity, "%", "Humidity")
end
------------------------ UI related functions ----------------
UIHandlers = {
} 
------------------------ Lua Action --------------------------
function LUA_ACTION.queryStatus()
  readEnvironmentalStatus()
end
------------------------ Command interface ------------------
function EX_CMD.ReadEnvironmentStatus(tParams)
  readEnvironmentalStatus()
end
function EX_CMD.UpdateEnvironmentStatus(tParams)
  updateEnvData(tParams)
end
------------------------ initial driver ----------------------
function DriverPollingTask()
  readEnvironmentalStatus()
end
function OnPropertyChanged4DriverExt(propName, propValue)
  Utils.handleDriverPropertyChange(DEVICE_CFG.properties, propName, propValue)
end
--function OnTimer4DriverExt(idTimer)
--end
function ON_DRIVER_INIT.Transnet()
  C4:AddVariable("Room Temperature", 0, "NUMBER")
  C4:AddVariable("CO2", 0, "NUMBER")
  C4:AddVariable("PM2.5", 0, "NUMBER")
  C4:AddVariable("Humidity", 0, "NUMBER")
  C4:AddVariable("EventCount", 0, "NUMBER")
end
function ON_DRIVER_LATEINIT.Transnet()
  refreshHVACStatus()
end
function LUA_ACTION.triggerEvent()
-- This is used for debugging purpose. Ignore it in product
  DEVICE_CFG.eventCnt = DEVICE_CFG.eventCnt + 1
  local newVal = DEVICE_CFG.eventCnt
  C4:SetVariable("EventCount", newVal)
end




