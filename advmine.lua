--往左边挖矿
--箱子放右边

--左边升级栏摆放：
--区块载入
--超级电池
--发电机
--物品栏x2
--键盘、显示器
--地质分析仪
--超级卡槽、基础卡槽
--物品栏控制升级

--右边放入：
--超级cpu
--T3内存x1
--T2内存x1
--高级无线网卡
--eeprom
--硬盘

local ignoreDurability = true
local moveInterval = 2

local robot = require("robot")
local component = require("component")
local ICore = require("ICore")
local Sides = require("sides")
local computer = require("computer")
local IRobot = require("IRobot")
local Vector3 = require("IVector3")
local INet = require("INet")



RComponent = {}
RComponent.include = {}
RComponent.include.generator = component.isAvailable("generator")
RComponent.include.Geolyzer = component.isAvailable("geolyzer")
RComponent.include.Chunkloader = component.isAvailable("chunkloader")
RComponent.include.Chunkloader = component.isAvailable("chunkloader")

RState = {}
RState.mode = 2
RState.modeString = "Auto"
RState.totalSpace = 0
RState.durability = 0
RState.distance = 0
RState.location = 0
RState.maxDistance = 0
RState.storeSlot = 1
RState.tunnelHeight = 2
RState.recursionLayer = 0
RState.level = 0
RState.stackLocation = {}
RState.relativeLocation = {}
RState.relativeLocation.x = 0
RState.relativeLocation.y = 0
RState.relativeLocation.z = 0

function RState:initialize()
  RState.totalSpace = 0
  RState.durability = 0
  RState.distance = 0
  RState.location = 0
  RState.relativeLocation.x = 0
  RState.relativeLocation.y = 0
  RState.relativeLocation.z = 0
  RState:update()
end

function RState:update()
  RState:updateTotalSpace();
  RState:updateDurability();
  RState:updateLeve();
end

function RState:updateDurability()
  if ignoreDurability then
	RState.durability = 100
	return
  end
  local result, _, _ = robot.durability()
  RState.durability = result or 0
end

function RState:updateTotalSpace()
  local total = 0
  for i=1, robot.inventorySize() do
    total = total + robot.space(i)
  end
  RState.totalSpace = total
end

function RState:updateLeve()	
  RState.level = ICore.IComponent:invoke("experience", "level") or 0
end


local args = {...}
local col1, col2 = 1, 25
local pad1, pad2 = col2-1, 50
local stop = false
local w, h = 0, 0
local skip = 0
local target = 0
local enableNet = true
local oreList = {"coal", "iron", "gold", "lapis", "diamond", "redstone", "emerald", "dye", "pickaxe", "drill" ,"resource", "ic2", "quartz", "material", "ore_metal", "railcraft:ore", "mekanism:oreblock"}
local advToolOreList = {"lapis", "diamond", "redstone", "emerald", "dye"}
local advToolSlot = 1
local currentTool = 0
local oreCount = 0
local sd = 0
local moveInvoke = 2

function display()
    local startLine = 1
	ICore.IGpu:print(col1, startLine + 0, "Mode:"..RState.modeString, nil, pad1)
    ICore.IGpu:print(col1, startLine + 1, "Total Space:"..RState.totalSpace, nil, pad1)
	ICore.IGpu:print(col1, startLine + 2, "Coor:"..tostring(IRobot:getCoor()), nil, pad1)
	ICore.IGpu:print(col1, startLine + 3, "Location:"..RState.location..(RState.maxDistance > 0 and ("/"..RState.maxDistance) or ""), nil, pad1)
	ICore.IGpu:print(col1, startLine + 4, "skip:"..skip, nil, pad1)
    ICore.IGpu:print(col1, startLine + 5, "target:"..target, nil, pad1)
	ICore.IGpu:print(col1, startLine + 6, "Location Stack["..RState.recursionLayer.."]:"..stackToString(RState.stackLocation), nil, 150)	
	
	
	ICore.IGpu:print(col2, startLine + 0, "Energy:"..ICore.IState:getEnergyString(), nil, pad2)
	ICore.IGpu:print(col2, startLine + 1, "Level:"..RState.level, nil, pad2)
	ICore.IGpu:print(col2, startLine + 2, "Tool Durability:"..RState.durability, nil, pad2)
	ICore.IGpu:print(col2, startLine + 3, "Current Tool:"..(currentTool == 0 and "Normal" or "Adv"), nil, pad2)
	ICore.IGpu:print(col2, startLine + 4, "Ore Count"..oreCount, nil, pad2)
	ICore.IGpu:print(col2, startLine + 5, "wireless:"..(ICore.IComponent:invoke("modem", "getStrength") or 0), nil, pad2)
	
	

	ICore.IGpu:fill(col1, startLine + 7, 160, 1, "=")  
