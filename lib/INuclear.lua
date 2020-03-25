local INuclear = {}
local NBuilder = {}
local RRedIO = {}
local RTransposer = {}
local INet = require("INet")

local ICore = require("ICore")
local component = require("component")

INuclear.NBuilder = NBuilder
INuclear.RRedIO = RRedIO
INuclear.RTransposer = RTransposer

INuclear.RETORNAME = component.isAvailable("reactor_chamber") and "reactor_chamber" or "reactor"

INuclear.builder = nil

function INuclear:initialize(builder)	
	INuclear.builder = builder	
	if component.isAvailable("modem") then
		ICore = INet:initialize(builder.netBuilder)
	else
		ICore =  ICore:initialize(builder.netBuilder.iCorebuilder) 		
	end	
	INuclear.RRedIO:adapte()
	INuclear.RTransposer:adapte()
	return ICore
end

function INuclear:isRunning()
	return ICore.IComponent:invoke(INuclear.RETORNAME, "producesEnergy") or false
end

function INuclear:getHeat()
	return ICore.IComponent:invoke(INuclear.RETORNAME, "getHeat") or 0
end

function INuclear:getMaxHeat()
	return ICore.IComponent:invoke(INuclear.RETORNAME, "getMaxHeat") or 0
end

function INuclear:getReactorEUOutput()
	return ICore.IComponent:invoke(INuclear.RETORNAME, "getReactorEUOutput") or 0
end

function INuclear:getReactorEnergyOutput()
	return ICore.IComponent:invoke(INuclear.RETORNAME, "getReactorEnergyOutput") or 0
end

--<============NBuilder=============>

function NBuilder:setNetBuilder(builder)
	NBuilder.netBuilder = builder
	return NBuilder
end

function NBuilder:setScanReactorCallback(_scanReactorCallback)
	NBuilder.scanReactorCallback = _scanReactorCallback
	return NBuilder
end

--<============RTransposer=============>

RTransposer.chestSide = 0
RTransposer.reactorSide = 0
RTransposer.map = {}
RTransposer.runtimeMap = {}

function RTransposer:adapte(chestName)
  chestName = chestName or "tile.chest"
  reactorName = reactorName or "ic2"
  ICore:init("RTransposer start adapte") 
  if not component.isAvailable("transposer")then 
	ICore:error("Cannot find transposer")
	return false
  end
  for i=0, 5 do    
	local inventoryName = ICore.IComponent:invoke("transposer", "getInventoryName", i)	
	ICore:init("inventoryName:", inventoryName)
	if inventoryName then
		if inventoryName == chestName then
			RTransposer.chestSide = i
		elseif ICore.IUtils:isStringContain(inventoryName, reactorName) then
			RTransposer.reactorSide = i
		end
	end
  end
  ICore:init("Find reactor side:"..RTransposer.reactorSide)
  ICore:init("Find chest   side:"..RTransposer.chestSide)
  RTransposer:initReactorMap()
  ICore.IThread:create(RTransposer.thread, RTransposer, "RTSPT")  
  ICore:init("RTransposer adapte finished")	  
  return true
end

function RTransposer:initReactorMap()
	ICore:init("Initialize reactor map") 
	local reactorInventorySize = ICore.IComponent:invoke("transposer", "getInventorySize", RTransposer.reactorSide)
	for i=1, reactorInventorySize do		
		local slotSize = ICore.IComponent:invoke("transposer", "getSlotStackSize", RTransposer.reactorSide, i)
		if slotSize > 0 then
		    local slotStack = ICore.IComponent:invoke("transposer", "getStackInSlot", RTransposer.reactorSide, i)
		    table.insert(RTransposer.map, {i, slotStack.name})			
		end	
	end
	ICore:init("Reactor map init finished") 
end

function RTransposer:thread()
  while true do  
    RTransposer:scanReactor()
  end
end

