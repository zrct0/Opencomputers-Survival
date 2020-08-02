local ICore = {}
local IBuilder = {}
local IGpu = {}
local IThread = {}
local IComponent = {}
local IUtils = {}
local IState = {}
local IInput = {}
local ICMD = {}

local serialization = require("serialization")
local computer = require("computer")
local component = require("component")
local text = require("text")
local thread = require("thread")
local event = require("event")
local term = require("term")


ICore.IBuilder = IBuilder
ICore.IGpu = IGpu
ICore.IThread = IThread
ICore.IUtils = IUtils
ICore.IComponent = IComponent
ICore.IState = IState
ICore.ICMD = ICMD
ICore.IInput = IInput
ICore.w = 0
ICore.h = 0
ICore.msgt_type = "info"

ICore.builder = nil


function ICore:new(builder)
  local t = {}
  setmetatable(t, self)
  self.__index = self
  t:initialize(builder)
  return t
end

function ICore:initialize(builder) 
  self.builder = builder
  self.isCMDsPrintTime = builder.isCMDsPrintTime 
  self.IGpu:initialize()
  self.IGpu.current_cmd_type = self.msgt_type
  local w, h = self.IGpu:getViewport()
  self.w = w
  self.h = h
  if builder.CMDList then
	ICMD:initialize(builder.CMDList)
	self.IGpu:setCMDMsgPosition(builder.CMDsTop, builder.CMDsBottom or h-2)
  else
	self.IGpu:setCMDMsgPosition(builder.CMDsTop, builder.CMDsBottom or h)
  end   
  term.clear()  
  return self
end

function ICore:error(...)    
    self:printMsg("error", "ERROR:", ...)
end

function ICore:warn(...)
    self:printMsg("warn", "WARN:", ...)
end

function ICore:info(...)
   self:printMsg("info", "INFO:", ...)
end

function ICore:init(...)
   self:printMsg("init", "INIT:", ...)
end

function ICore:debug(...)
   self:printMsg("debug", "DEBUG:", ...)
end

function ICore:printMsg(cmd_type, prefix, ...) 
	local str = prefix
	for i,v in ipairs({...}) do
		str = str..(v and tostring(v) or "nil")
	end
	if self.builder.isCMDsPrintTime then
		self.IGpu:writeCMDsCache(cmd_type, "["..os.date("%X").."]"..str)
	else
		self.IGpu:writeCMDsCache(cmd_type, str)
	end
	self.IGpu:printCMDsCache()
end

--<============IBuilder=============>

IBuilder.isCMDsPrintTime = false
IBuilder.CMDsTop = 0
IBuilder.port = 1
IBuilder.requireNetClient = false
IBuilder.requireNetServer = false
IBuilder.sendCMDMsg = false
IBuilder.sendCopyDisplay = false
IBuilder.INet = nil


function IBuilder:setCMDsTop(_CMDsTop)
	IBuilder.CMDsTop = _CMDsTop	
	return IBuilder
end

function IBuilder:setCMDMsgPosition(top, bottom)
	IBuilder.CMDsTop = top	
	IBuilder.CMDsBottom = bottom	
	return IBuilder
end

function IBuilder:setCMDList(_CMDList)		
	IBuilder.CMDList = _CMDList	
	return IBuilder
end

function IBuilder:setIsCMDsPrintTime(_isCMDsPrintTime)		
	IBuilder.isCMDsPrintTime = _isCMDsPrintTime	
	return IBuilder
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
local w, h = 0
IGpu.CMDsCache = {}
IGpu.CMDsCount = 0
IGpu.CMDsIter = 0
IGpu.MAX_CMDs_COUNT = 20
IGpu.MAIN_INFO_HEIGHT = 0
IGpu.CMDs_INFO_HEIGHT = 0
IGpu.CMDPOS_BOTTOM = 0
IGpu.cmd_type_id = {["all"] = -1, ["debug"] = 0, ["init"] = 1, ["info"] = 2, ["warn"] = 3, ["green"] = 4, ["yellow"] = 5, ["error"] = 6}
IGpu.cmd_type_color = {["debug"] = 0xFFFFFF, ["init"] = 0xFF00FF, ["info"] = 0x0000FF, ["green"] = 0x00FF00, ["yellow"] = 0xFFFF00, ["warn"] = 0xFFFF00, ["error"] = 0xFF0000}
IGpu.isInitialize = false
IGpu.current_cmd_type = "debug"
IGpu.bgColor = 0x000000

