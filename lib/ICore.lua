local ICore = {}
local IGpu = {}
local IThread = {}
local IComponent = {}
local INetwork = {}
local ICoreNetwork = {}
local IUtils = {}
local IState = {}

local serialization = require("serialization")
local computer = require("computer")
local component = require("component")
local text = require("text")
local thread = require("thread")
local event = require("event")
local term = require("term")



ICore.IGpu = IGpu
ICore.IThread = IThread
ICore.IUtils = IUtils
ICore.INetwork = INetwork
ICore.ICoreNetwork = ICoreNetwork
ICore.IComponent = IComponent
ICore.IState = IState

ICore.isCMDsShowTime = true
ICore.GlobelSendRemoteMsg = false
ICore.GlobelReceiveRemoteMsg = false

function ICore:initialize(_CMDsTop, _isCMDsShowTime, _netCallBack, _netWirelessStrength)  
  ICore.isCMDsShowTime = _isCMDsShowTime
  IGpu:initialize()
  local w, h = IGpu:getViewport()
  IGpu:setCMDMsgPosition(_CMDsTop, h)
  IGpu:clearCMDsCache()
  term.clear()
  
end

function ICore:setGlobelNetworkSetting(_GlobelSendRemoteMsg, _GlobelReceiveRemoteMsg)
  ICore.GlobelSendRemoteMsg = _GlobelSendRemoteMsg
  ICore.GlobelReceiveRemoteMsg = _GlobelReceiveRemoteMsg
end

function ICore:error(str)  
  ICore:printMsg("error", "ERROR:"..str)
 end

function ICore:warn(str)
  ICore:printMsg("warn", "WARN:"..str)
end

function ICore:info(str)
   ICore:printMsg("info", "INFO:"..str)
end

function ICore:init(str)
   ICore:printMsg("init", "INIT:"..str)
end

function ICore:debug(str)
   ICore:printMsg("debug", "DEBUG:"..str)
end

function ICore:printMsg(cmd_type, str) 
   if ICore.isCMDsShowTime then
     IGpu:writeCMDsCache(cmd_type, "["..os.date("%X").."]"..str)
   else
     IGpu:writeCMDsCache(cmd_type, str)
   end
   IGpu:printCMDsCache()
end

--<============IState=============>

IState.energy = computer.energy()
IState.maxEnergy = computer.maxEnergy()

function IState:update()
  IState.energy = computer.energy()
  IState.maxEnergy = computer.maxEnergy()
end

function IState:getEnergyString()
  IState:update()
  if IState.energy and IState.maxEnergy then
    return math.ceil(IState.energy).."/"..math.ceil(IState.maxEnergy)
  end
end

function IState:getEnergyPercentage()
  IState:update()
  return (IState.energy/IState.maxEnergy) * 100
end

--<============IGpu=============>
local CMDsCache = {}
local CMDsCount = 0
local CMDsIter = 0
local MAX_CMDs_COUNT = 20
local w, h = 0
local MAIN_INFO_HEIGHT = 0
local CMDs_INFO_HEIGHT = 0
local CMDPOS_BOTTOM = 0
local cmd_type_id = {["all"] = -1, ["debug"] = 0, ["init"] = 1, ["info"] = 2, ["warn"] = 3, ["error"] = 4}
local cmd_type_color = {["debug"] = 0xFFFFFF, ["init"] = 0xFF00FF, ["info"] = 0x0000FF, ["warn"] = 0xFFFF00, ["error"] = 0xFF0000}
local isInitialize = false
local current_cmd_type = "init"

local CMDMsgCallback = nil
local gpu = component.gpu

function IGpu:initialize()     
  w, h = gpu.getViewport()
  MAIN_INFO_HEIGHT = 9
  CMDs_INFO_HEIGHT = h - MAIN_INFO_HEIGHT - 1
  CMDPOS_BOTTOM = h - 2
  local totalMemory = computer.freeMemory() 
  local Memory_1T = 19300
  if totalMemory > Memory_1T * 2 then
    MAX_CMDs_COUNT = 70
  end
  if totalMemory > Memory_1T * 3 then
    MAX_CMDs_COUNT = 200
  end
  if totalMemory > Memory_1T * 4 then
    MAX_CMDs_COUNT = 600
  end
  print("totalMemory:"..totalMemory..", MAX_CMDs_COUNT:"..MAX_CMDs_COUNT)
  isInitialize = true
  return w, h