function RTransposer:scanReactor()
	ICore:debug("scan reactor") 
	local width = math.floor((ICore.IComponent:invoke("transposer", "getInventorySize", RTransposer.reactorSide)) / 6)
	for k, v in pairs(RTransposer.map) do
		local slotId = v[1]
		local ItemName = v[2]
		local x, y = (slotId - 1) % width, math.floor((slotId - 1) / width)
		local slotRecord = {}
		local slotStack = ICore.IComponent:invoke("transposer", "getStackInSlot", RTransposer.reactorSide, slotId)
		if slotStack then
			slotRecord.id = slotId
			slotRecord.name = slotStack.name
			slotRecord.life = math.ceil(((slotStack.maxDamage - slotStack.damage) * 99 / slotStack.maxDamage))
			slotRecord.x = x
			slotRecord.y = y
			RTransposer.runtimeMap[x * 16 + y] = slotRecord
		else
			RTransposer.runtimeMap[x * 16 + y] = 0
		end
		os.sleep(0.1)		
	end	
	ICore:debug("scan reactor finished") 
	os.sleep(0.1)
	if INuclear.builder.scanReactorCallback then
		INuclear.builder.scanReactorCallback()
	end
end

function RTransposer:getRuntimeMap()
	return RTransposer.runtimeMap
end

function RTransposer:getInitialMap(x, y)
	local width = math.floor((ICore.IComponent:invoke("transposer", "getInventorySize", RTransposer.reactorSide)) / 6)
	local slotId = y * width + x + 1
	for k, v in pairs(RTransposer.map) do
		if slotId == v[1] then
			local slotRecord = {}
			slotRecord.id = slotId
			slotRecord.name = v[2]
			slotRecord.x = x
			slotRecord.y = y
			return slotRecord
		end
	end
	return "EMPTY ITEM"
end

function RTransposer:findChestsItem(itemName)
	local chestInventorySize = ICore.IComponent:invoke("transposer", "getInventorySize", RTransposer.chestSide)
	for i=1, chestInventorySize do		
		local slotSize = ICore.IComponent:invoke("transposer", "getSlotStackSize", RTransposer.chestSide, i)
		if slotSize > 0 then
		    local slotStack = ICore.IComponent:invoke("transposer", "getStackInSlot", RTransposer.chestSide, i)
			if slotStack.name == itemName then
				return i
			end
		end
	end
	return nil
end


function RTransposer:transferChestItemToReactor(chestSlotId, reactorSlotId)
	ICore.IComponent:invoke("transposer", "transferItem", RTransposer.chestSide, RTransposer.reactorSide, 1, chestSlotId, reactorSlotId)
end
--<============RRedIO=============>
RRedIO.reactorSide = -1
function RRedIO:adapte()  
  ICore:init("RRedIO start adapte") 
  if not component.isAvailable(INuclear.RETORNAME)then 
	ICore:error("Cannot find "..INuclear.RETORNAME)
	return false
  end
  if not component.isAvailable("redstone") then 
	ICore:error("Cannot find redstone")
	return false
  end
  local lastRSStatus = ICore.IComponent:invoke("redstone", "setOutput", {0,0,0,0,0,0})
  ICore:init("Close all side output")  
  os.sleep(0.5)
  for side = 0, 5 do
    ICore:init("RRedIO start testing Side "..side)
    ICore.IComponent:invoke("redstone", "setOutput", side, 7)
	os.sleep(0.5)
	isRunning = ICore.IComponent:invoke(INuclear.RETORNAME, "producesEnergy")    
	if isRunning then
	  RRedIO.reactorSide = side
	  ICore:init("Find reactor in Side "..side)
	  ICore.IComponent:invoke("redstone", "setOutput", side,lastRSStatus[side])
	  os.sleep(0.5)
	  ICore:init("RRedIO adapte finished")	     
	  return true
	end
	ICore.IComponent:invoke("redstone", "setOutput", side, 0)
	os.sleep(0.5)
  end
  ICore:error("Cannot find reactor")
  return false
end

function RRedIO:startup()
  RRedIO:sendRedStore(7)  
end

function RRedIO:stop()
  RRedIO:sendRedStore(0)  
end

function RRedIO:sendRedStore(value)
  ICore.IComponent:invoke("redstone", "setOutput", RRedIO.reactorSide, value)    
  ICore:warn("Send RedStore To Reactor :"..value)
end



return INuclear