IGpu.x = 0
IGpu.y = 0
IGpu.w = 0
IGpu.h = 0

IGpu.CMDMsgCallback = nil
IGpu.gpu = component.gpu
IGpu.enableCMD = true

function IGpu:new(_x, _y ,_w ,_h)
  local t = {}
  setmetatable(t, self)
  self.__index = self
  t:initialize(_x, _y ,_w ,_h)
  return t
end

function IGpu:initialize(_x, _y ,_w ,_h)
  self.x, self.y, self.w, self.h = _x , _y , _w , _h
  w, h = self.gpu.getViewport()
  if self.x and self.y and self.w and self.h then
		
  else
	self.x = 2
	self.y = 1
	self.w = w
	self.h = h - 2
  end  
  self.MAIN_INFO_HEIGHT = self.y
  self.CMDs_INFO_HEIGHT = self.h
  self.CMDPOS_BOTTOM = self.y + self.h
  local totalMemory = computer.freeMemory() 
  local Memory_1T = 19300
  if totalMemory > Memory_1T * 2 then
    self.MAX_CMDs_COUNT = 70
  end
  if totalMemory > Memory_1T * 3 then
    self.MAX_CMDs_COUNT = 200
  end
  if totalMemory > Memory_1T * 4 then
    self.MAX_CMDs_COUNT = 600
  end
  print("totalMemory:"..totalMemory..", self.MAX_CMDs_COUNT:"..self.MAX_CMDs_COUNT) 
  self:clearCMDsCache()
  self.isInitialize = true
  return w, h
end

function IGpu:getViewport()
  return w, h
end

function IGpu:setCMDMsgPosition(top, bottom)
  self.MAIN_INFO_HEIGHT = top
  self.CMDPOS_BOTTOM = bottom
  self.CMDs_INFO_HEIGHT = bottom - top
end

function IGpu:setCMDMsgCallback(_CMDMsgCallback)  
  self.CMDMsgCallback = _CMDMsgCallback
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
  if not self.enableCMD then
    return
  end
  local cache = {cmd_type, tostring(self.CMDsIter < 10 and "[0" or "[")..self.CMDsIter.."]"..cmd}
  self.CMDsCache[self.CMDsIter] = cache
  self.CMDsIter = self.CMDsIter + 1
  if self.CMDsIter >= self.MAX_CMDs_COUNT then
    self.CMDsIter = 0
  end 
  if self.CMDsCount < self.MAX_CMDs_COUNT then
    self.CMDsCount = self.CMDsCount + 1
  end
  
  if self.cmd_type_id[cmd_type] >= self.cmd_type_id["init"] then
    if self.CMDMsgCallback then
      self.CMDMsgCallback(_, cache)
	end
	
	remoteSend = remoteSend or ICore.builder.sendCMDMsg
    if remoteSend and ICore.builder.INet and ICore.builder.INet.ICoreNetwork.isInitialize then
      local pkg = serialization.serialize(cache)  
      ICore.builder.INet.ICoreNetwork:send("ICMD", pkg)
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

  if color == nil or self.gpu.getDepth() < 4 then
    color = 0xFFFFFF
  end
  if padRight == nil then
    padRight = w
  end
  self.gpu.setForeground(color)
  self.gpu.setBackground(0x000000)
  self.gpu.set(x, y, text.padRight(str, padRight))
  self.gpu.setForeground(0xFFFFFF)

  if remoteSend == nil then
    remoteSend = ICore.builder.sendCopyDisplay
  end

  if remoteSend and ICore.builder.INet and ICore.builder.INet.ICoreNetwork.isInitialize then
    local pkg = serialization.serialize({x, y, str, color, padRight})  
    ICore.builder.INet.ICoreNetwork:send("IGpu", pkg)
  end
