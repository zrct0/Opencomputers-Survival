local INetStream = {}
local NSBuilder = {}

local INet = require("INet")
local buffer = require("buffer")
local event = require("event")


INetStream.stream = 
{	
	["address"] = nil,
	["write"] = function(self, arg)			
		if self.address then
			INet.INetwork:send(self.address, "IIS",  arg)
		else
			INet.ICoreNetwork:send("IIS",  arg)
		end
		return true
	end,
	["read"] = function(self, arg)			
		local _, msg = event.pull(2, "INetStream_read")
		ICore:debug("event.pull:", msg)
		if msg == "eof" then
			ICore:debug("read msg == eof")
			return nil
		end
		return msg
	end,
	["close"] = function(self)		
		ICore:debug("stream close")
		if self.address then
			INet.INetwork:send(self.address, "IIS",  "eof")
		else
			INet.ICoreNetwork:send("IIS",  "eof")
		end
		
	end,	
}

function INetStream.stream:new(mode)
	local t = {}
	setmetatable(t, self)
	self.__index = self		
	return t, buffer.new(mode, t)	 
end

function INetStream:initialize(inetbuilder)   
  ICore = INet:initialize(inetbuilder)	    
  return ICore
end

function INetStream.INetInputStream()
	local stream, buffer = INetStream.stream:new("r")
	buffer:setTimeout(30)
	buffer:setvbuf(nil, 128)	
	INet.ICoreNetwork.commandList.IIS = 
	function(address, msg)		
		ICore:debug("event.push:", msg)
		event.push("INetStream_read", msg)	
	end		
	return buffer
end 

function INetStream.INetOutputStream(address)
	local stream, buffer = INetStream.stream:new("w")
	stream.address = address
	buffer:setvbuf(nil, buffer.bufferSize * 0.5)	
	return buffer	
end

return INetStream