local fs = require("filesystem")
local shell = require("shell")
local computer = require("computer")
local args = {...}
local self_proxy = args[1]

local rundisk = 
[[
local fs = require("filesystem")
local shell = require("shell")
for proxy, path in fs.mounts() do
	if string.find(path, "/mnt/") and proxy.address ~= require("computer").getBootAddress() then
		local homePath = path .. "/home/"
		if fs.isDirectory(homePath) then
			shell.setWorkingDirectory(homePath)			
			local addpath = "./lib/?.lua;"
			if not string.find(package.path, addpath) then
				package.path = addpath..package.path
			end
			local home_shrc = homePath..".shrc"			
			if fs.exists(home_shrc) then			 
			    local file = io.open(home_shrc, "r")				
				for line in file:lines() do				
					shell.execute(line)
				end
			end
		end
	end
end

]]

for proxy, path in fs.mounts() do	
	if proxy.address == self_proxy.address then
		local homePath = path .. "/home/"
		if not fs.isDirectory(homePath) then
			fs.makeDirectory(homePath)
		end
		local rundiskPath = "/rundisk.lua"
		if not fs.exists(rundiskPath) then
			print("install rundisk.lua")
			local file = io.open(rundiskPath, "w")			
			file:write(rundisk)
			file:close()		
			file = io.open("/home/.shrc", "a")				
			file:write("/rundisk.lua\n")
			file:close()	
			computer.shutdown(true)
		end
	end
end



