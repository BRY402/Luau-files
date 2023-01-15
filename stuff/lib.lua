local deb = game:GetService("Debris")
local rs = game:GetService("RunService")
local clonable = Instance.new("Script")
local nilinstances = {}
local cache = {}
clonable.Disabled = true
local function extraEnv(func)
    local env = getfenv(func)
    setfenv(func,setmetatable({thisFunction = func},{__index = function(self,i)
            return env[i]
        end,
        __newindex = function(self,i,v)
            rawset(self,i,v)
        end}))
    return func
end
local function range(min,max,func)
	for i = min,max do
		local yield = i % 10 == 0
		extraEnv(func)(i,yield)
		if yield then
			task.wait()
		end
	end
end
local function read(list,func)
	for i,v in pairs(list) do
		local yield = i % 10 == 0
		extraEnv(func)(i,v,yield)
		if yield then
			task.wait()	
		end
	end
end
local function forever(func)
	local number = {0}
	while true do
		local n = number[1]
		number[1] = n + 1
		local yield = n % 10 == 0
		extraEnv(func)(n,yield)
		if yield then
			task.wait()
		end
	end
end
local function isnilparent(target)
	target:GetPropertyChangedSignal("Parent"):Connect(function()
		if target.Parent == nil then
			table.insert(nilinstances,target)
		else
			table.remove(nilinstances,table.find(nilinstances,target))
		end
	end)
end
local function setproperty(target, index, value)
	if tonumber(index) then
		value.Parent = target
		isnilparent(value)
	else
		target[index] = value
	end
end
local function setproperties(Properties, inst)
	if Properties then
		local selfFunc = Properties.__self
		if selfFunc then
			Properties.__self = nil
			assert(typeof(selfFunc) == "function","__self index is expected to be a function")
			task.spawn(function()
				local env = setmetatable({self = Properties,
					Parent = Parent},{__index = function(self,i)
						return rawget(self,i) or getfenv()[i]
					end,
					__newindex = function(self,i,v)
						rawset(self,i,v)
					end})
				setfenv(selfFunc,env)(inst)
			end)
		end
		if Properties.CanPropertyYield then
			Properties.CanPropertyYield = nil
			read(Properties,function(i,v)
				setproperty(inst,i,v)
			end)
		else
			table.foreach(Properties,function(i,v)
				setproperty(inst,i,v)
			end)
		end
	end
end
local lib = {newEvent = function(eventName, callerName, methodOrFunction)
    local methodOrFunction = methodOrFunction and methodOrFunction or "Method"
    local Connections = {}
    local returned = {[eventName] = {}}
    returned[callerName] = extraEnv(function(self,...)
        if methodOrFunction == "Method" then
            local args = table.pack(...)
            args.n = nil
            read(Connections,function(i,Connection)
                Connection:Call(unpack(args))
		if Connection.Type == "Once" then
			table.remove(Connections,Connection)
		end
            end)
        else
            local args = table.pack(self,...)
            args.n = nil
            read(Connections,function(i,Connection)
                Connection:Call(unpack(args))
		if Connection.Type == "Once" then
			table.remove(Connections,Connection)
		end
            end)
        end
    end)
    local event = returned[eventName]
    function event:Connect(func)
		local calledConnection = {Type = "Connect"}
		function calledConnection:Call(...)
			task.spawn(func,...)
		end
        table.insert(Connections,calledConnection)
        local Connection = {}
        function Connection:Disconnect()
            assert(table.find(Connections,func),"Connection was already disconnected")
            table.remove(Connections,func)
        end
        Connection.disconnect = Connection.Disconnect
        return Connection
    end
	function event:ConnectParallel(...)
		assert(script:GetActor(),"Script must have an actor")
		task.desynchronize()
		task.spawn(func,...)
	end
	function event:Once(func)
		local calledConnection = {Type = "Once"}
		function calledConnection:Call(...)
			task.spawn(func,...)
		end
        table.insert(Connections,calledConnection)
        local Connection = {Connected = true}
        function Connection:Disconnect()
            assert(table.find(Connections,func),"Connection was already disconnected")
			Connection.Connected = false
            table.remove(Connections,func)
        end
        Connection.disconnect = Connection.Disconnect
        return Connection
	end
    event.connect = event.Connect
	event.connectparallel = event.ConnectParallel
	event.once = event.Once
    return returned
end,
	Create = function(Class, Parent, Properties)
		local ri
		local cci = cache[Class]
		if not cci then
			local inst = Instance.new(Class)
			cache[Class] = inst
			inst.Archivable = true
			ri = clonable.Clone(inst)
		else
			cci.Archivable = true
			ri = clonable.Clone(cci)
		end
		if ri ~= nil then
			if Properties and Properties ~= true then
				setproperties(Properties,ri)
			elseif Properties == true then
				return function(Properties)
					setproperties(Properties,ri)
					ri.Parent = Parent
					isnilparent(ri)
					return ri
				end
			end
			ri.Parent = Parent
			isnilparent(ri)
		end
		return ri
	end,
	Random = function(min, max, seed)
		local nrs = Random.new(seed or os.clock())
		if min and max then
			int = nrs:NextInteger(min,max)
			num = nrs:NextNumber(min,max)
		else
			int = 0
			num = nrs:NextNumber()
		end
		local unit = nrs:NextUnitVector()
		local rt = {Unit = unit,Integer = int,Number = num,Generator = nrs}
		return rt
	end,
	Destroy = function(ins,delay)
		deb:AddItem(ins,tonumber(delay) or 0)
	end,
	GetNil = function()
		return nilinstances
	end,
	Clone = function(inst)
		if inst then
			local arch = inst.Archivable
			inst.Archivable = true
			local ninst = clonable.Clone(inst)
			inst.Archivable = arch
			return ninst
		end
	end,
	Loops = {range = range,
		read = read,
		forever = forever}}
local remote = lib.Create("BindableEvent")
lib.fastSpawn = function(func, ...)
	remote.Event:Once(func)
	remote:Fire(...)
end
return lib
