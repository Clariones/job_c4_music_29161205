
--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
-- Driver Declarations
--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
--[[
  Command Handler Tables
--]]
EX_CMD = {}
PRX_CMD = {}
NOTIFY = {}
DEV_MSG = {}
LUA_ACTION = {}

--[[
Tables of functions
The following tables are function containers that are called within the following functions:  

  OnDriverInit()
    - first calls all functions contained within ON_DRIVER_EARLY_INIT table
    - then calls all functions contained within ON_DRIVER_INIT table
  OnDriverLateInit()
    - calls all functions contained within ON_DRIVER_LATEINIT table
  OnDriverUpdate()
    - calls all functions contained within ON_DRIVER_UPDATE table
  OnDriverDestroyed()
    - calls all functions contained within ON_DRIVER_DESTROYED table
  OnPropertyChanged()
    - calls all functions contained within ON_PROPERTY_CHANGED table
--]]
ON_DRIVER_INIT = {}
ON_DRIVER_EARLY_INIT = {}
ON_DRIVER_LATEINIT = {}
ON_DRIVER_UPDATE = {}
ON_DRIVER_DESTROYED = {}
ON_PROPERTY_CHANGED = {}

-- Constants
DEFAULT_PROXY_BINDINGID = 5001
    
--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
-- Common Driver Code
--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
--[[
  OnPropertyChanged
    Function called by Director when a property changes value.
  Parameters
    sProperty
      Name of property that has changed.
  Remarks
    The value of the property that has changed can be found with: Properties[sName]. Note
    that OnPropertyChanged is not called when the Property has been changed by the driver
    calling the UpdateProperty command, only when the Property is changed by the user from
    the Properties Page. This function is called by Director when a property changes value.
--]]
function OnPropertyChanged(sProperty)
  Dbg:Trace("OnPropertyChanged(" .. sProperty .. ") changed to: " .. Properties[sProperty])

  local propertyValue = Properties[sProperty]
  
  -- Remove any spaces (trim the property)
  local trimmedProperty = string.gsub(sProperty, " ", "")

  -- if function exists then execute (non-stripped)
  if (ON_PROPERTY_CHANGED[sProperty] ~= nil and type(ON_PROPERTY_CHANGED[sProperty]) == "function") then
    ON_PROPERTY_CHANGED[sProperty](propertyValue)
    return
  -- elseif trimmed function exists then execute
  elseif (ON_PROPERTY_CHANGED[trimmedProperty] ~= nil and type(ON_PROPERTY_CHANGED[trimmedProperty]) == "function") then
    ON_PROPERTY_CHANGED[trimmedProperty](propertyValue)
    return
  end
  
  Utils.onPropertyChanged(sProperty, propertyValue)
  if (type(OnPropertyChanged4DriverExt) == "function") then
    OnPropertyChanged4DriverExt(sProperty, propertyValue)
  end
end

function ON_PROPERTY_CHANGED.DebugMode(propertyValue)
  gDebugTimer:KillTimer()
  Dbg:OutputPrint(propertyValue:find("Print") ~= nil)
  Dbg:OutputC4Log(propertyValue:find("Log") ~= nil)
  if (propertyValue == "Off") then return end
  gDebugTimer:StartTimer()
end

function ON_PROPERTY_CHANGED.DebugLevel(propertyValue)
  Dbg:SetLogLevel(tonumber(string.sub(propertyValue, 1, 1)))
end

---------------------------------------------------------------------
-- ExecuteCommand Code
---------------------------------------------------------------------
--[[
  ExecuteCommand
    Function called by Director when a command is received for this DriverWorks driver.
    This includes commands created in Composer programming.
  Parameters
    sCommand
      Command to be sent
    tParams
      Lua table of parameters for the sent command
--]]
function ExecuteCommand(sCommand, tParams)
  Dbg:Trace("ExecuteCommand(" .. sCommand .. "): " .. Utils.tableToString(tParams))

  -- Remove any spaces (trim the command)
  local trimmedCommand = string.gsub(sCommand, " ", "")

  -- if function exists then execute (non-stripped)
  if (EX_CMD[sCommand] ~= nil and type(EX_CMD[sCommand]) == "function") then
    EX_CMD[sCommand](tParams)
  -- elseif trimmed function exists then execute
  elseif (EX_CMD[trimmedCommand] ~= nil and type(EX_CMD[trimmedCommand]) == "function") then
    EX_CMD[trimmedCommand](tParams)
  -- handle the command
  elseif (EX_CMD[sCommand] ~= nil) then
    QueueCommand(EX_CMD[sCommand])
  else
    Dbg:Alert("ExecuteCommand: Unhandled command = " .. sCommand)
  end
