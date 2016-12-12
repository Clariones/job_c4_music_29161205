DEVICE_CFG = {
  idx = 1,
  gatewayId = -1,
  adjustment = 25,
  fadingSeconds = 0,
  lastIntensity = 100,
  currentIntensity = 0,
  CONNECTION_TRANSNET = 1,
  PROXY_DIMMER = 5001,
  eventCnt = 1,
  properties = {
    ["Channel Index"] = function(name, value) DEVICE_CFG.toAddress = tonumber(value) or DEVICE_CFG.toAddress end,
    ["Intensity"] = function(name, value)
          local level = intensity2Level(value)
          setDimmerLevel(level, DEVICE_CFG.fadingSeconds*1000)
        end,
    ["Fade Seconds"] = function(name, value) DEVICE_CFG.fadingSeconds = tonumber(value) or DEVICE_CFG.fadingSeconds end,
    ["Adjustment"] = function(name, value) DEVICE_CFG.adjustment = tonumber(value) or DEVICE_CFG.adjustment end,
  },
}

function EX_CMD.GetDriverInfo(tParams)
  local resp = {
    type = "DIMMER",
    c4DriverId = C4:GetDeviceID(),
    deviceIdx = DEVICE_CFG.idx,
  }
  DEVICE_CFG.gatewayId = tonumber(tParams.deviceId)
  C4:SendToDevice(tParams.deviceId, "connectDriver", resp)
end

----------------------- functional methos -----------------
function level2Intensity(level)
  local rst = tonumber(level) or 0
  if (rst <=0 ) then return 0 end
  if (rst >= 100) then return 255 end
  return math.ceil(rst * 255 / 100)
end
function intensity2Level(intensity)
  local rst = tonumber(intensity) or 0
  if (rst <=0 ) then return 0 end
  if (rst >= 255) then return 100 end
  return math.floor(rst * 100 / 255)
end
function mills2Seconds(mills)
  local rst = tonumber(mills) or 0
  if (rst <= 0) then return 0 end
  if (rst >= 255000) then return 255 end
  return math.ceil(rst/1000)
end
function toggleDimmer()
  if (DEVICE_CFG.currentIntensity > 0) then
    setDimmerLevel(0, 0)
  else
    setDimmerLevel(intensity2Level(DEVICE_CFG.lastIntensity), 0)
  end
end
function setDimmerLevel(level, mills)
  local intensity = level2Intensity(level);
  local seconds = mills2Seconds(mills)
  updateControlUI(level, intensity)
  local tParams = {
    action = "AbsoluteLevel",
    dimmerIdx = DEVICE_CFG.idx,
    adjustment = intensity,
    secondsToFade = seconds,
  }
  executeRealFunc(tParams)
end
-------------- Transnet functional communication -------------
function executeRealFunc(tParams)
--    ["action"]={type="List", values={["StopFade"]=0, ["Inc"]=1, ["Dec"]=2,["AbsoluteLevel"]=3}},
--    ["dimmerIdx"] = {type="Number", range={1,12}},
--    ["adjustment"] = {type="Number", range={0,255}},
--    ["secondsToFade"] = {type="Number", range={0,255}},
  Dbg:Debug("Direct Control Dimmer " .. Utils.tableToString(tParams))
  if (DEVICE_CFG.gatewayId <= 0) then
    Dbg:Error("Gateway not connected")
    return
  end
  C4:SendToDevice(DEVICE_CFG.gatewayId, "dimmerDirectControl", tParams)
end
function EX_CMD.updateDimmerIntensity(tParams)
  Dbg:Debug("Call updateDimmerIntensity(" .. Utils.tableToString(tParams) .. ")")
  if tonumber(tParams.intensity) == nil then 
    print("Error input for updateDimmerIntensity: " .. Utils.tableToString(tParams))
    return
  end
  local level = intensity2Level(tParams.intensity)
  updateControlUI(level, tParams.intensity)
end
------------------------ UI related functions ----------------
function updateControlUI(level, intensity)
  level = tonumber(level) or 0
  intensity = tonumber(intensity) or 0
  DEVICE_CFG.currentIntensity = intensity
  C4:UpdateProperty("Intensity", intensity)
  if (intensity > 0) then
    DEVICE_CFG.lastIntensity = intensity
  end
  C4:SendToProxy(DEVICE_CFG.PROXY_DIMMER,"LIGHT_LEVEL_CHANGED",level, "NOTIFY")