end

function main()
  if #args < 1 then
    printUsage()
	return    
  end
  RState.maxDistance = tonumber(args[1])
  sd = tonumber(args[2] or 0)
  skip = tonumber(args[3] or 0)
  target = target + skip
  local ibuilder = ICore.IBuilder:setCMDsTop(8)
  if component.isAvailable("modem") and enableNet then
	local nbuilderClient = INet.NBuilder:setNet(101, ibuilder):setClientNet(onServerCMDCome):SendCMDMsg():SendCopyDisplay():setWirelessStrength(16)
	ICore = INet:initialize(nbuilderClient)
  else
	ICore =  ICore:initialize(ibuilder)  
  end
  if not ignoreDurability and not robot.durability() then
	error("tool durability == 0")
  end
  RState:initialize()
  if RComponent.include.Chunkloader then
    ICore.IComponent:invoke("chunkloader", "setActive", true)  
  end
  IRobot:initialize(true, nil, moveCallback)   
  ICore.IThread:create(start, nil, "start")
  ICore.IThread:create(monitor, nil, "monitor")
end

function moveCallback(result)
  if ICore.IState:getEnergyPercentage() < 5 then
	  ICore:error("Low Energy")
	  charge()
  end
end

function monitor()
	while true do
		display()			
		ICore.IThread:resume("start")					
		os.sleep(0.1)
	end
end

function printUsage()  
  print("Usages: ")
  print("  mine <Max distance, sd, skip>")
  if not RComponent.include.Geolyzer then
    print("  <2>place a Stone in first slot to avoid robot dig stone ") 
  end
end

function start()	
	INet:setWirelessStrength(16)
	os.sleep(3)
	INet:setWirelessStrength(0)
	ICore:info("Mission Start!") 	
	while true do
		RState:initialize()
		findNewTarget()
		targetOne()
		dropUnusedOre()
		IRobot:moveToHome()	
		dropOreToChest()
		INet:setWirelessStrength(16)
		while ICore.IState:getEnergyPercentage() < 98 do
			os.sleep(10)
		end
		os.sleep(10)
		INet:setWirelessStrength(0)
	end	
end

function dropOreToChest()
	ICore:debug("dropOreToChest")
	IRobot:turnTo(sd == 0 and IRobot.S or IRobot.N)
	for i=2, robot.inventorySize() do
		if robot.count(i) > 0 then
			robot.select(i)
			robot.drop()
		end		
	end
end

function dropUnusedOre()
	ICore:debug("dropUnusedOre")
	for i=2, robot.inventorySize() do
		if robot.count(i) > 0 then
			local stack = ICore.IComponent:invoke("inventory_controller", "getStackInInternalSlot", i) 
			if not ICore.IUtils:isTableContain(oreList, stack["name"]) then
				robot.select(i)
				robot.drop()
			end
		end		
	end
end

function changeToNormalTool()	
	if currentTool == 1 then
		ICore:debug("change to normalToolSwing")
		currentTool = 0
		changeTool(advToolSlot)
	end
end

function changeToAdvTool()
	if currentTool == 0 then
		ICore:debug("change to advToolSwing")
		currentTool = 1
		changeTool(advToolSlot)
	end
end

function changeTool(toolSlot)	
	robot.select(toolSlot)
	ICore:debug("changeTool:", ICore.IComponent:invoke("inventory_controller", "equip"))
end