end

function IGpu:getViewport()
  return w, h
end

function IGpu:setCMDMsgPosition(top, bottom)
  MAIN_INFO_HEIGHT = top
  CMDPOS_BOTTOM = bottom
  CMDs_INFO_HEIGHT = bottom - top
end

function IGpu:setCMDMsgCallback(_CMDMsgCallback)  
  CMDMsgCallback = _CMDMsgCallback
end

function IGpu:getTier()  
  if w <= 50 then
    return 1
  elseif w <= 80 then
    return 2
  else
    return 3
  end  
end

function IGpu:writeCMDsCache(cmd_type, cmd, remoteSend)
  local cache = {cmd_type, tostring(CMDsIter < 10 and "[0" or "[")..CMDsIter.."]"..cmd}
  CMDsCache[CMDsIter] = cache
  CMDsIter = CMDsIter + 1
  if CMDsIter >= MAX_CMDs_COUNT then
    CMDsIter = 0
  end 
  if CMDsCount < MAX_CMDs_COUNT then
    CMDsCount = CMDsCount + 1
  end
  
  if cmd_type_id[cmd_type] >= cmd_type_id["init"] then
    if CMDMsgCallback then
      CMDMsgCallback(_, cache)
	end
	if remoteSend == nil then
      remoteSend = ICore.GlobelSendRemoteMsg
    end
    if remoteSend then
      local pkg = serialization.serialize(cache)  
      ICoreNetwork:send("ICMD", cache)
    end
  end
end

function IGpu:printLine(line, str, color, line_count_backwards, padRight)
  if line_count_backwards then
    line = h - line
  end
  self:print(2, line, str, color, padRight)
end

function IGpu:print(x, y, str, color, padRight, remoteSend)

  if color == nil or gpu.getDepth() < 4 then
    color = 0xFFFFFF
  end
  if padRight == nil then
    padRight = w
  end
  gpu.setForeground(color)
  gpu.setBackground(0x000000)
  gpu.set(x, y, text.padRight(str, padRight))
  gpu.setForeground(0xFFFFFF)

  if remoteSend == nil then
    remoteSend = ICore.GlobelSendRemoteMsg
  end
  if remoteSend then
    local pkg = serialization.serialize({x, y, str, color, padRight})  
    ICoreNetwork:send("IGpu", pkg)
  end
end

function IGpu:fill(x, y, w, h, chr, color)

  if color == nil or gpu.getDepth() < 4 then
    color = 0xFFFFFF
  end
  gpu.setForeground(color)
  gpu.setBackground(0x000000)
  gpu.fill(x, y, w, h ,chr)
  gpu.setForeground(0xFFFFFF)
end

function IGpu:printCMDsCache()
  if not gpu then 
    gpu = require("component").gpu
	w, h = gpu.getViewport()
	CMDs_INFO_HEIGHT = 5
  end 
  
  local CMDsTypeCache, CMDsTypeCacheCount = self:getCMDsCache(CMDs_INFO_HEIGHT)
  local lastLine = math.min(CMDs_INFO_HEIGHT, CMDsTypeCacheCount - 1)
  local line = CMDPOS_BOTTOM
  for i=0, lastLine do
    gpu.setForeground(self:getCMDColor(CMDsTypeCache[i][1]))
    gpu.setBackground(0x000000)
    gpu.set(2, line, text.padRight(CMDsTypeCache[i][2], w))
    line = line - 1
  end 
  gpu.setForeground(0xFFFFFF)

end

function IGpu:getCMDColor(cmd_type)
  if gpu.getDepth() >= 4 then
    return cmd_type_color[cmd_type]
  else
    return 0xFFFFFF
  end
end

