local INet = {}
local NBuilder = {}
local INetwork = {}
local ICoreNetwork = {}
local IClientNetwork = {}
local IServerNetwork = {}

local ICore = require("ICore")
local event = require("event")
local component = require("component")
local serialization = require("serialization")

INet.NBuilder = NBuilder
INet.INetwork = INetwork
INet.ICoreNetwork = ICoreNetwork
INet.IClientNetwork = IClientNetwork
INet.IServerNetwork = IServerNetwork

INet.builder = nil

function INet:initialize(builder) 

  self.builder = builder
  self.builder.iCorebuilder.INet = self
  self.builder.iCorebuilder.sendCMDMsg = builder.sendCMDMsg
  self.builder.iCorebuilder.sendCopyDisplay = builder.sendCopyDisplay
  ICore = ICore:initialize(self.builder.iCorebuilder) 
  if component.isAvailable("modem") then
	  if builder.requireNetClient then	
		IClientNetwork:initialize()
	  end
	  if builder.requireNetServer then
		IServerNetwork:initialize()
	  end
  else
	ICore:warn("INet is unavailable")
  end
  return ICore
end

function INet:setWirelessStrength(s) 
	if ICore.IComponent:invoke("modem", "isWireless") then
		ICore.IComponent:invoke("modem", "setStrength", s)
	end
end

function INet.simplifyAddress(address) 
	return string.sub(address, 1, 3)
end

--<============NBuilder=============>

NBuilder.iCorebuilder = nil
NBuilder.sendCMDMsg = false
NBuilder.sendCopyDisplay = false

function NBuilder:setNet(_port, iCorebuilder)			
	self.port = _port		
	self.iCorebuilder = iCorebuilder	
	return self
end

function NBuilder:setNetRemoteConnectedCallback(_remoteConnectedCallback)	
	self.remoteConnectedCallback = _remoteConnectedCallback	
	return self
end

function NBuilder:setClientNet(_serverMsgCallback, _serverCMDCallback)		
	self.serverMsgCallback = _serverMsgCallback	
	self.serverCMDCallback = _serverCMDCallback
	self.requireNetClient = true
	return self
end

function NBuilder:setServerNet(_commonMsgCallback, _CMDMsgCallback, _copyDisplayCallback)	
	self.commonMsgCallback = _commonMsgCallback
	self.CMDMsgCallback = _CMDMsgCallback
	self.copyDisplayCallback = _copyDisplayCallback
	self.requireNetServer = true
	return self
end

function NBuilder:SendCMDMsg()
	self.sendCMDMsg = true	
	return self
end

function NBuilder:SendCopyDisplay()		
	self.sendCopyDisplay = true
	return self
end

function NBuilder:setWirelessStrength(s)		
	self.wirelessStrength = s
	return self
end

--<============INetwork=============>

math.randomseed(os.time())

INetwork.callback = nil
INetwork.port = 0
INetwork.isWireless = false
INetwork.wirelessStrength = 0

function INetwork:initialize(_callback) 
  self.wirelessStrength = INet.builder.wirelessStrength or 0
  if ICore.IComponent:invoke("modem", "isWireless") then
	ICore.IComponent:invoke("modem", "setStrength", self.wirelessStrength)
  end
  self.port = INet.builder.port or math.random(10000)
  if ICore.IComponent.include.modem then
    self.callback = _callback   
	self.isWireless = ICore.IComponent:invoke("modem", "isWireless")
	ICore:init("Modem Open PORT "..self.port.." :"..tostring(ICore.IComponent:invoke("modem", "open", self.port)))
	if _callback then    
      ICore.IThread:create(self.thread, self, "INetwork")
	end
  end
end

function INetwork:getNetworkInfomation()  
  return (ICore.IComponent.include.modem and tostring(self.port)..(self.isWireless and ("  Wireless:"..self.wirelessStrength) or "") or "false")
end

function INetwork:broadcast(CMD, Msg)   
  if ICore.IComponent.include.modem then
	ICore:debug("broadcast:".."["..CMD.."]"..Msg)
    local pkg = serialization.serialize({CMD, Msg})  
    ICore.IComponent:invoke("modem", "broadcast", self.port, pkg)
  end
end

function INetwork:send(address, CMD, Msg) 
  if ICore.IComponent.include.modem then
    if not Msg then
		ICore:error(debug.traceback())
		error("Msg is nil")		
		return 
	end
	ICore:debug("INET send:", "[", CMD, "]", Msg)
    local pkg = serialization.serialize({CMD, Msg})
    ICore.IComponent:invoke("modem", "send", address, self.port, pkg)
  end
end

function INetwork:thread()
  while not ICore.IThread.stop do
    local _, _, from, port, _, message = event.pull("modem_message")    
	local pkg = serialization.unserialize(message)	
	if self.callback ~= nil then	  
	  self.callback(_, from, pkg[1], pkg[2])
	else
	  ICore:debug("self callback is nil")
	end
  end
