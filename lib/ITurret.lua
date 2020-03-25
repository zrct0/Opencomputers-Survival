ITurret = {}
local ICore = require("ICore")
local Vector3 = require("IVector3")
local turret = require("component").os_energyturret



ITurret.fireStack = {}

function ITurret:initialize()	
	ICore:init("turret power On")
	turret.powerOn()
	ICore:init("turret Armed")
	turret.setArmed(true)
	ICore.IThread:create(ITurret.thread, self, "ITurret")
end

function ITurret:fireSync(x, y, z)
	local pos 
	if y and z then
		pos = Vector3:new(x, y, z)
	else
		pos = x
	end
	if pos.x and pos.y and pos.z then
		local angle = ITurret:computeAngle(pos)			
		self:realFire(angle)	
	else
		ICore:error("Bad coor x:", pos.x, ", y:" , pos.y, ", z:" ,pos.z)
	end
end

function ITurret:fireAsyn(x, y, z)
	local pos 
	if y and z then
		pos = Vector3:new(x, y, z)
	else
		pos = x
	end
	if pos.x and pos.y and pos.z then
		local angle = ITurret:computeAngle(pos)			
		table.insert(self.fireStack, angle)
		ICore.IThread:resume("ITurret")	
	else
		ICore:error("Bad coor x:", pos.x, ", y:" , pos.y, ", z:" ,pos.z)
	end
end

function ITurret:thread()
	while true do		
		local angle = table.remove (self.fireStack)
		if angle then
			self:realFire(angle)			
		else
			ICore.IThread:suspend()
		end
	end
end

function ITurret:realFire(angle)		
	turret.moveToRadians(angle.x, angle.y)
	while not turret.isReady() do		
		os.sleep(0.2)
	end		
	turret.fire()		
end

function ITurret:computeAngle(pos)	
	local distance = pos:magnitude()
	local angle1 = ITurret.atan2(pos.x, -pos.y)
	local angle2 = math.asin(pos.z / distance)
	local angle = Vector3:new(angle1, angle2, 0)	
	return angle
end


return ITurret