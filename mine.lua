robot = require("robot")
component = require("component")
ICore = require("ICore")
sides = require("sides")

RComponent = {}
RComponent.include = {}
RComponent.include.generator = component.isAvailable("generator")
RComponent.include.Inventory_Controller = component.isAvailable("inventory_controller")

RState = {}
RState.mode = 0
RState.totalSpace = 0
RState.durability = 0
RState.distance = 0
RState.location = 0
RState.maxDistance = 0
RState.storeSlot = 1
RState.toolsSlot = 2

function RState:initialize()
  RState.totalSpace = 0
  RState.durability = 0
  RState:update()
end

function RState:update()
  RState:updateTotalSpace();
  RState:updateDurability();
end

function RState:updateDurability()
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


local args = {...}
local col1, col2 = 1, 25
local pad1, pad2 = col2-1, 50
local stop = false
local w, h

function display()
    local startLine = 1
	ICore.IGpu:print(col1, startLine + 0, "Mode:"..(RState.mode > 1 and "Around" or "Straight"), nil, pad1)
    ICore.IGpu:print(col1, startLine + 1, "Total Space:"..RState.totalSpace, nil, pad1)
	ICore.IGpu:print(col1, startLine + 2, "Tool Durability:"..RState.durability, nil, pad1)
	ICore.IGpu:print(col1, startLine + 3, "Run distance:"..RState.distance..(RState.maxDistance > 0 and ("/"..RState.maxDistance) or ""), nil, pad1)
	ICore.IGpu:print(col1, startLine + 4, "Location:"..RState.location, nil, pad1)

	ICore.IGpu:print(col2, startLine + 0, "Energy:"..ICore.IState:getEnergyString(), nil, pad2)
	ICore.IGpu:print(col2, startLine + 1, "Modem:"..ICore.INetwork:getNetworkInfomation(), nil, pad2)
	ICore.IGpu:print(col2, startLine + 2, "", nil, pad2)
	ICore.IGpu:print(col2, startLine + 3, "Generator:"..(RComponent.include.generator and "true" or "false"), nil, pad2)
	ICore.IGpu:print(col2, startLine + 4, "Inventory Controller:"..(RComponent.include.Inventory_Controller and "true" or "false"), nil, pad2)
	

	ICore.IGpu:fill(col1, startLine + 5, 160, 1, "=")  
end

function main()
  if #args < 1 then
    printUsage()
	return    
  end
  RState.maxDistance = tonumber(args[1])
  if #args == 2 then
	if args[2] == "-l" then
	  RState.mode = 1
	elseif args[2] == "-ad" then
	  RState.mode = 2
    elseif args[2] == "-a" then
	  RState.mode = 3
	else 
	  RState.mode = 0
	end
  end

  local sendNetwork = args[3] == "-r"
   
  start()

end



function printUsage()  
  print("Usages: ")
  print("  mine <Max distance> [<mode>] [<network>]")
  print("  <1>if <Max distance> equie 0 , the robot will mine until no space or no durability")  
  print("  <2>place a Store in first slot to avoid robot dig store") 
  print("  <3>mode use:")   
  print("     -l: dig only straight line dig")  
  print("     -ld: dig only straight line dig and dig back") 
  print("     -a: around")  
  print("     -ad: around and dig back") 
  print("  <4>network use:")   
  print("     -l: location")  
  print("     -r: remote")  
end

function start()
  ICore:initialize(6, false)
  ICore:setGlobelNetworkSetting(sendNetwork, false)
  RState:initialize()
  display()
  forwardStep()  
  if RState.mode == 0 or RState.mode == 2 then
	ICore:info("Dig neighbouring")
    robot.turnRight()
	for i=0, 2 do
	  moveForward()
	  dig() 
	end
	robot.turnRight()
	forwardStep(-1, 0)
  else  
	backStep() 
  end
  robot.turnAround()
  ICore:info("Mission Finished!")  
end

function forwardStep(addLocation, addDistance)
  ICore:info("Go!")
  addLocation = addLocation or 1
  addDistance = addDistance or 1
  while not stop do   
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
	  break
	end
	if ICore.IState:getEnergyPercentage() < 10 then
	  ICore:error("Low Energy")
	  break
	end
	if addLocation == -1 and RState.location == -1 then
	  break;
	end
	RState:update()
	display()
  end  
end

function moveForward()  
  local try = 100
  while try > 0 do    
    if robot.forward() then
	  return true	  
	else
	  robot.swing()
	end	  
	try = try - 1
  end
  ICore:info("Robot cannot forward")
  return false
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
  if RState.mode > 1 then
    local side = sides.front
    side = digOneLayer(true, false, side)
	robot.swingUp()	
	robot.up()
	side = digOneLayer(false, true, side)
	robot.down()
  else
    robot.swing()	
    robot.swingUp()	
  end
end

function digOneLayer(isFirstLayer, isFinalLayer, side)
  
  local newSide
  if isFirstLayer then
    robot.swing()	
	robot.turnLeft()
	newSide = sides.right
  end  

  compareIsStoreAndDig()
  robot.turnAround()
  compareIsStoreAndDig()  
  
  if not isFirstLayer and not isFinalLayer then
    if side == sides.right then
	  newSide = sides.left
	else
	   newSide = sides.right
	end
  end
  
  if isFinalLayer then
    if side == sides.right then
      robot.turnRight() 
	else
	  robot.turnLeft() 
	end
	newSide = sides.front
  end
  return newSide
end

function compareIsStoreAndDig()
  robot.select(RState.storeSlot)
  if not robot.compare() then
    robot.swing()
  end
end

main()