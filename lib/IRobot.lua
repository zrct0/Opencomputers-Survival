IRobot = {}
Vector3 = require("IVector3")
robot = require("robot")
thread = require("thread")

IRobot.coor = nil
IRobot.direction = nil
IRobot.face = 0
IRobot.nopSwing = nil
IRobot.intercept = false
IRobot.enbleSuspend = false
IRobot.moveCallback = false

IRobot.E = 0
IRobot.S = 1
IRobot.W = 2
IRobot.N = 3


function IRobot:initialize(enbleSuspend, nopSwing, moveCallback)
	self.coor = Vector3.ZERO
	self.direction = Vector3.ZERO
	self.intercept = false	
	self.enbleSuspend = enbleSuspend
	self.nopSwing = nopSwing
	self.moveCallback = moveCallback
end

function IRobot:moveToHome()
	self:moveToZ(0)	
	if math.abs(self.coor.x) > math.abs(self.coor.y) then
		self:moveToX(0)
		self:moveToY(0)
	else					
		self:moveToY(0)
		self:moveToX(0)
	end	
end

function IRobot:moveTo(x, y, z)
	local pos
	if y and z then
		pos = Vector3:new(x, y, z)
	else
		pos = x
	end
	
	if pos.z then
		self:moveToZ(pos.z)
	end
	self:moveToX(pos.x)
	self:moveToY(pos.y)
end

function IRobot:moveToX(x)		
	if x > self.coor.x then
		self.direction = Vector3.FORWARD
		self:turnTo(0)
		self:robotGoto(x - self.coor.x)				
	elseif x < self.coor.x then
		self.direction = Vector3.BACK
		self:turnTo(2)
		self:robotGoto(self.coor.x - x)		
	end		
end

function IRobot:moveToY(y)		
	if y > self.coor.y then
		self.direction = Vector3.RIGHT
		self:turnTo(1)
		self:robotGoto(y - self.coor.y)		
	elseif y < self.coor.y then
		self.direction = Vector3.LEFT
		self:turnTo(3)
		self:robotGoto(self.coor.y - y)		
	end	
end

function IRobot:moveToZ(z)	
	if z > self.coor.z then
		self.direction = Vector3.UP
		self:robotGoto(z - self.coor.z, robot.up, robot.swingUp, robot.detectUp)			
	elseif z < self.coor.z then	
		self.direction = Vector3.DOWN
		self:robotGoto(self.coor.z - z, robot.down, robot.swingDown, robot.detectDown)	
	end	
end

function IRobot:robotGoto(d, actionFunc, swingFunc, detectFunc)
	actionFunc = actionFunc or robot.forward
	swingFunc = swingFunc or robot.swing
	detectFunc = detectFunc or robot.detect
	for m=1, d do			
		self:robotMove(actionFunc, swingFunc, detectFunc)
		display()
		if self.intercept then
			ICore:warn("Intercept [self:robotGoto]")			
			break
		end
	end
end

function IRobot:turnTo(side)	
	if side ~= self.face then
		local t = side - self.face
		local diff = math.abs(t)		
		diff =  diff > 2 and diff - 2 or diff
		if diff > 1 then
			robot.turnAround()
		else
			t = math.abs(t) > 1 and -t or t				
			if t > 0 then
				robot.turnRight()
			else
				robot.turnLeft()		
			end
		end
		self.face = side
	end
end

function IRobot:robotMove(actionFunc, swingFunc, detectFunc)	
	if self.enbleSuspend then
		thread.current():suspend()
	end
	local result = true
	while not actionFunc() do
		local _, detectResult = detectFunc()
		if detectResult ~= self.nopSwing then
			swingFunc()
		else
			detour()
			result = false
			break
		end
		if self.intercept then
			ICore:warn("Intercept [robotMove]")	
			result = false
			break
		end
	end
	if result then
		self.coor = self.coor + self.direction	
	end
	if self.moveCallback then
		self.moveCallback(result)
	end
end

function IRobot:getCoor()
	return IRobot.coor
end



return IRobot