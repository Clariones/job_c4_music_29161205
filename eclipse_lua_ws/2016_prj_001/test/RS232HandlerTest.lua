 Dbg = {}
require("HC800Simulation")
require("RS232Handler")

function Dbg.log(str)
  print("DEBUG LOG: " .. (tostring(str) or "nil"))
end

function OnDataRecieved(idBinding, data)
  print("Data received from " .. idBinding .. ": " .. data)
end

RS232Handler:help()
RS232Handler:init({pieceSize=8, pieceTimeout=3,callBack=OnDataRecieved})
local testTimerId = RS232Handler.timerId
RS232Handler:onTimer(testTimerId)

RS232Handler:onPieceRecieved(1,"1234567")

RS232Handler:onPieceRecieved(1,"12345678123")
RS232Handler:onPieceRecieved(2,"90123455")
RS232Handler:onPieceRecieved(1,"abcd")
RS232Handler:onTimer(testTimerId)
RS232Handler:onTimer(testTimerId)
RS232Handler:onTimer(testTimerId)
print(Dbg)