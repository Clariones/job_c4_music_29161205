require("HC800Simulation")
require("CommonDriverScript")
require("Transnet_HVAC")


Properties = {
  ["Debug Level"]="5 - Debug", 
  ["Debug Mode"]="Print and Log", 
  ["Fan Speed"]="Off", 
  ["Modbus Device"]="1", 
  ["Mode"]="Heat", 
  ["Prompt Message"]="Only Heat/Cool can set temperature", 
  ["Room Temperature"]="0", 
  ["Set Temperature"]="15", 
  ["Temperature Scale"]="CELSIUS",
}
print(Utils.tableToString(Properties))
TEST:Start()
print(Utils.tableToString(Properties))
print(Utils.tableToString(DEVICE_CFG.HVAC_DATA))