end

--[[
  Define any functions of commands (EX_CMD.<command>) received from ExecuteCommand that need to be handled by the driver.
--]]

--[[
  EX_CMD.LUA_ACTION
    Function called for any actions executed by the user from the Actions Tab in Composer.
--]]
function EX_CMD.LUA_ACTION(tParams)
  if tParams ~= nil then
    for cmd,cmdv in pairs(tParams) do
      if cmd == "ACTION" then
        if (LUA_ACTION[cmdv] ~= nil) then
          LUA_ACTION[cmdv]()
        else
          Dbg:Alert("Undefined Action")
          Dbg:Alert("Key: " .. cmd .. " Value: " .. cmdv)
        end
      else
        Dbg:Alert("Undefined Command")
        Dbg:Alert("Key: " .. cmd .. " Value: " .. cmdv)
      end
    end
  end
end

--[[
  LUA_ACTION.DisplayGlobals
    Implementation of Action "Display Globals". Executed when selecting the "Display Globals" action within Composer.
    Provided as an example for actions.
--]]
function LUA_ACTION.DisplayGlobals()
  print ("Global Variables")
  print ("----------------------------")

  for k,v in pairs(_G) do -- globals`
    if not (type(v) == "function") then
      --print(k .. ":  " .. tostring(v))
      if (string.find(k, "^g%L")  == 1) then
        print(k .. ":  " .. tostring(v))
        if (type(v) == "table") then
          PrintTable(v, "   ")
        end
      end
    end
  end

  print ("")
end

function PrintTable(tValue, sIndent)
  sIndent = sIndent or "   "
  for k,v in pairs(tValue) do
    print(sIndent .. tostring(k) .. ":  " .. tostring(v))
    if (type(v) == "table") then
      PrintTable(v, sIndent .. "   ")
    end
  end
end

---------------------------------------------------------------------
-- ReceivedFromProxy Code
---------------------------------------------------------------------
--[[
  ReceivedFromProxy(idBinding, sCommand, tParams)
    Function called by Director when a proxy bound to the specified binding sends a
    BindMessage to the DriverWorks driver.

  Parameters
    idBinding
      Binding ID of the proxy that sent a BindMessage to the DriverWorks driver.
    sCommand
      Command that was sent
    tParams
      Lua table of received command parameters
--]]
function ReceivedFromProxy(idBinding, sCommand, tParams)
  if (sCommand ~= nil) then
    if(tParams == nil)    -- initial table variable if nil
      then tParams = {}
    end
    Dbg:Trace("ReceivedFromProxy(): " .. sCommand .. " on binding " .. idBinding .. "; Call Function " .. sCommand .. "(): " .. Utils.tableToString(tParams))

    if (PRX_CMD[sCommand]) ~= nil then
      PRX_CMD[sCommand](idBinding, tParams)
    else
      Dbg:Alert("ReceivedFromProxy: Unhandled command = " .. sCommand)
    end
  end
end

---------------------------------------------------------------------
-- Notification Code
---------------------------------------------------------------------
-- notify with parameters
function SendNotify(notifyText, Parms, bindingID)
  C4:SendToProxy(bindingID, notifyText, Parms, "NOTIFY")
end

-- A notify with no parameters
function SendSimpleNotify(notifyText, ...)
  bindingID = select(1, ...) or DEFAULT_PROXY_BINDINGID
  C4:SendToProxy(bindingID, notifyText, {}, "NOTIFY")
end

---------------------------------------------------------------------
-- Initialization/Destructor Code
---------------------------------------------------------------------
--[[
  OnDriverInit
    Invoked by director when a driver is loaded. This API is provided for the driver developer to contain all of the driver
    objects that will require initialization.
--]]
function OnDriverInit()
  C4:ErrorLog("INIT_CODE: OnDriverInit()")
  -- Call all ON_DRIVER_EARLY_INIT functions.
  for k,v in pairs(ON_DRIVER_EARLY_INIT) do
    if (ON_DRIVER_EARLY_INIT[k] ~= nil and type(ON_DRIVER_EARLY_INIT[k]) == "function") then
      C4:ErrorLog("INIT_CODE: ON_DRIVER_EARLY_INIT." .. k .. "()")
      ON_DRIVER_EARLY_INIT[k]()
    end
  end

  -- Call all ON_DRIVER_INIT functions
  for k,v in pairs(ON_DRIVER_INIT) do
    if (ON_DRIVER_INIT[k] ~= nil and type(ON_DRIVER_INIT[k]) == "function") then
      C4:ErrorLog("INIT_CODE: ON_DRIVER_INIT." .. k .. "()")
      ON_DRIVER_INIT[k]()
    end
  end

  -- Fire OnPropertyChanged to set the initial Headers and other Property global sets, they'll change if Property is changed.
  for k,v in pairs(Properties) do
    OnPropertyChanged(k)
  end
  
  Utils.initStep = 5
  
  if (type(AfterPropertiesInitialUpdate) == "function") then
    AfterPropertiesInitialUpdate()
  end
  
  Utils.initStep = 6
end

--[[
  OnDriverUpdate
    Invoked by director when an update to a driver is requested. This request can occur either by adding a new version of a driver
    through the driver search list or right clicking on the driver and selecting "Update Driver" from within ComposerPro.
    Its purpose is to initialize all components of the driver that are reset during a driver update.
--]]
function OnDriverUpdate()
  C4:ErrorLog("INIT_CODE: OnDriverUpdate()")
  
  -- Call all ON_DRIVER_UPDATE functions
  for k,v in pairs(ON_DRIVER_UPDATE) do
    if (ON_DRIVER_UPDATE[k] ~= nil and type(ON_DRIVER_UPDATE[k]) == "function") then
      C4:ErrorLog("INIT_CODE: ON_DRIVER_UPDATE." .. k .. "()")
      ON_DRIVER_UPDATE[k]()
    end
  end
end

--[[
  OnDriverLateInit
    Invoked by director after all drivers in the project have been loaded. This API is provided
    for the driver developer to contain all of the driver objects that will require initialization
    after all drivers in the project have been loaded.
--]]
function OnDriverLateInit()
  C4:ErrorLog("INIT_CODE: OnDriverLateInit()")
  
  -- Call all ON_DRIVER_LATEINIT functions
  for k,v in pairs(ON_DRIVER_LATEINIT) do
    if (ON_DRIVER_LATEINIT[k] ~= nil and type(ON_DRIVER_LATEINIT[k]) == "function") then
      C4:ErrorLog("INIT_CODE: ON_DRIVER_LATEINIT." .. k .. "()")
      ON_DRIVER_LATEINIT[k]()
    end
  end
end


--[[
  OnDriverDestroyed
    Function called by Director when a driver is removed. Release things this driver has allocated such as timers.
--]]
function OnDriverDestroyed()
  C4:ErrorLog("INIT_CODE: OnDriverDestroyed()")
  -- Call all ON_DRIVER_DESTROYED functions
  for k,v in pairs(ON_DRIVER_DESTROYED) do
    if (ON_DRIVER_DESTROYED[k] ~= nil and type(ON_DRIVER_DESTROYED[k]) == "function") then
      C4:ErrorLog("INIT_CODE: ON_DRIVER_DESTROYED." .. k .. "()")
      ON_DRIVER_DESTROYED[k]()
    end
  end
end

--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
-- Debug Logging Code
--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
Log = {}

-- Create a Table with Logging functions
function Log:Create()
  
  -- table for logging functions
  local lt = {}
  
  lt._logLevel = 0
  lt._outputPrint = false
  lt._outputC4Log = false
  lt._logName =  "Set Log Name to display"
  
  function lt:SetLogLevel(level)
    self._logLevel = level
  end
  
  function lt:OutputPrint(value)
    self._outputPrint = value
  end
  
  function lt:OutputC4Log(value)
    self._outputC4Log = value
  end
  
  function lt:SetLogName(name)
    self._logName = name
  end

  function lt:Enabled()
    return (self._outputPrint or self._outputC4Log)
  end
  
  function lt:PrintTable(tValue, sIndent)
    if (type(tValue) == "table") then
      if (self._outputPrint) then
        for k,v in pairs(tValue) do
          print(sIndent .. tostring(k) .. ":  " .. tostring(v))
          if (type(v) == "table") then
            self:PrintTable(v, sIndent .. "   ")
          end
        end
      end
  
      if (self._outputC4Log) then
        for k,v in pairs(tValue) do
          C4:ErrorLog(self._logName .. ": " .. sIndent .. tostring(k) .. ":  " .. tostring(v))
          if (type(v) == "table") then
            self:PrintTable(v, sIndent .. "   ")
          end
        end
      end

    else
      if (self._outputPrint) then
        print (sIndent .. tValue)
      end
      
      if (self._outputC4Log) then
        C4:ErrorLog(self._logName .. ": " .. sIndent .. tValue)
      end
    end
  end
    
  function lt:Print(logLevel, sLogText)
    if (self._logLevel >= logLevel) then
      if (type(sLogText) == "table") then
        self:PrintTable(sLogText, "   ")
        return
      end
      
      if (self._outputPrint) then
        print (sLogText)
      end

      if (self._outputC4Log) then
        C4:ErrorLog(self._logName .. ": " .. sLogText)
      end
    end
  end
  
  function lt:Alert(strDebugText)
    self:Print(0, strDebugText)
  end
  
  function lt:Error(strDebugText)
    self:Print(1, strDebugText)
  end
  
  function lt:Warn(strDebugText)
    self:Print(2, strDebugText)
  end
  
  function lt:Info(strDebugText)
    self:Print(3, strDebugText)
  end
  
  function lt:Trace(strDebugText)
    self:Print(4, strDebugText)
  end
  
  function lt:Debug(strDebugText)
    self:Print(5, strDebugText)
  end
  
  return lt
end

function ON_DRIVER_EARLY_INIT.LogLib()
  -- Create and initialize debug logging
  Dbg = Log.Create()
  Dbg:SetLogName("base_template PLEASE CHANGE")
end

function ON_DRIVER_INIT.LogLib()
  -- Create Debug Timer
  gDebugTimer = Timer:Create("Debug", 45, "MINUTES", OnDebugTimerExpired)
end

--[[
  OnDebugTimerExpired
    Debug timer callback function
--]]
function OnDebugTimerExpired()
  Dbg:Warn("Turning Debug Mode Off (timer expired)")
  gDebugTimer:KillTimer()
  C4:UpdateProperty("Debug Mode", "Off")
  OnPropertyChanged("Debug Mode")
end
      
---------------------------------------------------------------------
-- Timer Code
---------------------------------------------------------------------
Timer = {}

-- Create a Table with Timer functions
function Timer:Create(name, interval, units, Callback, repeating, Info)
  -- timers table
  local tt = {}
  
  tt._name = name
  tt._timerID = TimerLibGetNextTimerID()
  tt._interval = interval
  tt._units = units
  tt._repeating = repeating or false
  tt._Callback = Callback
  tt._info = Info or ""
  tt._id = 0

  function tt:StartTimer(...)
    self:KillTimer()
    
    -- optional parameters (interval, units, repeating)
    if ... then
      local interval = select(1, ...)
      local units = select(2, ...)
      local repeating = select(3, ...)
      
      self._interval = interval or self._interval
      self._units = units or self._units
      self._repeating = repeating or self._repeating
    end
    
    if (self._interval > 0) then
      Dbg:Trace("Starting Timer: " .. self._name)
      self._id = C4:AddTimer(self._interval, self._units, self._repeating)
    end
  end

  function tt:KillTimer()
    if (self._id) then
      self._id = C4:KillTimer(self._id)
    end
  end
  
  function tt:TimerStarted()
    return (self._id ~= 0)
  end
      
  function tt:TimerStopped()
    return not self:TimerStarted()
  end
  
  gTimerLibTimers[tt._timerID] = tt
  Dbg:Trace("Created timer " .. tt._name)
  
  return tt
end

function TimerLibGetNextTimerID()
  gTimerLibTimerCurID = gTimerLibTimerCurID + 1
  return gTimerLibTimerCurID
end

function ON_DRIVER_EARLY_INIT.TimerLib()
  gTimerLibTimers = {}
  gTimerLibTimerCurID = 0
end

function ON_DRIVER_DESTROYED.TimerLib()
  -- Kill open timers
  for k,v in pairs(gTimerLibTimers) do
    v:KillTimer()
  end
end

--[[
  OnTimerExpired
    Function called by Director when the specified Control4 timer expires.
  Parameters
    idTimer
      Timer ID of expired timer.
--]]
function OnTimerExpired(idTimer)
  for k,v in pairs(gTimerLibTimers) do
    if (idTimer == v._id) then
      if (v._Callback) then
        v._Callback(v._info)
      end
    end
  end
  
  if (type(OnTimer4DriverExt)=="function") then
    OnTimer4DriverExt(idTimer)
  end
end
      
      
-------------------------------------------------------------------------------
-- Below are common driver script

------------------ RS232 assembler -----------------
RS232Handler = {
  _config = {pieceSize=8, pieceTimeout=3, callBack=nil},
  _recvStrDatas = {},
  _timerId = nil,
  
  onPieceRecieved = function(self, idBinding, strData)
    if strData == nil then return end
    
    local tgtTbl = self._recvStrDatas[idBinding]
    if (tgtTbl == nil) then 
      self._recvStrDatas[idBinding] = {timerCnt=0,datas={}} 
      tgtTbl = self._recvStrDatas[idBinding]
    end
    table.insert(tgtTbl.datas, strData)
    if (self:_isLastPiece(strData)) then
      tgtTbl.timerCnt = 0
      self:_handleFrameData(idBinding)
    else
      tgtTbl.timerCnt = self._config.pieceTimeout
    end
  end,
  
  _isLastPiece = function(self, strData)
    return #strData < self._config.pieceSize
  end,
  
  onTimer = function(self, idTimer)
    if not self._timerId then print("RS232 Handler not inited") return end
    if (idTimer ~= self._timerId) then return end
    -- Now it's my duty call
    self:_cutdownTimer()
  end,
  
  init = function(self, arg)
    if (arg.pieceSize) then self._config.pieceSize = arg.pieceSize end
    if (arg.pieceTimeout) then self._config.pieceTimeout = arg.pieceTimeout end
    self._config.callBack = arg.callBack
    if (type(self._config.callBack) ~= "function") then
      print("!!!You must init RS232 with a data reciever callback function!")
      print("!!!You must init RS232 with a data reciever callback function!!")
      print("!!!You must init RS232 with a data reciever callback function!!!")
      print("like RS232Handler:init({pieceSize=8, pieceTimeout=3,callBack=OnDataRecieved})")
      print("   (Important things must say 3 times)")
      return
    end
    
    self._timerId = C4:AddTimer(10, "MILLISECONDS", true)
  end,
  
  _cutdownTimer = function(self)
    for idBinding,tbl in pairs(self._recvStrDatas) do
      if (tbl.timerCnt > 0) then
        tbl.timerCnt = tbl.timerCnt-1
        if (tbl.timerCnt == 0) then
          self:_handleFrameData(idBinding)
        end
      end
    end
  end,
  
  _handleFrameData = function(self, idBinding)
    local tbl = self._recvStrDatas[idBinding]
    
    local str = "";
    local len = #tbl.datas
    if (len < 1) then
      return
    end
  
    for k=1,len do
      str =  str .. tbl.datas[k]
    end
    tbl.datas = {}
    self._config.callBack(idBinding, str)
  end,
}

------------------------------------------------------
---------------- Common Utils ------------------------
Utils = {
  DUMP_DATA_ALL = "All",
  DUMP_DATA_NO = "No",
  DUMP_DATA_RECIEVED = "Recieved",
  OFF = "Off",
  ON = "On",
    
  dumpData = "No",
  
  initStep = 0,
  
  pollingTimer = nil,
  pollingDelayTimer = nil,
  pollingSeconds = 0,
  pollingDelaySeconds = 0,
}
function Utils.TemperatureF2C(fahrenheit)
  return (tonumber(fahrenheit) - 32) / 1.8
end

function Utils.TemperatureC2F(celsius)
  return tonumber(celsius) * 1.8 + 32
end
function Utils.byte0 (data)
  return bit.band(data, 0xFF)
end

function Utils.byte1 (data)
  return bit.band(bit.rshift(data, 8), 0xFF)
end
function Utils.BEtoUShort (strData)
  local rst = 0;
  local byte0, byte1 = string.byte(strData,1,2)
  return byte0 * 256 + byte1
end
function Utils.BEtoShort (strData)
  local rst = Utils.BEtoUShort(strData)
  if (rst > 0x7FFF) then
    return rst - 0x10000
  end
  return rst
end
function Utils.LEtoUShort (strData)
  local rst = 0;
  local byte0, byte1 = string.byte(strData,1,2)
  return byte1 * 256 + byte0
end
function Utils.LEtoShort (strData)
  local rst = Utils.LEtoUShort(strData)
  if (rst > 0x7FFF) then
    return rst - 0x10000
  end
  return rst
end
function Utils.isEmpty(something)
  if (something == nil) then return true end
  if (type(something) == "table") then
    for k,v in pairs(something) do
      return false
    end
    return true
  elseif (type(something) == "string") then
    return string.len(something) == 0
  end
  return false
end
function Utils.getSortedKeys(tbl)
  local keyTbl = {}
  for k,v in pairs(tbl) do
    table.insert(keyTbl,k)
  end
  table.sort(keyTbl)
  return keyTbl
end
function Utils.tableToString(tbl)
  if (type(tbl) ~= "table") then return "Not a table: " .. tostring(tbl) end
  local rstStr = "{"
  local keyTbl = Utils.getSortedKeys(tbl)
  for i,k in pairs(keyTbl) do
    local v = tbl[k]
    if (type(v) == "table") then
      if (rstStr ~= "{") then
        rstStr = rstStr .. ", "
      end
      rstStr = rstStr .. k .. "=" .. Utils.tableToString(v)
    else
      if (rstStr ~= "{") then
        rstStr = rstStr .. ", "
      end
      rstStr = rstStr .. k .. "="
      if (type(v) == "string") then
        rstStr = rstStr .. "\"" .. (tostring(v) or "nil") .. "\""
      else
        rstStr = rstStr .. (tostring(v) or "nil")
      end
    end
  end
  return rstStr .. "}"
end
function Utils.verifyTableParams(tRules, tParams)
  for name,rule in pairs(tRules) do
    if (rule.type=="Number") then
      local value = tonumber(tParams[name] or "nil")
      if (value == nil) then
        return "Member \"" .. name .. "\" must be a number"
      end
      if (type(rule.range) == "table") then
        if (value < rule.range[1]) or (value > rule.range[2]) then
          return "Member \"" .. name .. "\" should be in range [" .. rule.range[1] .. "," .. rule.range[2] .. "]"
        end
      end
    elseif (rule.type == "List") then
      local value = rule.values[tParams[name] or "nil"]
      if (value == nil) then
        local keys = Utils.getSortedKeys(rule.values)
        return "Member \"" .. name .. "\" should be one of: " .. table.concat(keys,"/")
      end
    else
      return "Not supported verify rule \"".. rule.type .."\""
    end
  end
  return nil
end
function Utils.printCurrentTime()
  print("Current Time:", os.date("%Y-%m-%d %H:%M:%S",os.time()))
end
---------- Polling task related methods -------------
function Utils.pollingTask()
--  print("pollingTask()")
--  Utils.printCurrentTime()
  if (type(DriverPollingTask) == "function") then
    DriverPollingTask()
  end
end
function Utils.startPollingTask()
--  print("startPollingTask()")
--  Utils.printCurrentTime()
  Utils.pollingTimer = Timer:Create("polling timer", Utils.pollingSeconds, "SECONDS", Utils.pollingTask, true, "polling timer")
  Utils.pollingTask()
  Utils.pollingTimer:StartTimer()
end
function Utils.startPollingTimer()
--  print("startPollingTimer()")
--  Utils.printCurrentTime()
  if (Utils.pollingDelayTimer) then
     Utils.pollingDelayTimer:KillTimer()
  end
  if (Utils.pollingTimer) then
     Utils.pollingTimer:KillTimer()
  end
  
  if (Utils.pollingSeconds <= 0) then return end -- If polling-seconds value not a positive number, then do not start polling task
  if (Utils.pollingDelaySeconds > 0) then 
    -- If user want start polling after several seconds, then create task which will create real polling task
    Utils.pollingDelayTimer = Timer:Create("polling delay timer", Utils.pollingDelaySeconds, "SECONDS", Utils.startPollingTask, false, "polling delay timer")
    Utils.pollingDelayTimer:StartTimer()
  else
    Utils.startPollingTask()
  end
end
function ON_DRIVER_LATEINIT.PollingTask()
  Utils.startPollingTimer()
end
----------- Common properties related methods -------------
function Utils.onPropertyChanged(propName, propVal)
  if (propName == "Polling Dealy Seconds") then
    Utils.pollingDelaySeconds = tonumber(propVal) or 0
    if (Utils.initStep >= 5) then Utils.startPollingTimer() end
  elseif (propName == "Polling Period Seconds") then
    Utils.pollingSeconds = tonumber(propVal) or 0
    if (Utils.initStep >= 5) then Utils.startPollingTimer() end
  elseif (propName == "Dump Data") then
    Utils.dumpData = propVal
  end
end
function Utils.handleDriverPropertyChange(tblCfg, propName, propValue)
  local cfg = tblCfg[propName]
  if (type(cfg) == "function") then cfg(propName, propValue) return end
end




