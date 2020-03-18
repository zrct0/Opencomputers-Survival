local component = require("component")
local ICore = require("ICore")

local Block = {}

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

local blocks = {}
local startX, startY, blockW, blockH = {}, {}, 0, 0
local blocksColor = {}
local color = {running = 0x002400, disconnet = 0x0F0F0F}


function main()   	
	local ibuilder = ICore.IBuilder:setCMDsTop(25):setCMDList(CMDList):setNet(100, false):setServerNet(onClientCommonMsgCome, onClientCMDMsgCome):setNetRemoteConnectedCallback(onRemoteConnected) 	
	ICore:initialize(ibuilder)	
	local startX, startY, blockW, blockH = {}, {}, 0, 0
	blockW = ICore.w
	blockH = 10
	startX = {1, 1, 1, 1}  
	startY = {2 + blockH * 0, 3 + blockH * 1, 4 + blockH * 2, 5 + blockH * 3}  
	blocksColor = {color.disconnet, color.disconnet, color.disconnet, color.disconnet}
	for i=1, 4 do		
		blocks[i] = Block:new(startX[i], startY[i] , blockW, blockH, i)
	end  
	while true do
		os.sleep(1)
	end
end

function onRemoteConnected()

end

function onClientCommonMsgCome(address, cmd, msg)
	
end

function onClientCMDMsgCome(address, cmd_type, msg)		
	local block = blocks[2]	
	block:writeBlockCMDs(cmd_type, msg)	
end

--<============Block=============>

Block.IGpu = nil
Block.index = 1
Block.x = 0
Block.y = 0
Block.w = 0
Block.h = 0
function Block:new(_x, _y ,_w ,_h)
	local t = {}
	setmetatable(t, self)
	self.__index = self
	t:initialize(_x, _y ,_w ,_h)
	return t
end

function Block:initialize(_x, _y ,_w ,_h, _index)
	self.x, self.y, self.w, self.h, self.index = _x , _y , _w , _h, _index
	ICore.IGpu:drawRectangle(self.x, self.y ,self.w ,self.h, " ", blocksColor[self.index])	
	self.IGpu = ICore.IGpu:new(self.x, self.y - 1,self.w ,self.h)
	self.IGpu:clearCMDsCache()
end

function Block:onClientCommonMsgCome(cmd, msg)
	
end

function Block:writeBlockCMDs(cmd_type, msg)	
	self.IGpu:writeCMDsCache(cmd_type, msg)
	self.IGpu:setBgColor(blocksColor[self.index])
	self.IGpu:printCMDsCache()
end

main()