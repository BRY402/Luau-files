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