end
------------------------ Light proxy commands ----------------
function  PRX_CMD.ON(idBinding, tParams)
  Dbg:Debug("Calling ON(".. idBinding .. ", " .. Utils.tableToString(tParams) .. ")")
  setDimmerLevel(100, 0)
end
function  PRX_CMD.CLICK_TOGGLE_BUTTON(idBinding, tParams)
  Dbg:Debug("Calling CLICK_TOGGLE_BUTTON(".. idBinding .. ", " .. Utils.tableToString(tParams) .. ")")
  toggleDimmer()
end
function  PRX_CMD.TOGGLE(idBinding, tParams)
  Dbg:Debug("Calling TOGGLE(".. idBinding .. ", " .. Utils.tableToString(tParams) .. ")")
  toggleDimmer()
end
function  PRX_CMD.OFF(idBinding, tParams)
  Dbg:Debug("Calling OFF(".. idBinding .. ", " .. Utils.tableToString(tParams) .. ")")
  setDimmerLevel(0, 0)
end
function  PRX_CMD.SET_LEVEL(idBinding, tParams)
  Dbg:Debug("Calling SET_LEVEL(".. idBinding .. ", " .. Utils.tableToString(tParams) .. ")")
  setDimmerLevel(tParams.LEVEL, 0)
end
function  PRX_CMD.RAMP_TO_LEVEL(idBinding, tParams)
  Dbg:Debug("Calling RAMP_TO_LEVEL(".. idBinding .. ", " .. Utils.tableToString(tParams) .. ")")
  setDimmerLevel(tParams.LEVEL, tParams.TIME)
end

------------------------ Lua Action --------------------------
function LUA_ACTION.readDimmerIntensity()
  if (DEVICE_CFG.gatewayId <= 0) then Dbg:Error("Gateway not connected") return end
  C4:SendToDevice(DEVICE_CFG.gatewayId, "readDimmerIntensity", {})
end
function LUA_ACTION.turnOnDimmer()
  setDimmerLevel(100,0)
end
function LUA_ACTION.turnOffDimmer()
  setDimmerLevel(0,0)
end
function LUA_ACTION.incDimmer()
  local tParams = { action="Inc", dimmerIdx=DEVICE_CFG.idx, adjustment=DEVICE_CFG.adjustment, secondsToFade=0}
  local newIntensity = DEVICE_CFG.currentIntensity + DEVICE_CFG.adjustment
  if (newIntensity > 255) then newIntensity = 255 end
  updateControlUI(intensity2Level(newIntensity), newIntensity)
  executeRealFunc(tParams)
end
function LUA_ACTION.decDimmer()
  local tParams = { action="Dec", dimmerIdx=DEVICE_CFG.idx, adjustment=DEVICE_CFG.adjustment, secondsToFade=0}
  local newIntensity = DEVICE_CFG.currentIntensity - DEVICE_CFG.adjustment
  if (newIntensity < 0) then newIntensity = 0 end
  updateControlUI(intensity2Level(newIntensity), newIntensity)
  executeRealFunc(tParams)
end
function LUA_ACTION.stopDimmer()
  local tParams = { action="StopFade", dimmerIdx=DEVICE_CFG.idx, adjustment=DEVICE_CFG.adjustment, secondsToFade=0}
  local newIntensity = DEVICE_CFG.currentIntensity - DEVICE_CFG.adjustment
  if (newIntensity < 0) then newIntensity = 0 end
  updateControlUI(intensity2Level(newIntensity), newIntensity)
  executeRealFunc(tParams)
end

------------------------ Command interface ------------------
function EX_CMD.DirectControl(tParams)
  tParams.dimmerIdx = DEVICE_CFG.idx
  executeRealFunc(tParams)
end

------------------------ initial driver ----------------------
--function DriverPollingTask()
--  print("Polling task: TBC")
--end
function OnPropertyChanged4DriverExt(propName, propValue)
  Utils.handleDriverPropertyChange(DEVICE_CFG.properties, propName, propValue)
end
--function OnTimer4DriverExt(idTimer)
--end
function ON_DRIVER_INIT.Transnet()
  C4:AddVariable("EventCount", 0, "NUMBER")
end

function LUA_ACTION.triggerEvent()
-- This is used for debugging purpose. Ignore it in product
  DEVICE_CFG.eventCnt = DEVICE_CFG.eventCnt + 1
  local newVal = DEVICE_CFG.eventCnt
  C4:SetVariable("EventCount", newVal)
end