function findNewTarget()
	target = target + 1
	ICore:info("Find target:", target)
	local realMoveInvoke = moveInvoke + 1
	realMove = moveInterval + 1
	realMoveInvoke = (sd == 0 and -realMove or realMove)
	IRobot:moveTo(Vector3:new(0,target * realMoveInvoke,0))
	IRobot:turnTo(IRobot.E)
	display()	
end

function targetOne()
  forwardStep()  
  backStep() 
  robot.turnAround()
  ICore:info("Target Finished!") 
end

function forwardStep(addLocation, addDistance)
  ICore:info("Go!")
  addLocation = addLocation or 1
  addDistance = addDistance or 1
  while not stop do  
	RState:update()
	changeToNormalTool()
	if moveForward() then
	  RState.distance = RState.distance + addDistance
	  RState.location = RState.location + addLocation
	else
	  break
	end
	dig() 
	if addLocation > 0 and RState.maxDistance > 0 and RState.distance > RState.maxDistance then	 	 
	  break
	end
	if RState.durability == 0 then
	  ICore:error("Tool durability is 0")
	  break
	end
    if RState.totalSpace == 0 then
	  ICore:error("No Space")
	  dropUnusedOre()
	end	
	if ICore.IState:getEnergyPercentage() < 5 then
	  ICore:error("Very Low Energy")
	  if not charge() then
	    break	 
	  end	  
	elseif ICore.IState:getEnergyPercentage() < 20 then
	  ICore:error("Low Energy")
	  charge()
	end
	if addLocation == -1 and RState.location == -1 then
	  break;
	end	
	display()
  end  
end

function charge()
  if RComponent.include.generator then   
    local fuelCount = ICore.IComponent:invoke("generator", "count")  
	if fuelCount > 0 then
	  local sleepTime = math.ceil((100 - ICore.IState:getEnergyPercentage()) / 6)
	  for i=sleepTime, 1, -1 do
	    fuelCount = ICore.IComponent:invoke("generator", "count") 
        if fuelCount <= 0 then
          ICore:info("Fuel empty.")
		  break
		end
	    ICore:info("FuelCount:"..fuelCount..", sleep for "..(i * 60).."s charging.")
	    os.sleep(60)
		if ICore.IState:getEnergyPercentage() > 99 then
		  ICore:info("Sufficient energy.")
		  break
		end
	  end
	  ICore:info("Resume mission.")
	  return true
	end
	ICore:info("Start Charge")
    for i=1, robot.inventorySize() do
	  robot.select(i)
	  result = ICore.IComponent:invoke("generator", "insert")
	  if result then
	    ICore:info("Charge Successed.")	   
		return true
	  end
	end
  end
  return false
end

function moveForward()   
  while not robot.forward() do     
	  robot.swing()
  end  
  return true
end

function backStep()
  ICore:info("Start to return")
  robot.turnAround()
  for i=1, RState.distance do
    if moveForward() then
	  RState.location = RState.location - 1
	  display()
	end
  end
end

function dig() 
  if RState.mode == 2 then
    digVertical(RState.tunnelHeight)
  else
    robot.swing()	
    robot.swingUp()	
  end
end

function digVertical(tunnelHeight)
  if RComponent.include.Geolyzer then
    return digVerticalByGeolyzer(tunnelHeight)
  else
    return digVerticalByCompare(tunnelHeight)
  end  
end

function digVerticalByGeolyzer(tunnelHeight)
  local findOre = false
  
  findOre = recursionDig(Sides.down) --1层下方  
  --上去
  for i=1, tunnelHeight do
    findOre = recursionDig(Sides.left)
	findOre = recursionDig(Sides.front)
	findOre = recursionDig(Sides.right)
	if i ~= tunnelHeight then
	  changeToNormalTool()
	  robotUp()
	end	
  end     

  findOre = recursionDig(Sides.up) --顶层上方  
 
  --下来
  for i=tunnelHeight, 1, -1 do    
	if i ~= 1 then
	  robotDown()
	end
  end
 
  return findOre
end

