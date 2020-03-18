IVector3 = {}

IVector3.x = 0
IVector3.y = 0
IVector3.z = 0
IVector3.vtable = {0, 0, 0}


--根据x,y,z创建向量
function IVector3:new(x,y,z)
	local t = {}
	setmetatable(t, self)
	self.__index = self
	t:initialize(x,y,z)
	return t
end

function IVector3:initialize(x,y,z)
	self.x = x
	self.y = y
	self.z = z  
	self.vtable = {x, y, z, 1}
end

--向量相加
function IVector3:__add(v)
	return IVector3:new(self.x + v.x, self.y + v.y, self.z + v.z)
end

--向量相减
function IVector3:__sub(v)
	return IVector3:new(self.x - v.x, self.y - v.y, self.z - v.z)
end

--向量相乘
function IVector3:__mul(v)
	if type(v) == "number" then
		return IVector3:new(self.x * v, self.y * v, self.z * v)
	end
	return IVector3:new(self.x * v.x, self.y * v.y, self.z * v.z)
end

--向量相除
function IVector3:__div(v)
	if type(v) == "number" then
		return IVector3:new(self.x / v, self.y / v, self.z / v)	
	end
	return IVector3:new(self.x / v.x, self.y / v.y, self.z / v.z)
end

--向量的绝对值
function IVector3:abs()	
	return IVector3:new(math.abs(self.x), math.abs(self.y), math.abs(self.z))
end

--四舍五入取整数
function IVector3:roundInt()	
	return IVector3:new(math.floor(self.x + 0.5), math.floor(self.y + 0.5), math.floor(self.z + 0.5))
end

--向量的比较
function IVector3:__eq(v)	
	return v and self.x == v.x and self.y == v.y and self.z == v.z
end

--求插值
--t为间隔
--返回从 from 到 to的连接线上的一系列值（存在表中）
--公式 from + (to - from)
function IVector3:lerp(from, to, t)
	local vs = {}
	local dv = to:sub(from)		
	local interval = math.floor(from:distance(to) / t)	
	local iv = dv:div(interval)	
	local lastNv = nil	
	for i=0, interval do
		local nv = from:add(iv:mul(i)):roundInt()
		if not (nv == lastNv) then			
			table.insert(vs, nv)			
		end
		lastNv = nv
	end
	return vs
end

--两点之间的距离
function IVector3:distance(v)
	local dx2 = math.pow(self.x - v.x, 2)
	local dy2 = math.pow(self.y - v.y, 2)
	local dz2 = math.pow(self.z - v.z, 2)	
	return math.sqrt(dx2 + dy2 + dz2)
end  

--向量的长度
function IVector3:magnitude()
	local dx2 = math.pow(self.x, 2)
	local dy2 = math.pow(self.y, 2)
	local dz2 = math.pow(self.z, 2)	
	return math.sqrt(dx2 + dy2 + dz2)
end

--两点之间的距离
function IVector3:distance(v)
	local dx2 = math.pow(self.x - v.x, 2)
	local dy2 = math.pow(self.y - v.y, 2)
	local dz2 = math.pow(self.z - v.z, 2)	
	return math.sqrt(dx2 + dy2 + dz2)
end  

function IVector3:get(i)
	return self.vtable[i]
end

function IVector3:__tostring()
	return "("..self.x..","..self.y..","..self.z..")"
end 

IVector3.ZERO = IVector3:new(0, 0, 0)
IVector3.UP = IVector3:new(0, 0, 1)
IVector3.DOWN = IVector3:new(0, 0, -1)
IVector3.FORWARD = IVector3:new(1, 0, 0)
IVector3.BACK = IVector3:new(-1, 0, 0)
IVector3.RIGHT = IVector3:new(0, 1, 0)
IVector3.LEFT = IVector3:new(0, -1, 0)

return IVector3