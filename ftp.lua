local ICore = require("ICore")
local INet = require("INet")
local INetStream = require("INetStream")
local INetFile = require("INetFile")
local shell = require("shell")
local fs = require("filesystem")

local lpwd = os.getenv("PWD")
local rpwd = "/"
local serverAddress = nil
local lGpu = nil
local rGpu = nil
local getTasks = {}
local CMDList = 
{  
  ["ls"] = function(coms)   	 
	  local userGlobalFolder = lpwd
	  local list = fs.list(userGlobalFolder)
	  local ls = userGlobalFolder.." #"
	  for v in list do
		  ls = ls.."  "..v
	  end
	  lout(ls)
   end,   
  ["cd"] = function(coms) 
	  local msg = coms[2]
	  if msg then
		  local userGlobalFolder = lpwd	 
		  local newUserGlobalFolder = fs.canonical(userGlobalFolder.."/"..msg)
		  if fs.isDirectory(newUserGlobalFolder) then
			  lpwd = newUserGlobalFolder			 
		  else
			  lout(newUserGlobalFolder.." not exit")
		  end
	  else
	  lout("Usage: cd <folder>")
	  end
   end, 
  ["mkdir"] = function(coms)     
	  local msg = coms[2]
	  if msg then
		  local userGlobalFolder = lpwd	 
		  local newUserGlobalFolder = fs.canonical(userGlobalFolder.."/"..msg)
		  if fs.isDirectory(newUserGlobalFolder) then
			  lout(newUserGlobalFolder.." has exited")
		  else			  
			  fs.makeDirectory(newUserGlobalFolder)		
		  end
	  else
	  lout("Usage: mkdir <folder>")
	  end
   end, 
   ["rm"] = function(coms)     
	  local msg = coms[2]
	  if msg then
		 local userGlobalFolder = lpwd	 
		 local userGlobalFile = fs.canonical(userGlobalFolder.."/"..msg)
		 if fs.exists(userGlobalFile) then
			lout("確認刪除 "..userGlobalFile.."? y/n")
			local key = ICore.IInput:read()			
			if ICore.IUtils:isStringContain(key, "y") then
				fs.remove(userGlobalFile)
				lout("刪除成功")	
			end
		 else
		    lout("remove file "..userGlobalFile.."fail: file not exit")
		 end
	  else
	  lout("Usage: rm <file or folder>")
	  end
   end,
  ["get"] = function(coms)   
	  local msg = coms[2]
	  if msg then
		  table.insert(getTasks, {serverAddress, msg})
	  else
	  lout("Usage: get <file>")
	  end	  
  end,
  ["send"] = function(coms)  
	  local msg = coms[2]
	  if msg then
		  local userGlobalFolder = lpwd	 
		  local userGlobalFile = fs.canonical(userGlobalFolder.."/"..msg)
		  local segments = fs.segments(userGlobalFile)
		  local finallyFilename = segments[#segments]			  
		  if fs.exists(userGlobalFile) then	
		      if serverAddress then
				  lout( "uploading...")
				  INet.INetwork:send(serverAddress, "send", finallyFilename)
				  os.sleep(1)
				  INetFile.send(INetStream, serverAddress, userGlobalFile) 				  
			  else
			      lout( "server is not connected")
			  end
		  else
			  lout( userGlobalFile.." not exit")
		  end
	  else
	  lout("Usage: send <file>")
	  end	  
   end,
  ["rls"] = function(coms)   	 
	  INet.INetwork:send(serverAddress, "ls", "")
   end,   
  ["rcd"] = function(coms) 
	  local msg = coms[2]
	  if msg then
		  INet.INetwork:send(serverAddress, "cd", msg)
	  else
	  lout("Usage: rcd <folder>")
	  end
   end, 
  ["rmkdir"] = function(coms)     
	  local msg = coms[2]
	  if msg then
		 INet.INetwork:send(serverAddress, "mkdir", msg)
	  else
	  lout("Usage: rmkdir <folder>")
	  end
   end, 
  ["rrm"] = function(coms)     
	  local msg = coms[2]
	  if msg then
		 lout("確認刪除 "..msg.."? y/n")
		 local key = ICore.IInput:read()
		 if ICore.IUtils:isStringContain(key, "y") then
			INet.INetwork:send(serverAddress, "rm", msg)
		 end		 
	  else
	  lout("Usage: rrm <folder>")
	  end
   end,
}

function get_thread()
	while true do
		while #getTasks == 0 do
			os.sleep(1)
		end
		local task = table.remove(getTasks)
		if task then
			local address = task[1]
			local msg = task[2]
			local userGlobalFolder = lpwd	 
			local userGlobalFile = fs.canonical(userGlobalFolder.."/"..msg)
			INet.INetwork:send(serverAddress, "get", msg)				
			lout( "downloading... ")
			local result, reason = INetFile.receive(INetStream, userGlobalFile)
			if result then
			    lout( "get " .. userGlobalFile .." successed!")
			else
			    lout( "get " .. userGlobalFile .." fail:" .. reason)
			end
		end
	end
end

local ResponsedList = 
{  
  ["FTP_R_LS"] = function(address, msg)     
		rpwd = msg
	    rout(rpwd)
   end,   
  ["FTP_R_CD"] = function(address, msg)     
		rpwd = msg
	    rout(rpwd)
   end,
  ["FTP_R_PWD"] = function(address, msg)     
		rpwd = msg
	    rout(rpwd)
   end,
  ["FTP_ERROR"] = function(address, msg)     
	    lout(msg)
   end, 
  ["FTP_SUCCESSED"] = function(address, msg)     
		lout(msg)
  end
}
local gpu = require("component").gpu
local w, h = gpu.getViewport()
local rect = {
		{x = 2, y = 3    , w = w - 2, h = h / 2 - 4},
		{x = 2, y = h / 2 + 2, w = w - 2, h = h / 2 - 5}
	}
function main()
	local maxWirelessStrength = 400
	local ibuilder = ICore.IBuilder:setCMDsTop(1):setCMDList(CMDList)	
	local nbuilderClient = INet.NBuilder:setNet(21, ibuilder):setNetRemoteConnectedCallback(onConnected):setClientNet(onServerMsgCome):setWirelessStrength(maxWirelessStrength)	
	ICore = INetStream:initialize(nbuilderClient)	
	ICore.IGpu:setCmdType("green")
	rGpu = ICore.IGpu:new(rect[1].x, rect[1].y , rect[1].w ,rect[1].h)
	lGpu = ICore.IGpu:new(rect[2].x, rect[2].y , rect[2].w ,rect[2].h)		
	ldisplay()	
	rdisplay()
	ICore.IThread:create(get_thread, nil, "get_thread")
end

function ldisplay()		
	ICore.IGpu:drawRectangle(1, h / 2 + 1 ,w ,h / 2 - 1, " ", 0x00FF00)	
	gpu.setForeground(0xFFFFFF)
	gpu.set(w / 2 - 5, h / 2 + 1, "本地 文件")	
	lGpu:clear(rect[2].x, rect[2].y , rect[2].w ,rect[2].h + 1)
end

function rdisplay()	
	ICore.IGpu:drawRectangle(1, 1 ,w, 1," ", 0x0000FF)	
	gpu.setForeground(0xFFFFFF)
	gpu.set(2, 1, "迷祢FTP")
	ICore.IGpu:drawRectangle(1, 2 ,w, h / 2 - 1," ", 0xFFFF00)		
	gpu.setForeground(0x000000)
	gpu.set(w / 2 - 5, 2, "遠程 文件")	
	rGpu:clear(rect[1].x, rect[1].y , rect[1].w ,rect[1].h + 1)
end

function onConnected(address)
	lout("Connected to server")
	serverAddress = address
end

function onServerMsgCome(address, CMD, msg)
	local commandFunc = ResponsedList[CMD]  
	if commandFunc ~= nil then	  	 	  
	  commandFunc(address, msg)
	end
end

function lout(...)	
	if lGpu then
		ldisplay()
		local str = ""
		for i,v in ipairs({...}) do
			str = str..(v and tostring(v) or "nil")
		end
		lGpu:writeCMDsCache("green", str)
		lGpu:printCMDsCache()		
	end	
end

function rout(...)	
	if rGpu then
		rdisplay()	
		local str = ""
		for i,v in ipairs({...}) do
			str = str..(v and tostring(v) or "nil")
		end
		rGpu:writeCMDsCache("yellow", str)
		rGpu:printCMDsCache()			
	end	
end

main()