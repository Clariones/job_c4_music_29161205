--- Usage:
--LicenseConfig = {
--  ["Light"]={
--    type=LicenseHandler.TYPE_QUANTITY,
--    value="12",
--  },
--  ["Dimmer"]={
--    type=LicenseHandler.TYPE_DATE,
--    value="2016-3-1",
--  },
--}
--
--LicenseHandler:init(LicenseConfig)
--LicenseHandler:showStatus()
--
--local x = LicenseHandler:consume("Dimmer")
--print(x) -- will show "true" or "false"

LicenseHandler = {
  TYPE_QUANTITY="QUANTITY",
  TYPE_DATE="DATE",
    
  _config = {},
  _usedCount = {},
  _recvStrDatas = {},
  
  _handlers = {
    ['QUANTITY'] = {
      showStatus = function(mng, name, config)
        print(string.format("%s(%s)\t:limit=%s,used=%s",name, tostring(config.type),tostring(config.value),tostring(mng._usedCount[name] or "0")))
      end,
      consume = function(mng, name, cnt)
        cnt = tonumber(cnt) or 1
        if (mng._usedCount[name] == nil) then mng._usedCount[name] = cnt return true end
        if (tonumber(mng._usedCount[name]) >= tonumber(mng._config[name].value)) then return false end
        mng._usedCount[name] = tonumber(mng._usedCount[name]) + cnt
        return true
      end,
    },
    ['DATE'] = {
      showStatus = function(mng, name, config)
        print(string.format("%s(%s)\t:date=%s,now=%s",name, tostring(config.type), os.date("%Y-%m-%d %H:%M:%S",config.value),os.date("%Y-%m-%d %H:%M:%S",os.time())))
      end,
      consume = function(mng, name, cnt)
        return os.time() < mng._config[name].value
      end
    },
  },

  
  init = function(self,tConfig)
    for name,data in pairs(tConfig) do
      self._config[name] = {type=data.type, value=data.value}
      if (data.type == "DATE") then
        local targetDate = self:_toDate(data.value)
        --print(os.date("%Y-%m-%d", targetDate), os.date("%Y-%m-%d %H:%M:%S", targetDate))
        if (targetDate == nil) then
          print(data.value .. " is not a valid date")
          self._config[name].value = 0
        else
          self._config[name].value = targetDate
        end
      end
    end
  end,
  
  showStatus = function(self)
    for name,data in pairs(self._config) do
      local type = data.type
      local handler = self._handlers[type]
      if (handler == nil) then
        print("Unknown license type (" .. type .."). All request will be denied")
      else
        handler.showStatus(self, name, data)
      end
    end
  end,
  
  resetLicense = function(self,name)
    local config = self._config[name]
    if (config == nil) then return end
    if (self._usedCount[name] == nil) then return end
    local type = self._config[name].type
    if (type == "QUANTITY") then self._usedCount[name] = 0
    end
  end,
  
  consume = function(self, name, cnt)
    local config = self._config[name]
    if (config == nil) then return false end
    local handler = self._handlers[config.type]
    if (handler == nil) then return false end
    return handler.consume(self, name, cnt)
  end,
  
  
  _toDate = function(self, strDate)
    local regPtn = "(%d+)%-(%d+)-(%d+)"
    local a,b,y,m,d =string.find(strDate,regPtn)
    if self._isValidDate(y,m,d) then
      return os.time({year=y,month=m,day=d, hour=23, min=59, sec=59})
    else
      return nil
    end
  end,
  
  _isValidDate = function(y,m,d)
    y = tonumber(y)
    m = tonumber(m)
    d = tonumber(d)
    if (d < 1) or (d > 31) then return false end
    if (m > 12) or (m < 1) then return false end
    if (y < 1976) then return false end
    local days = {31,28,31,30,31,30,31,31,30,31,30,31}
    if (m == 2) then
      if ((y % 400) == 0) then
        days[2] = 29
      elseif ((y % 100) ~= 0) and ((y % 4) == 0) then
        days[2] = 29
      end
    end
    return d <= days[m]
  end
}