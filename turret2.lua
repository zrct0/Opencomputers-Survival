local ICore = require("ICore")
local INet = require("INet")
local ITurret = require("ITurret")
local Vector3 = require("IVector3")
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

local whiteList = {"Experience Orb", "经验球", "item", "Arrow", "Energy"}

local args = {...}
local col1, col2 = 1, 25
local pad1, pad2 = col2-1, 50
local w, h
local height = 1
local port = 101

function display()
	local startLine = 1
	ICore.IGpu:print(col1, startLine + 0, "turret.isPowered:"..tostring(turret.isPowered()), nil, 160)
	ICore.IGpu:print(col1, startLine + 1, "turret.isOnTarget:"..tostring(turret.isOnTarget()), nil, 160)
    ICore.IGpu:print(col1, startLine + 2, "turret.isReady:"..tostring(turret.isReady()), nil, 160)	
	ICore.IGpu:print(col1, startLine + 3, "mission:["..#ITurret.fireStack.."]:"..ICore.IUtils:stackToString(ITurret.fireStack), nil, 160)
	
	ICore.IGpu:fill(col1, startLine + 4, 160, 1, "=")  
end

function main()
	height = tonumber(args[1] or 1)	
	port = tonumber(args[2] or 101)
	local maxWirelessStrength = tonumber(args[2] or 400)	
	local ibuilder = ICore.IBuilder:setCMDsTop(5):setCMDList(CMDList)	
	if component.isAvailable("modem") then
		local nbuilderClient = INet.NBuilder:setNet(port, ibuilder):setClientNet(onServerMsgCome, onServerCMDCome):SendCMDMsg():SendCopyDisplay():setWirelessStrength(maxWirelessStrength)
		ICore = INet:initialize(nbuilderClient)
	else
		ICore =  ICore:initialize(ibuilder)  
	end
	ITurret:initialize()
	ICore.IThread:create(start, self, "start")
	ICore.IThread:create(display_thread, self, "display_thread")
end

function display_thread()
	while true do
		os.sleep(1)
		display()
	end
end

function start()
	os.sleep(1)
	while true do
		display()
		local targetPos = findTarget()
		if targetPos then			
			ITurret:fireSync(targetPos.x, targetPos.y, targetPos.z - height)
		else
			os.sleep(10)
			display()
			ICore:info("no target")
		end
	end
end

function findTarget()
	local mobData = ICore.IComponent:invoke("os_entdetector", "scanEntities", 64)
	local target	
	local targetDistance = 999
	local targetPos
	if mobData and type(mobData) == "table" then
		for k, v in pairs(mobData) do
			local pos = Vector3:new(v.x, v.z, v.y)
			local distance = pos:magnitude()	
			if distance < targetDistance and not ICore.IUtils:isTableContain(whiteList, v.name) then
				target = v			
				targetPos = pos
				targetDistance = distance
			end
			
		end
	end
	if target then
		ICore:info("Find target ["..target.name.."] in"..tostring(targetPos))	
		return targetPos
	else
		return false
	end
end

function onServerMsgCome(CMD, msg)
	
end

function onServerCMDCome(com)	
	ICore.ICMD:execute(com)
end

main()