end

function IGpu:fill(x, y, w, h, chr, color)

  if color == nil or self.gpu.getDepth() < 4 then
    color = 0xFFFFFF
  end
  self.gpu.setForeground(color)
  self.gpu.setBackground(0x000000)
  self.gpu.fill(x, y, w, h ,chr)
  self.gpu.setForeground(0xFFFFFF)
end

function IGpu:printCMDsCache()	
  if not self.enableCMD then
    return
  end
  local CMDsTypeCache, CMDsTypeCacheCount = self:getCMDsCache(self.CMDs_INFO_HEIGHT)
  local lastLine = self.CMDs_INFO_HEIGHT
  local line = self.CMDPOS_BOTTOM  
  local i = 0
  local tline = 0
  while tline <= lastLine and i < CMDsTypeCacheCount do	   
    self.gpu.setForeground(self:getCMDColor(CMDsTypeCache[i][1]))
    self.gpu.setBackground(self.bgColor)
	local sout = CMDsTypeCache[i][2]
	local slen = string.len(sout)
	local pline = math.floor(slen / self.w)
	local sline = 0
	while sline * self.w < slen do
		local substart = sline * self.w
		local subend = (sline + 1) * self.w - 1
		local lout = string.sub(sout, substart, subend)
		self.gpu.set(self.x, line - pline + sline, text.padRight(lout, self.w))
		sline = sline + 1
		tline = tline + 1
	end		
    line = line - sline	
	i = i + 1	
  end 
  self.gpu.setForeground(0xFFFFFF)
end

function IGpu:setBgColor(_color)
	self.bgColor = _color
end

function IGpu:getCMDColor(cmd_type)
  if self.gpu.getDepth() >= 4 then
    return self.cmd_type_color[cmd_type]
  else
    return 0xFFFFFF
  end
end

function IGpu:setCmdType(cmd_type)  
  if self.cmd_type_id[cmd_type] ~= nil then
    self.gpu.fill(1, self.MAIN_INFO_HEIGHT, w, h, " ")   
	self:writeCMDsCache("info", "["..os.date("%X").."]INFO:Set CMD Type:->"..cmd_type)
    self:printCMDsCache()   
    self.current_cmd_type = cmd_type
	return true
  end
  return false
end

function IGpu:getCMDsCache(count)
  local CMDsTypeCache = {}
  local CMDsTypeCacheIter = 0
  for i=self.CMDsIter-1, 0, -1 do  
    if self.current_cmd_type == "all" or self.cmd_type_id[self.CMDsCache[i][1]] >= self.cmd_type_id[self.current_cmd_type] then
	  if CMDsTypeCacheIter < count then
        CMDsTypeCache[CMDsTypeCacheIter] = self.CMDsCache[i]	
        CMDsTypeCacheIter = CMDsTypeCacheIter + 1	
	  else
		break
      end		
	end
  end   
  
  for i=self.CMDsCount-1, self.CMDsIter, -1  do
    if self.current_cmd_type == "all" or self.cmd_type_id[self.CMDsCache[i][1]] >= self.cmd_type_id[self.current_cmd_type] then
	  if CMDsTypeCacheIter < count then	    
         CMDsTypeCache[CMDsTypeCacheIter] = self.CMDsCache[i]
	     CMDsTypeCacheIter = CMDsTypeCacheIter + 1	
	  else
		 break
	  end
	end
  end
  return CMDsTypeCache, CMDsTypeCacheIter
end

function IGpu:drawRectangle(_x, _y ,_w, _h, chr, color)
  self.gpu.setForeground(0xFFFFFF)
  self.gpu.setBackground(color)
  self.gpu.fill(_x, _y, _w, _h, chr)
