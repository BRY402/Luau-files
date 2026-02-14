local coroutine = coroutine
local sb_package = {preload = {}}
local print = print

local require = (function(_ENV)
    local unpack = unpack or table.unpack
    local loaded = {}
    sb_package.loaded = setmetatable({}, {__index = loaded})

    return function(modname, args)
        local res = loaded[modname]
        if res then
            return res
        end

        local mod = sb_package.preload[modname]
        if mod then
            local args = type(args) == "table" and args or {args}
            loaded[modname] = mod(setmetatable({}, {__index = _ENV}), modname, unpack(args))
        else
            loaded[modname] = require(modname) --!
        end

        return loaded[modname]
    end
end)(_ENV or getfenv())

local NLS = NLS or function()
    print("NLS is not supported in this script builder")
end

sb_package.preload["./Scheduler"] = function(_ENV, ...)
        local function mod(_ENV, ...)
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_status = coroutine.status
local ipairs = ipairs
local print = print
local table_remove = table.remove
local type = type
local unpack = unpack or table.unpack

local function resume(thread, ...)
    local result = {coroutine_resume(thread, ...)}
    if not result[1] then
        print(result[2])
    end
    
    return unpack(result)
end

local threadObj = {
    ClassName = "thread",
    floor = nil,
    ref = nil, -- main thread
    id = 0,
    quota = function(self, task)
        self.quota = type(task) == "function" and task or self.quota
        return true
    end,
    finished = false,
    args = nil
}

local Scheduler = {floors = {}}

function Scheduler.createFloor(level)
    local floor = {n = 0}
    Scheduler.floors[level] = floor
    
    return floor
end

function Scheduler.createThread(task, floor)
    if type(task) == "table" and task.ClassName == "thread" then
        return task
    end
    
    local thread = setmetatable({}, {__index = threadObj})
    thread.ref = type(task) == "thread" and task or coroutine_create(task)
    thread.id = #floor + 1
    floor[thread.id] = thread
    thread.floor = floor
    
    local n = floor.n
    floor.n = thread.id > n and (n + (thread.id - n)) or n
    
    return thread
end

function Scheduler.removeThread(thread)
    if not thread.floor then
        return
    end
    
    local n = thread.floor.n
    thread.floor.n = n <= thread.id and (n - (thread.id - n + 1)) or n
    thread.floor[thread.id] = nil
    thread.floor = nil
end

function Scheduler.resume(thread, ...)
    if not thread then
        return
    end
    
    if not thread:quota() then
        return false, "thread self-assigned quota not reached", 1
    end
    
    local isDead = coroutine_status(thread.ref) == "dead"
    local isSuspended = coroutine_status(thread.ref) == "suspended"
    thread.finished = isDead or thread.finished
    
    if isSuspended then
        local args = thread.args or {...}
        return resume(thread.ref, unpack(args)), 0
    end
    
    if thread.finished then
        Scheduler.removeThread(thread)
    end
end

function Scheduler.run(...)
    for _, floor in ipairs(Scheduler.floors) do
        for i = 1, floor.n do
            Scheduler.resume(floor[i], ...)
        end
    end
end

return Scheduler
    end
    
    local thread = coroutine.create(setfenv and setfenv(mod, _ENV) or mod)
    local success, result = coroutine.resume(thread, _ENV, ...)

    if not success then
        print(result)
        return
    end

    return result
end

local coroutine_close = coroutine.close
local coroutine_running = coroutine.running
local coroutine_yield = coroutine.yield
local mainThread = coroutine_running()
local os_clock = os.clock
local tonumber = tonumber
local Scheduler = require("./Scheduler") --$*

local HEARTBEAT = Scheduler.createFloor(1)
local function patientThread(threadTask, waitTime)
    local waitTime = tonumber(waitTime) or 0
    local thread = Scheduler.createThread(threadTask, HEARTBEAT)
    local createdAt = os_clock()
    
    thread.quota = function(self)
        self.finished = (os_clock() - createdAt) > waitTime
        return self.finished
    end
    
    return thread
end

local task = {}

function task.spawn(functionOrThread, ...)
    local thread = Scheduler.createThread(functionOrThread, HEARTBEAT)
    Scheduler.resume(thread, ...)
    
    return thread.ref
end

function task.defer(functionOrThread, ...)
    local thread = Scheduler.createThread(functionOrThread, HEARTBEAT)
    thread.args = {...}
    
    return thread.ref
end

function task.delay(duration, functionOrThread, ...)
    local thread = patientThread(functionOrThread, duration)
    thread.args = {...}
    
    return thread.ref
end

function task.wait(duration)
    local duration = tonumber(duration) or 0
    local begin = os_clock()
    if coroutine_running() == mainThread then
        repeat until (os_clock() - begin) > duration
        return os_clock() - begin
    end
    
    patientThread(coroutine_running(), duration)
    coroutine_yield()
    return os_clock() - begin
end

function task.cancel(thread)
    if type(thread) == "table" and thread.ClassName == "thread" then
        thread.finished = true
        thread = thread.ref
    end
    
    if coroutine_close then
        coroutine_close(thread)
    end
    
    return
end

task.run = Scheduler.run

return task