end

--<============ICoreNetwork=============>

ICoreNetwork.remoteAddress = {}
ICoreNetwork.remoteAddress2Id = {}
ICoreNetwork.remoteCounts = 0
ICoreNetwork.msgCallback = nil
ICoreNetwork.commandList = {}
ICoreNetwork.isInitialize = false

function ICoreNetwork:addServerAddress(address)
  if not ICoreNetwork.remoteAddress2Id[address] then
    ICoreNetwork.remoteAddress[ICoreNetwork.remoteCounts] = address
	ICoreNetwork.remoteAddress2Id[address] = ICoreNetwork.remoteCounts
	ICoreNetwork.remoteCounts = ICoreNetwork.remoteCounts + 1
	ICore:info("Remote Connected:"..address)
	if INet.builder.remoteConnectedCallback then
		INet.builder.remoteConnectedCallback(address)
	end
  end
end

function ICoreNetwork:execute(address, com, msg)  
   local commandFunc = ICoreNetwork.commandList[com]  
	if commandFunc ~= nil then	  
	  ICore:debug("[ICoreNetwork]Execute:"..com)	  
	  commandFunc(address, msg)
	elseif ICoreNetwork.msgCallback then		
	  ICoreNetwork.msgCallback(address, com, msg)
	else 
	  ICore:debug("unExecute:"..com)	  
	end
end

function ICoreNetwork:initialize(_cmdlist, _msgCallback) 
	ICoreNetwork.commandList = _cmdlist
	ICoreNetwork.msgCallback = _msgCallback
	INetwork:initialize(ICoreNetwork.onMessageCome)   
	ICoreNetwork.isInitialize = true
end

function ICoreNetwork:send(CMD, Msg)
  if ICore.IComponent.include.modem then    
	for k, address in pairs(ICoreNetwork.remoteAddress) do	  
	  INetwork:send(address, CMD, Msg) 
	end
  end
end

function ICoreNetwork:onMessageCome(Address, CMD, Msg)
  ICore:debug("ICoreNetwork@Address:", INet.simplifyAddress(Address) , ", CMD:", CMD, ", Msg:", Msg) 
  ICoreNetwork.execute(ICoreNetwork, Address, CMD, Msg)
end

--<============IClientNetwork=============>

IClientNetwork.commandList = 
{  
  ["Require Address"] = function(address, msg)
	if msg == "From Server" then
		ICoreNetwork:addServerAddress(address)
		ICoreNetwork:send("Respond Address",  "From Client")
	end
  end,

  ["Respond Address"] = function(address, msg) 
    ICoreNetwork:addServerAddress(address)
  end, 

  
  ["Remote CMD"] = function(address, msg) 
  
    ICoreNetwork:addServerAddress(address)
	if INet.builder.serverCMDCallback then	
		local pkg = serialization.unserialize(msg)  
		INet.builder.serverCMDCallback(msg)
	end
  end,
}

function IClientNetwork:initialize() 
	ICoreNetwork:initialize(IClientNetwork.commandList, INet.builder.serverMsgCallback) 
	INetwork:broadcast("Require Address", "From Client")
end


--<============IServerNetwork=============>

IServerNetwork.commandList = 
{  
  ["Require Address"] = function(address, msg)
    if msg == "From Client" then
		ICoreNetwork:addServerAddress(address)
		ICoreNetwork:send("Respond Address",  "From Server")	
	end
  end,

  ["Respond Address"] = function(address, msg) 
    ICoreNetwork:addServerAddress(address)
  end,
  
  ["ICMD"] = function(address, msg) 
    ICoreNetwork:addServerAddress(address)	
	if INet.builder.CMDMsgCallback then
		local cache = serialization.unserialize(msg)  
		INet.builder.CMDMsgCallback(address, cache[1], cache[2])
	end
  end,
  
  ["IGpu"] = function(address, msg) 
    ICoreNetwork:addServerAddress(address)	
	if INet.builder.copyDisplayCallback then
		local cache = serialization.unserialize(msg) 
		local x, y, str, color, padRight = cache[1], cache[2], cache[3], cache[4], cache[5]		
		INet.builder.copyDisplayCallback(address, x, y, str, color, padRight)
	end
  end,
}

function IServerNetwork:initialize() 
	ICoreNetwork:initialize(IServerNetwork.commandList, INet.builder.commonMsgCallback) 
	INetwork:broadcast("Require Address", "From Server")
end

function IServerNetwork:sendRemoteCMD(coms)
	local comsStr = ""
    for k, v in pairs(coms) do
	  if k > 1 then
		comsStr = comsStr..v.." "
	  end
    end
	ICoreNetwork:send("Remote CMD", comsStr)
end

return INet