function IGpu:setCmdType(cmd_type)  
  if cmd_type_id[cmd_type] ~= nil then
    gpu.fill(1, MAIN_INFO_HEIGHT, w, h, " ")   
	self:writeCMDsCache("info", "["..os.date("%X").."]INFO:"..str)
    self:printCMDsCache()   
    current_cmd_type = cmd_type
	return true
  end
  return false
end

function IGpu:getCMDsCache(count)
  local CMDsTypeCache = {}
  local CMDsTypeCacheIter = 0
  for i=CMDsIter-1, 0, -1 do  
    if current_cmd_type == "all" or cmd_type_id[CMDsCache[i][1]] >= cmd_type_id[current_cmd_type] then
	  if CMDsTypeCacheIter < count then
        CMDsTypeCache[CMDsTypeCacheIter] = CMDsCache[i]	
        CMDsTypeCacheIter = CMDsTypeCacheIter + 1	
	  else
		break
      end		
	end
  end   
  
  for i=CMDsCount-1, CMDsIter, -1  do
    if current_cmd_type == "all" or cmd_type_id[CMDsCache[i][1]] >= cmd_type_id[current_cmd_type] then
	  if CMDsTypeCacheIter < count then	    
         CMDsTypeCache[CMDsTypeCacheIter] = CMDsCache[i]
	     CMDsTypeCacheIter = CMDsTypeCacheIter + 1	
	  else
		 break
	  end
	end
  end
  return CMDsTypeCache, CMDsTypeCacheIter
end



function IGpu:clearCMDsCache()
  CMDsCache = {}
  CMDsCount = 0
  CMDsIter = 0
end

--<============IThread=============>


IThread.threads = {}
IThread.threadsInfo = {}
IThread.counts = 0
IThread.openosOnErrorFunc = nil

IThread.isInitialize = false

function IThread:create(func, self_pointer, name)
  if not name then
    name = "unname"
  end
  ICore:debug("create thread ["..name.."] ")  
  self.threads[self.counts] = thread.create(func, self_pointer)
  self.threadsInfo[self.counts] = {func, self_pointer, name}  
  self.counts = self.counts + 1

  if not self.isInitialize then
    self:initialize()
  end  
end

function IThread:killAllThread()
  event.onError = IThread.openosOnErrorFunc
  for i=0, self.counts - 1 do
    (self.threads[i]):kill()
  end
  os.exit()
end

function IThread:initialize()
  self.isInitialize = true
  self.openosOnErrorFunc = event.onError
  event.onError = 
  function (msg)    	
    ICore:error(msg)   
  end
  self:create(self.threadMonitor, self, "IThread")
end

function IThread:threadMonitor()
  while true do       
    ICore:debug("Scan thread, count:"..self.counts)   
    for i=0, self.counts - 1 do
      local t = self.threads[i]	  
	  if t:status() == "dead" then
	    ICore:error("thread ["..self.threadsInfo[i][3].."] "..t:status())		
	    self.threads[i] = thread.create(self.threadsInfo[i][1], self.threadsInfo[i][2])
	    ICore:warn("restart thread ["..self.threadsInfo[i][3].."]")  	  
	  end      
    end
    os.sleep(5) 	
  end
end

--<============IComponent=============>

IComponent.include = {}
IComponent.include.modem = component.isAvailable("modem")

function IComponent:invoke(componentName, func, ...) 
  if component.isAvailable(componentName) then
    local result = component.getPrimary(componentName)
    return component.invoke(result.address, func, ...) 
  end
end

--<============INetwork=============>

math.randomseed(os.time())

INetwork.callback = nil
INetwork.port = math.random(10000)
INetwork.isWireless = false
INetwork.wirelessStrength = 0



function INetwork:initialize(_callback, _wirelessStrength) 
  INetwork.wirelessStrength = _wirelessStrength or 0
  if IComponent.include.modem then
    INetwork.callback = _callback   
	INetwork.isWireless = IComponent:invoke("modem", "isWireless")
	ICore:init("Modem Open PORT "..INetwork.port.." :"..tostring(IComponent:invoke("modem", "open", INetwork.port)))
	if _callback then    
      IThread:create(INetwork.thread, INetwork, "INetwork")
	end
  end
