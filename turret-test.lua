local ICore = require("ICore")
local INet = require("INet")
local ITurret = require("ITurret")
local turret = require("component").os_energyturret
local component = require("component")
local text = require("text")

local CMDList = 
{  
  ["fire"] = function(coms)     
		if coms[2] ~= nil and coms[3] ~= nil then
			local count = coms[5] or 1
			for i=1, count do
				ITurret:fireAsyn(tonumber(coms[2] or 0), tonumber(coms[3] or 0), tonumber(coms[4] or 0))
			end
		else
			ICore.IGpu:printLine(1, "Usage: fire <x> <y> <z>", nil, true)	    
		end
   end,   

  ["msgt"] = function(coms)     
    if coms[2] == nil then	  
	  ICore.IGpu:printLine(1, "Usage: msgt <type>", nil, true)	     
	else	  	  
	  if not ICore.IGpu:setCmdType(coms[2]) then	      
	    ICore.IGpu:printLine(1, "Usage type: debug init info warn error", nil, true)	     
	  end
	end
   end,   
}

local args = {...}
local col1, col2 = 1, 25
local pad1, pad2 = col2-1, 50

function display()
	local startLine = 1
	ICore.IGpu:print(col1, startLine + 0, "turret.isPowered:"..tostring(turret.isPowered()), nil, 160)
	ICore.IGpu:print(col1, startLine + 1, "turret.isOnTarget:"..tostring(turret.isOnTarget()), nil, 160)
    ICore.IGpu:print(col1, startLine + 2, "turret.isReady:"..tostring(turret.isReady()), nil, 160)	
	ICore.IGpu:print(col1, startLine + 3, "mission:["..#ITurret.fireStack.."]:"..ICore.IUtils:stackToString(ITurret.fireStack), nil, 160)
	
	ICore.IGpu:fill(col1, startLine + 4, 160, 1, "=")  
end

function main()
	local maxWirelessStrength = tonumber(args[1] or 400)	
	local ibuilder = ICore.IBuilder:setCMDsTop(5):setCMDList(CMDList)	
	if component.isAvailable("modem") then
		local nbuilderClient = INet.NBuilder:setNet(101, ibuilder):setClientNet(onServerMsgCome, onServerCMDCome):SendCMDMsg():SendCopyDisplay():setWirelessStrength(maxWirelessStrength)
		ICore = INet:initialize(nbuilderClient)
	else
		ICore =  ICore:initialize(ibuilder)  
	end
	ITurret:initialize(3)
	while true do
		display()
		os.sleep(1)
	end
end

function onServerMsgCome(CMD, msg)
	
end

function onServerCMDCome(com)	
	ICore.ICMD:execute(com)
end

main()