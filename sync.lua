local fs = require("filesystem")
local shell = require("shell")

function main()
	local from = os.getenv("PWD")
	local to = "/home"
	copy(from, to)
end

local nopCopyList = {".shrc", "sync.lua", "build.lua"}

function copy(from, to)
	if fs.isDirectory(from) then
		if not fs.isDirectory(to) then
			fs.makeDirectory(to)
		end
		local list = fs.list(from)
		for v in list do
			if not isTableContain(nopCopyList, v) then
				local from_path = fs.canonical(from.."/"..v)
				local to_path = fs.canonical(to.."/"..v)
				copy(from_path, to_path)				
			end
		end
	else					
		local result, reson = fs.copy(from, to)		
		if result then
			print("\""..from.."\"->\""..to.."\"")	
		else
			print(reson)
		end
	end
end

function isTableContain(tab, element)
  for _, value in pairs(tab) do
    if string.find(element, value) then
      return true
    end
  end
  return false
end

main()