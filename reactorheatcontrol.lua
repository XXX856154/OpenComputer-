local component = require("component")
local event = require("event")
local reactor = component.reactor_chamber -- 假设你使用的是 IC2 核电仓
local maxHeat = reactor.getMaxHeat()

local timerId

local function checkReactorHeat()
    local currentHeat = reactor.getHeat()
    if currentHeat >= maxHeat * 0.99 then
        reactor.setActive(false)
        print("Reactor shutdown due to high heat: " .. currentHeat)
        -- 停止定时器并退出主循环
        event.cancel(timerId)
        os.exit()
    elseif currentHeat < maxHeat * 0.99 then
        reactor.setActive(true)
        print("Reactor started: " .. currentHeat)
    end
end

-- 设置一个定时器，每秒检查一次热量
local interval = 1 -- 每1秒检查一次
timerId = event.timer(interval, checkReactorHeat, math.huge)