function digVerticalByCompare(tunnelHeight)
  local findOre = false
  findOre = recursionDig() --1层前方
  findOre = recursionDig(Sides.down) --1层下方
  
  robot.turnLeft() --转向1：左转；方位：左  
  --左边前方按层数遍历
  for i=1, tunnelHeight do
    findOre = recursionDig()
	if i ~= tunnelHeight then
	  robotUp()
	end	
  end  
  
  robot.turnRight() --转向2：右转；方位：前
  if tunnelHeight > 1 then
    findOre = recursionDig() --顶层前方
  end
  findOre = recursionDig(Sides.up) --顶层上方
  
  robot.turnRight() --转向3：右转；方位：右
  --右边前方按层数遍历
  for i=tunnelHeight, 1, -1 do
    findOre = recursionDig()
	if i ~= 1 then
	  robotDown()
	end
  end

  robot.turnLeft() --转向4：左转；方位：前  
  return findOre
end

function recursionDig(digSide)
  digSide = digSide or Sides.front  
  compareOreAndDig(digSide)  
end

function compareOreAndDig(digSide)   
  if RComponent.include.Geolyzer then
    compareByGeolyzer(digSide)
  else  
    compareByCompare(digSide)
  end 
end

function compareByGeolyzer(digSide)
  result = ICore.IComponent:invoke("geolyzer", "analyze", digSide)     
  if ICore.IUtils:isTableContain(oreList, result["name"]) then
	oreCount = oreCount + 1
	if ICore.IUtils:isTableContain(advToolOreList, result["name"]) then
		changeToAdvTool()
	else
		changeToNormalTool()
	end
	if digSide == Sides.left then
	  robot.turnLeft()
	  RealDigOre(Sides.front)
	  robot.turnRight()
	elseif digSide ==  Sides.right then
	  robot.turnRight()
	  RealDigOre(Sides.front)
	  robot.turnLeft()
	else
	  RealDigOre(digSide)
	end	
  end
end

function compareByCompare(digSide)
  if digSide == Sides.front then
    compareFunc = robot.compare	
  elseif digSide == Sides.up then
    compareFunc = robot.compareUp		
  elseif digSide == Sides.down then
    compareFunc = robot.compareDown		
  end
  
  robot.select(RState.storeSlot)
  if not compareFunc() then
    RealDigOre(digSide)
  end
end

function RealDigOre(digSide)   
  if digSide == Sides.front then
    detectFunc = robot.detect	
  elseif digSide == Sides.up then
    detectFunc = robot.detectUp		
  elseif digSide == Sides.down then
    detectFunc = robot.detectDown		
  end
  local result, info = detectFunc()
  if result then
    if robotSwingWihtTime(digSide, 0.35) or RComponent.include.Geolyzer then
      if RState.mode == 2 then
        robotMove(digSide)
        RState.recursionLayer = RState.recursionLayer + 1
	    stackPush(RState.stackLocation, digSide)	
        display()
	
       digVertical(1)
	
	    ploc = stackPop(RState.stackLocation)
	    if ploc == 0 then	  
	      robotUp()
	    elseif ploc == 1 then	
	      robotDown()
	    elseif ploc == 3 then	  
	      robotBack()
	    end
	
        RState.recursionLayer = RState.recursionLayer - 1
        display()
      end
	end
  end
end

function robotSwingWihtTime(digSide, threshold)  
  local swingStartTime = computer.uptime()  
  if digSide == Sides.front then
    robot.swing()  	
  elseif digSide == Sides.up then
    robot.swingUp()  	
  elseif digSide == Sides.down then
    robot.swingDown()  	
  end
  local swingTime = computer.uptime() - swingStartTime
  return swingTime > threshold
end

function stackPush(stack, value)
  table.insert(stack, value)
end

function stackPop(stack)
  return table.remove (stack)
end

function stackToString(stack)
  local str = ""
  for k, v in pairs(stack) do
    str = str..v
  end
  return str
end

function robotMove(side)
  if side == Sides.front then
    robotForward()
  elseif side == Sides.up then
    robotUp()	
  elseif side == Sides.down then
    robotDown()	
  end
end

function robotUp()
  while not robot.up() do
	robot.swingUp()
  end
end

function robotDown()
  while not robot.down() do
	robot.swingDown()
  end	
end

function robotForward()
  while not robot.forward() do
	robot.swing()
  end		
end

function robotBack()
  if not robot.back() then
    robot.turnAround()
	robotForward()
	robot.turnAround()
  end
end


main()