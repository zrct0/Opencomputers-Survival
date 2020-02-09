robot = require("robot")
term = require("term")
component = require("component")
ICore = require("ICore")
sides = require("sides")

RComponent = {}
RComponent.include = {}
RComponent.include.tractor_beam = component.isAvailable("tractor_beam")

RState = {}
RState.mode = 0
RState.action = "Wait"
RState.locationZ = 0
RState.locationX = 0
RState.side = sides.right
RState.totalSpace = 0
RState.durability = 0
RState.saplingSlot = 1
RState.saplingCount = 0
RState.osSleepTime = 2

function RState:initialize()
  RState.totalSpace = 0
  RState.durability = 0
  RState:update()
end

function RState:update()
  RState:updateTotalSpace();
  RState:updateDurability();
  RState.saplingCount = robot.count(RState.saplingSlot)
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
	ICore.IGpu:print(col1, startLine + 0, "Mode:"..(RState.mode == 0 and "Single" or "Multiple"), nil, pad1)
	ICore.IGpu:print(col1, startLine + 1, "Action:"..RState.action, nil, pad1)
    ICore.IGpu:print(col1, startLine + 2, "Total Space:"..RState.totalSpace, nil, pad1)
	ICore.IGpu:print(col1, startLine + 3, "Sapling Count:"..RState.saplingCount, nil, pad1)	
	ICore.IGpu:print(col1, startLine + 4, "Location:"..((RState.side == sides.right) and "+" or "-").."("..RState.locationX..","..RState.locationZ..")", nil, pad1)

	ICore.IGpu:print(col2, startLine + 0, " Energy:"..ICore.IState:getEnergyString(), nil, pad2)
	ICore.IGpu:print(col2, startLine + 1, " Modem:"..ICore.INetwork:getNetworkInfomation(), nil, pad2)
	ICore.IGpu:print(col2, startLine + 2, "", nil, pad2)
	ICore.IGpu:print(col2, startLine + 3, " Tractor Beamr:"..(RComponent.include.tractor_beam and "true" or "false"), nil, pad2)
	ICore.IGpu:print(col2, startLine + 4, "", nil, pad2)

	ICore.IGpu:fill(col1, startLine + 5, 160, 1, "=")  
end

function main()
  if #args < 1 then
    printUsage()
	return    
  end

  RState.mode = ((args[1] == "-m") and 1 or 0)
  local sendNetwork = args[2] == "-r"

  ICore:initialize(6, false)
  ICore:setGlobelNetworkSetting(sendNetwork, false)
  RState:initialize()
  while true do    
    display()
	local isAir, isLog = detectLog()
	if isLog then
	  fellTree()
	  os.sleep(RState.osSleepTime)
	else 	 
	  changeAction("Wait")
	  os.sleep(RState.osSleepTime)
	  if RState.mode == 1 then
	    if isAir then
		  ICore:info("Move to end. TurnAround")	
		  RState.side = (RState.side == sides.right) and sides.left or sides.right
		  display()
		end
		moveToNextTree()
	  end
	end
	suckSapling()
	os.sleep(RState.osSleepTime)
	RState:update()
	if RState.totalSpace == 0 then
	  ICore:error("No Space")	
	  os.sleep(RState.osSleepTime)
	end		
  end
end

function printUsage()  
  print("Usages: ")
  print("  plant <mode>")
  print("  <1>mode use:")   
  print("     -o: Monitor single tree")  
  print("     -m: Monitor multiple trees") 
  print("  <2>network use:")   
  print("     -l: location")  
  print("     -r: remote")  
end

function moveToNextTree()
  changeAction("Move to next tree")  
  if RState.side == sides.right then
    robot.turnRight()
	for i=0, 1 do
	  suck()
	  while not robot.forward() do 
	  end
	  RState.locationX = RState.locationX + 1
	  display()
	end
	suck()
	robot.turnLeft()
  else
    robot.turnLeft()
	for i=0, 1 do
	  while not robot.forward() do 
	  end
	  RState.locationX = RState.locationX - 1
	  display()
	end
	robot.turnRight()
  end
  changeAction("Wait")
  goDown()
end


function detectLog()
  local result, info = robot.detect()
  return not result, info == "solid"
end

function fellTree()
  changeAction("Felling tree") 
  local isAir, isLog = detectLog()
  while isLog do
    robot.swing()
    robot.swingUp()	
	robot.up()
	RState.locationZ = RState.locationZ + 1
	isAir, isLog = detectLog()
	display()
  end
  goDown()
  plantSapling()
end

function goDown()  
  changeAction("Go down") 
  while RState.locationZ > 0 do	  
	if robot.down() then
      RState.locationZ = RState.locationZ - 1
	  display()
	else	    
	  robot.swingDown()
	end	      	
  end
end

function suckSapling()
  changeAction("Suck Sapling") 
  suck()
  robot.turnRight()
  suck()
  robot.turnRight()
  suck()
  robot.turnRight()
  suck()
  robot.turnRight()
  changeAction("Wait")  
end

function plantSapling()
  changeAction("Suck Sapling") 
  RState.saplingCount = robot.count(RState.saplingSlot)
  if RState.saplingCount > 0 then
    robot.select(RState.saplingSlot)
    robot.place()
  else
    ICore:error("No Sapling")	
  end
  changeAction("Wait") 
end

function suck()
  if RComponent.include.tractor_beam then    
    ICore.IComponent:invoke("tractor_beam", "suck")       
  else
    robot.suck()
  end
end



function changeAction(action)
  if action ~= RState.action then
    ICore:info("Action Change:"..action)
    RState.action = action
	display()
  end
end

main()
