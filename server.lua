local component = require("component")
local ICore = require("ICore")
local INet = require("INet")
local text = require("text")

local args = {...}
local top = 8

local CMDList = 
{   

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

function main()   
	local top = tonumber(args[1] or 8)
	local ibuilderServer = ICore.IBuilder:setCMDsTop(top):setCMDList(CMDList)
	local nbuilderServer = INet.NBuilder:setNet(101, ibuilderServer):setServerNet(onClientCommonMsgCome, onClientCMDMsgCome, onCopyDisplay):setNetRemoteConnectedCallback(onRemoteConnected):setWirelessStrength(16) 	
	ICore = INet:initialize(nbuilderServer)
		
end

function onClientCommonMsgCome(address, cmd, msg)
	
end

function onClientCMDMsgCome(address, cmd_type, msg)		
	ICore.IGpu:writeCMDsCache(cmd_type, msg)
	ICore.IGpu:printCMDsCache()	
	ICore.IGpu:fill(col1, top - 1, 160, 1, "=") 	
end

function onCopyDisplay(address, x, y, str, color, padRight)
	ICore.IGpu:print(x, y, str, color, padRight)	
end

main()