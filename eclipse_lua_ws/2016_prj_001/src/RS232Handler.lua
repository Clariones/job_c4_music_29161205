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
  
  help = function(self)
    print("==========================================================================")
    print("This is RS232 Handler")
    print("Usage:")
    print("  RS232Handler:init({callBack=OnDataRecieved})\n  OR")
    print("  RS232Handler:init({pieceSize=8, pieceTimeout=3,callBack=OnDataRecieved})\n")
    print("  function ReceivedFromSerial(idBinding, strData)")
    print("    RS232Handler:onPieceRecieved(idBinding,strData)")
    print("  end\n")
    print("  OnTimerExpired(idTimer)")
    print("    RS232Handler:onTimer(idTimer)")
    print("  end\n")
    print("  function OnDataRecieved(idBinding, data)")
    print("    --Your data handling code")
    print("  end")
    print("==========================================================================")
  end,
}