end

function IGpu:clear(x, y, w, h)
  x = x or 1
  y = y or 1
  w = w or ICore.w
  h = h or ICore.h
  self.gpu.setBackground(0x000000)
  self.gpu.fill(x, y, w, h, " ")
end

function IGpu:clearCMDsCache()
  self.CMDsCache = {}
  self.CMDsCount = 0
  self.CMDsIter = 0
end

--<============IThread=============>


IThread.threads = {}
IThread.threadsInfo = {}
IThread.threadsValues = {}
IThread.counts = 0
IThread.openosOnErrorFunc = nil

IThread.isInitialize = false
IThread.stop = false

function IThread:create(func, self_pointer, name)
  if self.stop then
	return
  end
  if not name then
    name = "unname"
  end
  ICore:info("create thread ["..name.."] ")  
  self.threads[self.counts] = thread.create(func, self_pointer)
  self.threadsInfo[self.counts] = {func, self_pointer, name}  
  self.threadsValues[self.counts] = {}
  self.counts = self.counts + 1

  if not self.isInitialize then
    self:initialize()
  end  
end

function IThread:getCurrentThreadId()		
	for i=0, self.counts - 1 do			
		if self.threads[i] == thread.current() then		
			return i
		end		
	end
	ICore:error("getCurrentThreadId fail")
	return false
end

function IThread:getCurrentThreadName()		
	local threadId = self:getCurrentThreadId()
	if threadId then
		return self.threadsInfo[threadId][3]
	end
	ICore:error("Can not find name ", threadId)
	return false
end

function IThread:getCurrentThreadValue()
	local threadId = self:getCurrentThreadId()
	if threadId then
		return self.threadsValues[threadId]
	end
	ICore:error("Can not find threadValue ", threadId)
	return false
end

function IThread:resume(name)
	for i=0, self.counts - 1 do		
		if self.threadsInfo[i][3] == name then
			local t = self.threads[i] 
			ICore:debug("thread ["..self.threadsInfo[i][3].."]resume")		
			t:resume()
			return true
		end		
	end
	ICore:error("resume thread ["..name.."] can not find")
	return false
end

function IThread:suspend(name)
	if name then
		for i=0, self.counts - 1 do		
			if self.threadsInfo[i][3] == name then
				local t = self.threads[i] 
				ICore:debug("thread ["..self.threadsInfo[i][3].."]suspend")		
				t:suspend()
				return true
			end		
		end
		ICore:error("suspend thread ["..name.."] can not find")
		return false
	else
		ICore:debug("thread [curerent]suspend")		
		thread.current():suspend()
	end
end

function IThread:killThread(name)
	for i=0, self.counts - 1 do		
		if self.threadsInfo[i][3] == name then
			local t = self.threads[i] 
			ICore:debug("thread ["..self.threadsInfo[i][3].."]killed")		
			t:kill()
			return true
		end		
	end
	ICore:error("kill thread ["..name.."] can not find")
	return false
end

function IThread:killAllThread()
  self.stop = true
  ICore:error("run killAllThread, ", self.stop)
  event.onError = self.openosOnErrorFunc
  for i=0, self.counts - 1 do
    (self.threads[i]):kill()
	ICore:warn("kill ", self.threads[i], ", ", (self.threads[i]):status())
  end    
  os.exit()
end

function IThread:initialize()
  self.isInitialize = true
  self.openosOnErrorFunc = event.onError
  event.onError = 
  function (msg)  
	IThread:getCurrentThreadId()	
	ICore:error("Thread ERROR:",  IThread:getCurrentThreadName())
    ICore:error(msg)	
  end
  self:create(self.threadMonitor, self, "ithread")
end

function IThread:threadMonitor()
  while not self.stop do     	
    --ICore:debug("Scan thread, count:"..self.counts)   
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
--<============ICMD=============>