end

function INetwork:getNetworkInfomation()  
  return (ICore.IComponent.include.modem and tostring(INetwork.port)..(INetwork.isWireless and ("  Wireless:"..INetwork.wirelessStrength) or "") or "false")
end

function INetwork:broadcast(CMD, Msg)   
  if IComponent.include.modem then
    local pkg = serialization.serialize({CMD, Msg})  
    IComponent:invoke("modem", "broadcast", INetwork.port, pkg)
  end
end

function INetwork:send(address, CMD, Msg) 
  if IComponent.include.modem then
    local pkg = serialization.serialize({CMD, Msg})
    IComponent:invoke("modem", "send", address, INetwork.port, pkg)
  end
end

function INetwork:thread()
  while true do
    local _, _, from, port, _, message = event.pull("modem_message")    
	local pkg = serialization.unserialize(message)	
	if self.callback ~= nil then
	  self.callback(_, from, pkg[1], pkg[2])
	else
	  utils:debug("INetwork callback is nil")
	end
  end
end

--<============ICoreNetwork=============>

ICoreNetwork.remoteAddress = {}
ICoreNetwork.remoteAddress2Id = {}
ICoreNetwork.remoteCounts = 0
ICoreNetwork.msgCallback = nil
ICoreNetwork.commandList = 
{  
  ["Require Address"] = function(address, msg)
    ICoreNetwork:addRemoteAddress(address)
  end,

  ["Respond Address"] = function(address, msg) 
    ICoreNetwork:addRemoteAddress(address)
  end,  
  
  ["IGpu"] = function(address, msg) 
    ICoreNetwork:addRemoteAddress(address)

  end,
  
  ["ICMD"] = function(address, msg) 
    ICoreNetwork:addRemoteAddress(address)
	
  end
}

function ICoreNetwork:addRemoteAddress(address)
  if not ICoreNetwork.remoteAddress2Id[address] then
    ICoreNetwork.remoteAddress[ICoreNetwork.remoteCounts] = address
	ICoreNetwork.remoteAddress2Id[address] = ICoreNetwork.remoteCounts
	ICoreNetwork.remoteCounts = ICoreNetwork.remoteCounts + 1
	ICore:info("Network Connected:"..address)
  end
end

function ICoreNetwork:execute(address, com, msg)  
   local commandFunc = ICoreNetwork.commandList[com]
	if commandFunc ~= nil then	  
	  ICore:warn("[ICoreNetwork]Execute:"..com)	  
	  commandFunc(address, msg)
	elseif ICoreNetwork.msgCallback then
	  ICoreNetwork.msgCallback(address, com, msg)
	end
end

function ICoreNetwork:initialize(_msgCallback) 
  ICoreNetwork.msgCallback = _msgCallback
  INetwork:initialize(onMessageCome, _netWirelessStrength)     
end

function ICoreNetwork:send(CMD, Msg)
  if IComponent.include.modem then
    ICore:debug("[NetSend]"..CMD..":"..Msg) 
	for k, address in pairs(ICoreNetwork.remoteAddress2Id) do
	  INetwork:send(address, CMD, Msg) 
	end
  end
end

function ICoreNetwork:onMessageCome(Address, CMD, Msg)
  ICore:debug("@Address:", Address, ", CMD:", CMD, ", Msg:", Msg) 
  ICoreNetwork.execute(ReactorLocalNetwork, Address, CMD, Msg)
end

--<============IUtils=============>

function IUtils:writeFile(data, fileName)
  local file = io.open(fileName, "w")
  file:write(data)
  file:close()
  IUtils:debug("Writed"..fileName)
end

function IUtils:readFile(fileName)
  local file = io.open(fileName, "r")
  str = ""
  for line in file:lines() do
    str = str..line
  end
  IUtils:debug("Readed"..fileName)
  return str
end

function IUtils:fileExist(fileName)
  return filesystem.exists(fileName)
end

return ICore