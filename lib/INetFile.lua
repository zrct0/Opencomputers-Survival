local INetFile = {}

local fs = require("filesystem")

function INetFile.send(INetStream, address, filePath)   
  local buffer = INetStream.INetOutputStream(address)  
	local file, r = io.open(filePath, "r")	
	if not file then
		return false, r
	end
	for line in file:lines() do
		buffer:write(line.."\n")
	end
	file:close()	
	buffer:close()	
	return true
end

function INetFile.receive(INetStream, filePath)
	local successed = false
	local reason = "timeout"
	local buffer = INetStream.INetInputStream()	
	file = io.open(filePath, "w")	
	if file then		
		for line in buffer:lines() do				
			if line then
				successed = true		
				file:write(line.."\n")	
			end
		end
		file:close()
	else
		reason = "fail to open "..filePath
	end	
	if not successed then
		if fs.exists(filePath) then
			fs.remove(filePath)
		end
	end
	return successed, reason
end


return INetFile