ICMD.commandList = nil

function ICMD:initialize(_commandList) 
  self.commandList = _commandList
  IInput:initialize(3) 
  IThread:create(self.thread, self, "ICMD")  
end

function ICMD:thread()
  while true do      
	IGpu.gpu.set(1, h, "# ")
    self:execute(IInput:read())
  end
end

function ICMD:execute(com) 
 if self.commandList then
   coms = text.tokenize(com) 
   local commandFunc = self.commandList[coms[1]]
	if commandFunc ~= nil then
	  IGpu:printLine(1, " ", nil, true)	
	  ICore:debug("Execute "..com)
	  commandFunc(coms)
	else	  
	  local usage = "Usage:  "	 
	  for key, value in pairs(self.commandList) do 
        usage = usage.."  "..key
      end
	  IGpu:printLine(1, usage, nil, true)	  
	end
  end
end


--<============IInput=============>

IInput.stream = ""
IInput.slen = 0
IInput.x = 1
IInput.y = h


function IInput:initialize(x, y) 
	self.x = x or 1
	self.y = y or h
    IThread:create(self.thread, self, "IInput")  
end

function IInput:thread()
  while true do  
	  IGpu.gpu.setBackground(0x000000)
      IGpu.gpu.set(self.x + self.slen, self.y, " ")
	  os.sleep(0.5)
	  IGpu.gpu.setBackground(0xFFFFFF)
	  IGpu.gpu.set(self.x + self.slen, self.y, " ")
	  os.sleep(0.5)
  end
end

function IInput:read(bgColor, fgColor)
	bgColor = bgColor or 0x000000
	fgColor = fgColor or 0xFFFFFF
	self.stream = ""
	local eventname, keyboardAddress, chr, code, playerName = event.pull("key_down")	
	while chr ~= 13 do	 	
	  IGpu.gpu.setBackground(bgColor)
	  IGpu.gpu.getForeground(fgColor)	  
	  if chr == 8 then
	    if self.slen > 0 then
			self.stream = string.sub(self.stream, 1, -2)
			IGpu.gpu.set(self.x, self.y, self.stream.."  ")	  
			self.slen = self.slen - 1
		end
	  else
	    if chr >=32 and chr <=126 then
		self.stream = self.stream..string.char(chr)
		IGpu.gpu.set(self.x, self.y, self.stream.."  ")	  
		self.slen = self.slen + 1
		end
	  end	  
	  eventname, keyboardAddress, chr, code, playerName = event.pull("key_down")
	end
	IGpu.gpu.setBackground(bgColor)
	IGpu.gpu.fill(self.x, self.y, self.slen + 1, 1, " ")
	self.slen = 0
	return self.stream
end

--<============IUtils=============>

function IUtils:writeFile(data, fileName)
  local file = io.open(fileName, "w")
  file:write(data)
  file:close()
  ICore:debug("Writed"..fileName)
end

function IUtils:readFile(fileName)
  local file = io.open(fileName, "r")
  str = ""
  for line in file:lines() do
    str = str..line
  end
  ICore:debug("Readed"..fileName)
  return str
end

function IUtils:fileExist(fileName)
  return filesystem.exists(fileName)
end

function IUtils:execute(commandList, com, msg)  
   local commandFunc = commandList[com]
	if commandFunc ~= nil then	
	  commandFunc(msg)	
	end
end

function IUtils:isStringContain(str, subStr)
	if string.find(str, subStr) then
		return true
	end
	return false
end

function IUtils:isTableContain(tab, element)
  for _, value in pairs(tab) do
    if IUtils:isStringContain(element, value) then
      return true
    end
  end
  return false
end

function IUtils:stackPush(stack, value)
  table.insert(stack, value)
end

function IUtils:stackPop(stack)
  return table.remove (stack)
end

function IUtils:stackToString(stack)
  local str = ""
  for k, v in pairs(stack) do
    str = str..tostring(v)
  end
  return str
end

return ICore