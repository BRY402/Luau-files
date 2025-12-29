if task then
    return task
end

local task = {levels = {}}

local type = type
local error = error
local ipairs = ipairs
local coroutine_create = coroutine.create
local coroutine_yield = coroutine.yield
local coroutine_running = coroutine.running
local coroutine_close = coroutine.close
local os_clock = os.clock

local scheduler = require('./Shared/Scheduler')
local mainThread = coroutine_running()

task.levels.INIT_LVL = 1
task.levels.HEARTBEAT_LVL = 2

scheduler.addFloor(task.levels.INIT_LVL) -- Start of cycle
scheduler.addFloor(task.levels.HEARTBEAT_LVL) -- Heartbeat


-- Task functions
function task.wait(duration)
    if coroutine_running() == mainThread then
        return 0
    end
    
    scheduler.scheduleTask(coroutine_running(), task.levels.HEARTBEAT_LVL, duration)
    local start = os_clock()
    coroutine_yield()
    return os_clock() - start
end

function task.spawn(functionOrThread, ...)
    local thread = type(functionOrThread) == 'function' and coroutine_create(functionOrThread) or functionOrThread

    if type(thread) ~= 'thread' then
        print("Expected thread, got "..type(thread))
    end

    return scheduler.resume(thread, ...)
end

function task.defer(functionOrThread, ...)
    local thread = type(functionOrThread) == 'function' and coroutine_create(functionOrThread) or functionOrThread

    if type(thread) ~= 'thread' then
        print("Expected thread, got "..type(thread))
    end

    scheduler.scheduleTask(thread, task.levels.HEARTBEAT_LVL, 0, ...)

    return thread
end

function task.delay(duration, functionOrThread, ...)
    local thread = type(functionOrThread) == 'function' and coroutine_create(functionOrThread) or functionOrThread

    if type(thread) ~= 'thread' then
        return print("Expected thread, got "..type(thread))
    end

    scheduler.scheduleTask(thread, task.levels.HEARTBEAT_LVL, duration, ...)

    return thread
end

function task.cancel(thread)
    coroutine_close(thread)
end

function task.run(functionOrThread)
    if functionOrThread then -- Just in case
        return task.spawn(functionOrThread)
    end
    while true do -- Make sure all tasks scheduled for execution are finished
        local finishedfloors = 0
        for i, floor in ipairs(scheduler.tasks) do
            if floor.n <= 0 then
                finishedfloors = finishedfloors + 1
            else
                finishedfloors = finishedfloors - 1
                scheduler.run(i)
            end
        end
        if finishedfloors >= scheduler.tasks.n then
            break
        end
    end

    return true
end

task.scheduler = scheduler

return task
