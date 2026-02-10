local task = require('./TaskScheduler')

local format = string.format
local coroutine_status = coroutine.status

local function test(testn)
    local n = 0
    for i = 1, 10 do
        n = n + i
        task.wait()
    end
    print(n)
    if n ~= 55 then
        print(format('Test%i failed', testn))
        return
    end
    print(format('Test%i passed', testn))
end

print('Running tests')
task.spawn(test, 1)

task.defer(test, 2)

task.delay(1/60, test, 3)

local thread = task.spawn(function()
    while true do
        task.wait()
    end
end)

task.cancel(thread)

if coroutine_status(thread) ~= 'dead' then
    print('Test4 failed')
else
    print('Test4 passed')
end

task.wait(2)

while true do
    task.run()
end