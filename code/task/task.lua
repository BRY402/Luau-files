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