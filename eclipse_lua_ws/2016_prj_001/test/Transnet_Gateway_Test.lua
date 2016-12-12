require("HC800Simulation")
require("CommonDriverScript")
require("Transnet_Gateway")




TEST:AddDevice({id=66, name="Transnet Gateway"})
TEST:AddDevice({id=67, name="Dimmer 1"})
TEST:ConnectDevice(67,1,66,2)
TEST:WorkOnDevice(66)
Properties = {
  ["Debug Level"] = "5 - Debug",
  ["Debug Mode"] = "Print",
  ["Polling Dealy Seconds"] = "0",
  ["Polling Period Seconds"] = "0",
  ["Dump Data"] = "No",
  ["To Address"] = "2",
  ["Source Address"] = "1",
}
TEST:Start()

--------------------------------------------------
--local tParams = {type="DIMMER", c4DriverId=67, deviceIdx=1}
--_connectDriver(tParams)
--tParams = {type="DIMMER", c4DriverId=68, deviceIdx=2}
--_connectDriver(tParams)
--print(Utils.tableToString(DEVICE_CFG.connectedDevices))
--print(Utils.tableToString(DEVICE_CFG.connectedDrivers))
--------------------------------------------------

TEST:Command("connectDriver",{type="DIMMER", c4DriverId=67, deviceIdx=1})
TEST:Command("connectDriver",{type="DIMMER", c4DriverId=68, deviceIdx=2})
 --TEST:Command("connectDriver",{type="DIMMER", c4DriverId=69, deviceIdx=3})
TEST:Command("connectDriver",{type="DIMMER", c4DriverId=70, deviceIdx=4})
TEST:Command("connectDriver",{type="FAN_COIL", c4DriverId=71, deviceIdx=10})


TEST:Command("readDimmerIntensity",{})

--DebugRecieveRS232("AA 55 01 02 07 07 64 00 12 ab 34 44 0D 0A")
--TEST:Action("showDeviceStatus")

--DebugRecieveRS232("AA 55 01 02 05 92 10 20 30 40 0D 0A")
----DebugRecieveRS232("AA 55 00 02 07 07 64 00 14 20 30 40 0D 0A")     
--TEST:Action("showDeviceStatus")
--TEST:Command("fanCoilDirectControl",{fromDevice=10, fanSpeed="High", keyboardLock="NoChange", modbusDeviceName=1, mode="NoChange", state="NoChange", temperature=0})
--TEST:Command("readFanCoil", {fromDevice=10, modbusDeviceName=1})
--TEST:Action("showDeviceStatus")
--DebugRecieveRS232("AA 55 01 02 0F 52 64 00 01 00 01 01 01 00 FA 00 0E 01 00 00 0D 0A")

TEST:Command("activateScene",{sceneNumber=128})
TEST:Command("incScene",{sceneNumber=128})
TEST:Command("decScene",{sceneNumber=128})
TEST:Command("stopFadeScene",{sceneNumber=128})
TEST:Command("saveStateAsScene",{sceneNumber=128,option="Save",areaNo="23"})
TEST:Command("saveStateAsScene",{sceneNumber=128,option="Trigger",areaNo="23"})
TEST:Command("saveStateAsScene",{sceneNumber=128,option="Delete",areaNo="23"})
