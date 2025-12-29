local print = print
local type = type
local error = error
local ipairs = ipairs
local tonumber = tonumber
local coroutine_resume = coroutine.resume
local coroutine_status = coroutine.status
local table_remove = table.remove
local table_unpack = table.unpack or unpack
local os_clock = os.clock

local scheduler = {tasks = {n = 0}}

local function isInt(number)
    return tonumber(number) and number % 1 == 0
end

local function resume(thread, ...)
    local success, errormsg = coroutine_resume(thread, ...)

    if not success then
        print(errormsg)
        return
    end

    return thread
end


function scheduler.addFloor(level)
    if not isInt(level) then
        return nil, "Level is expected to be an integer"
    end

    if not scheduler.tasks[level] then
        scheduler.tasks[level] = {n = 0}
        scheduler.tasks.n = scheduler.tasks.n + 1
    end

    return scheduler.tasks[level]
end

function scheduler.addTask(thread, level, condition, ...)
    local tasks = scheduler.tasks
    local floor, err = tasks[level] or scheduler.addFloor(level)
    if not floor then
        return nil, err
    end
    
    if type(thread) ~= 'thread' then
        return nil, "Argument #1 ÷xpected thread, got "..type(thread)
    end
    
    if type(condition) ~= "function" then
        return nil, "Argument #3 expected function, got "..type(condition)
    end

    floor[floor.n + 1] = {
        thread = thread,
        createdAt = os_clock(),
        args = {...},
        finished = false,
        condition = condition,
        Index = floor.n + 1
    }
    floor.n = floor.n + 1
    
    return floor[floor.n]
end

function scheduler.removeTask(floor, i)
    if not isInt(i) then
        return false, "Index expected to be an integer"
    end
    
    table_remove(floor, i)
    floor.n = floor.n - 1
end

function scheduler.scheduleTask(thread, level, waitTime, ...)
    return scheduler.addTask(thread, level, function(self)
        self.finished = os_clock() - self.createdAt >= waitTime
        
        return self.finished
    end)
end

local function execTask(scheduledTask, floor)
    if not scheduledTask then
        return false, "Scheduled task is nil"
    end
    
    if not scheduledTask.finished and scheduledTask:condition() then
        local thread = scheduledTask.thread
        
        if coroutine_status(thread) ~= 'dead' then
            resume(scheduledTask.thread, table_unpack(scheduledTask.args))
        end
    end
    
    if scheduledTask.finished then
        scheduler.removeTask(floor, scheduledTask.Index)
    end
    
    return true
end


function scheduler.run(level, i)
    if not isInt(level) then
        return false, "Level is expected to be an integer"
    end

    local tasks = scheduler.tasks
    local floor = tasks[level]

    if not floor then
        return false, "Given level for floor is invalid (no floor found)"
    end

    if i then
        if not isInt(i) then
            return false, "Index expected to be an integer"
        end

        local task = floor[i]

        return execTask(task, floor)
    end

    for _, task in ipairs(floor) do
        if task then
            execTask(task, floor)
        end
    end

    return true
end

scheduler.resume = resume

return scheduler
