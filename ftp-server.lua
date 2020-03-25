local ICore = require("ICore")
local INet = require("INet")
local INetStream = require("INetStream")
local INetFile = require("INetFile")
local shell = require("shell")
local fs = require("filesystem")

local users = {}
local ftpFolder = "/home/ftp/"
local sendTasks = {}
ServerList = 
{  
  ["ls"] = function(address, msg)     
	  local usersFolder = getUserPwd(address)	 
	  local userGlobalFolder = fs.canonical(ftpFolder .. usersFolder)
	  local list = fs.list(userGlobalFolder)
	  local ls = usersFolder.." #"
	  for v in list do
		  ls = ls.."  "..v
	  end
	  INet.INetwork:send(address, "FTP_R_LS", ls)
   end,   
  ["cd"] = function(address, msg)     
	  local usersFolder = getUserPwd(address)
	  local userGlobalFolder = fs.canonical(ftpFolder .. usersFolder)
	  local newUsersFolder = fs.canonical(usersFolder.."/"..msg)
	  local newUserGlobalFolder = fs.canonical(userGlobalFolder.."/"..msg)
	  if fs.isDirectory(newUserGlobalFolder) then		  
		  setUserPwd(address, newUsersFolder)
		  INet.INetwork:send(address, "FTP_R_CD", newUsersFolder)
	  else
	      INet.INetwork:send(address, "FTP_ERROR", newUsersFolder.." not exit")
	  end
   end, 
  ["pwd"] = function(address, msg)     
	  local usersFolder = getUserPwd(address)	  
	  INet.INetwork:send(address, "FTP_R_PWD", usersFolder)
   end,
  ["mkdir"] = function(address, msg)     
	  local usersFolder = getUserPwd(address)
	  local userGlobalFolder = fs.canonical(ftpFolder .. usersFolder)
	  local newUsersFolder = fs.canonical(usersFolder.."/"..msg)
	  local newUserGlobalFolder = fs.canonical(userGlobalFolder.."/"..msg)
	  if fs.isDirectory(newUserGlobalFolder) then
		  INet.INetwork:send(address, "FTP_ERROR", newUsersFolder.." has exited")
	  else
	      fs.makeDirectory(newUserGlobalFolder)	
	  end
   end, 
  ["rm"] = function(address, msg) 	  
	  local usersFolder = getUserPwd(address)
	  local usersFile = fs.canonical(usersFolder .. "/" .. msg)
	  local userGlobalFolder = fs.canonical(ftpFolder .. usersFolder)
	  local userGlobalFile  = fs.canonical(userGlobalFolder .. "/" .. msg)	  
	  if fs.exists(userGlobalFile) then
		  if checkUserPwdPermissions(address, usersFile) then
			  fs.remove(userGlobalFile)	
			  INet.INetwork:send(address, "FTP_SUCCESSED", "刪除成功")
		  else
			  INet.INetwork:send(address, "FTP_ERROR", "刪除失敗,缺少權限")			  
		  end		 	  
	  else
		  INet.INetwork:send(address, "FTP_ERROR", usersFile.." not exit")
	  end
   end, 
  ["get"] = function(address, msg)
      local usersFolder = getUserPwd(address)
	  local usersFile = fs.canonical(usersFolder .. "/" .. msg)
	  local userGlobalFolder = fs.canonical(ftpFolder .. usersFolder)
	  local userGlobalFile  = fs.canonical(userGlobalFolder .. "/" .. msg)	  
	  if fs.exists(userGlobalFile) then
		  os.sleep(1)
		  INetFile.send(INetStream, address, userGlobalFile) 
	  else
		  INet.INetwork:send(address, "FTP_ERROR", usersFile.." not exit")
	  end
  end,
  ["send"] = function(address, msg)  
	    table.insert(sendTasks, {address, msg})
   end,
   
}

function send_thread()
	while true do
		while #sendTasks == 0 do
			os.sleep(1)
		end
		local task = table.remove(sendTasks)
		if task then
			local address = task[1]
			local msg = task[2]
			local usersFolder = getUserPwd(address)
			local usersFile = fs.canonical(usersFolder .. "/" ..msg)
			local userGlobalFolder = fs.canonical(ftpFolder .. usersFolder)
			local userGlobalFile  = fs.canonical(userGlobalFolder .. "/" ..msg)	 
			ICore:info("prepare to receive file:"..userGlobalFile)
			if INetFile.receive(INetStream, userGlobalFile) then
			  INet.INetwork:send(address, "FTP_SUCCESSED", "send " .. usersFile .." successed!")
			else
			  INet.INetwork:send(address, "FTP_ERROR", "send " .. usersFile .." fail")
			end			
		end
	end
end

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
	local maxWirelessStrength = 400
	local ibuilder = ICore.IBuilder:setCMDsTop(1):setCMDList(CMDList)	
	local nbuilderClient = INet.NBuilder:setNet(21, ibuilder):setNetRemoteConnectedCallback(onConnected):setServerNet(onClientCommonMsgCome):setWirelessStrength(maxWirelessStrength)
	ICore = INetStream:initialize(nbuilderClient)	
	if not fs.isDirectory(ftpFolder) then
		ICore:info("create folder "..ftpFolder)
		fs.makeDirectory(ftpFolder)	
	end	
	ICore.IThread:create(send_thread, nil, "send_thread")
end

function onConnected(address)
	local addressAlias = INet.simplifyAddress(address)
	local usersFolder = "/"..addressAlias
	local userGlobalFolder = fs.canonical(ftpFolder .. usersFolder)
	users[address] = {
		["pwd"] = usersFolder
	}
	if not fs.isDirectory(userGlobalFolder) then
		ICore:info("create folder "..userGlobalFolder)
		fs.makeDirectory(userGlobalFolder)	
	end
	INet.INetwork:send(address, "FTP_R_PWD", usersFolder)
end

function onClientCommonMsgCome(address, cmd, msg)
	local commandFunc = ServerList[cmd]  
	if commandFunc ~= nil then	  	 	  
	  commandFunc(address, msg)
	end
end

function getUserPwd(address)	
	local user = users[address]
	if not user then
		onConnected(address)
		user = users[address]
	end
	return user.pwd
end

function setUserPwd(address, usersFolder)	
	local user = users[address]
	if not user then
		onConnected(address)
		user = users[address]
	end
	user.pwd = usersFolder
end

function checkUserPwdPermissions(address, usersFolder)
	local addressAlias = INet.simplifyAddress(address)
	local segments = fs.segments(usersFolder)
	ICore:warn("checkUserPwdPermissions,", addressAlias, ",",segments[1])
	return addressAlias == segments[1]
end

main()

