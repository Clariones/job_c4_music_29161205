require("HC800Simulation")
require("LicenseHandler")

LicenseConfig = {
  ["Light"]={
    type=LicenseHandler.TYPE_QUANTITY,
    value="12",
  },
  ["Dimmer"]={
    type=LicenseHandler.TYPE_DATE,
    value="2016-3-1",
  },
}

LicenseHandler:init(LicenseConfig)
LicenseHandler:showStatus()

local x = LicenseHandler:consume("Dimmer")
print(x) -- will show "true" or "false"

for i=1,13 do
  x = LicenseHandler:consume("Light",2)
  print(i, x)
  LicenseHandler:resetLicense("Light")
end