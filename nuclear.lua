local component = require("component")
local ICore = require("ICore")
local INuclear = require("INuclear")
local text = require("text")


local CMDList = 
{
  ["exit"] = function(scom)       
	ICore.IGpu:clear()
	ICore.IThread:killAllThread()
	exit(0)
  end,   
  ["start"] = function(coms) 
    INuclear.RRedIO:startup()
	changeAction("RUNING", true)
  end,
  ["stop"] = function(coms) 
    INuclear.RRedIO:stop()
	changeAction("SHUTDOWN")
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

local col1, rtmx, col2
local pad1, pad2

local NState = {}
NState.action = "SHUTDOWN"
NState.lastHeat = INuclear.getHeat()

function main()   
	
	local ibuilder = ICore.IBuilder:setCMDsTop(9):setCMDList(CMDList)	  	
	if component.isAvailable("modem") then
		ibuilder = ibuilder:setNet(100, true):setClientNet(onServerCMDCome)
	end
	local nbuilder = INuclear.NBuilder:setIBuilder(ibuilder):setScanReactorCallback(onScanReactorFinished)
	INuclear:initialize(nbuilder)	
	col1, rtmx, col2 = 1, ICore.w - 28, ICore.w / 2 + 18
	pad1, pad2 = rtmx - 3, 100	
	ICore.IThread:create(display_thread, nil, "display_thread") 
	ICore.IThread:create(logic_thread, nil, "logic_thread") 
end

function onServerCMDCome(cmd, msg)
	
end

function changeAction(action, force)
	if NState.action ~= action	and (force or NState.action ~= "SHUTDOWN") then		
		NState.action = action	
		ICore:info("ACTION CHANGE:-->"..action)
		ICore.IGpu:print(col1, 5, "ACTION:"..NState.action, nil, pad1)
	end
end

function onScanReactorFinished()	
	ICore.IThread:resume("display_thread")
end

function logic_thread()
	while true do	  
	  logic()
	  os.sleep(0.5)
	end
end

function logic()
	if (INuclear.isRunning() or NState.action == "RUNING") and INuclear.getHeat() > NState.lastHeat then
		INuclear.RRedIO:stop()
		ICore:info("["..INuclear.getHeat().."]HEAT RISE!")
		changeAction("WAIT CHECK")
	end	
	if (INuclear.isRunning() or NState.action == "RUNING") and INuclear.getHeat() > 2000 then
		INuclear.RRedIO:stop()
		ICore:error("["..INuclear.getHeat().."]OVERHEAT!")
		changeAction("SHUTDOWN")
	end
	NState.lastHeat = INuclear.getHeat()
end

function display_thread()
	while true do
		display()	
		os.sleep(1)
	end
end

function display()		
	local startLine = 1
	ICore.IGpu:print(col1, startLine + 0, INuclear.isRunning() and "Running" or "Stop", INuclear.isRunning() and 0x00FF00 or 0xFF0000, pad1)
	ICore.IGpu:print(col1, startLine + 1, "Heat:"..INuclear.getHeat().."/"..INuclear.getMaxHeat(), INuclear.getHeat() > 1000 and 0xFFFF00 or 0xFFFFFF, pad1)	
	ICore.IGpu:print(col1, startLine + 2, "EU output:"..INuclear.getReactorEUOutput(), nil, pad1)	
	ICore.IGpu:print(col1, startLine + 3, "", nil, pad1)
	ICore.IGpu:print(col1, startLine + 4, "ACTION:"..NState.action, nil, pad1)
	ICore.IGpu:print(col1, startLine + 5, "", nil, pad1)
	ICore.IGpu:print(col1, startLine + 6, "", nil, pad1)
	ICore.IGpu:print(col1, startLine + 7, (component.isAvailable(INuclear.RETORNAME) and " RETOR" or " ")..(component.isAvailable("redstone") and " RSTIO" or " ")..(component.isAvailable("transposer") and " TSPOT" or " "), nil, pad1)
	
	
	--绘制运行时图边框
	ICore.IGpu.gpu.setBackground(0xFFFFFF)
	ICore.IGpu.gpu.fill(rtmx - 2 , 1,  31 , 1, " ")
	ICore.IGpu.gpu.fill(rtmx - 2 , 2,  2  , 6, " ")
	ICore.IGpu.gpu.fill(rtmx + 27, 2,  2  , 6, " ")
	ICore.IGpu.gpu.fill(rtmx - 2 , 8,  31 , 1, " ")
	ICore.IGpu.gpu.setBackground(0x000000)		
	
	--绘制运行时图
	local runtimeMap = INuclear.RTransposer:getRuntimeMap()
	if runtimeMap then
		for x=0, 8 do
		  for y=0, 5 do
			local slotRecord = runtimeMap[x * 16 + y]
			if slotRecord then
			  if slotRecord ~= 0 then
				if string.find(slotRecord.name, "Uranium") then
				  ICore.IGpu.gpu.setBackground(0xFFFFFF)
				  ICore.IGpu.gpu.setForeground(0x000000)
				else
				  ICore.IGpu.gpu.setBackground(0x000000)
				  ICore.IGpu.gpu.setForeground(0xFFFFFF)
				end
				ICore.IGpu.gpu.set(rtmx + x * 3, y + 2, text.padLeft(tostring(slotRecord.life), 2))
			  else
				ICore.IGpu.gpu.setBackground(0x000000)
				ICore.IGpu.gpu.setForeground(0xFFFFFF)
				ICore.IGpu.gpu.set(rtmx + x * 3, y + 2, "--")
				--更换物品逻辑
				slotRecord = INuclear.RTransposer:getInitialMap(x, y)
				replaceItemsLogic(slotRecord)
			  end
			else
			  ICore.IGpu.gpu.setBackground(0x000000)
			  ICore.IGpu.gpu.setForeground(0xFFFFFF)
			  ICore.IGpu.gpu.fill(rtmx + x * 3, y + 2, 3, 1," ")
			end		
		  end
		end
		--还原背景和字体颜色
		ICore.IGpu.gpu.setBackground(0x000000)
		ICore.IGpu.gpu.setForeground(0xFFFFFF)
	end
	ICore.IGpu:fill(col1, startLine + 8, 160, 1, "=") 	
end


function replaceItemsLogic(slotRecord)
	if not string.find(slotRecord.name, "Uranium") then
		INuclear.RRedIO:stop()
		changeAction("REPLENISH")
		ICore:warn(slotRecord.name.." is depleted.")
		local chestSlotId = INuclear.RTransposer:findChestsItem(slotRecord.name)
		if chestSlotId then			
			INuclear.RTransposer:transferChestItemToReactor(chestSlotId, slotRecord.id)
			ICore:info(slotRecord.name.." replenish.")
			ICore.IThread:suspend()
			display()
		else
			ICore:error(slotRecord.name.." is Empty")
			changeAction("SHUTDOWN")
		end
		if NState.action ~= "SHUTDOWN" and NState.action ~= "RUNING" then
			INuclear.RRedIO:startup()
			changeAction("RUNING")
		end
	else
		ICore:error(slotRecord.name.." is depleted")
	end
end

main()