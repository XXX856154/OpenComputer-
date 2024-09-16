local thread = require("thread")
local component = require("component")
local redControl = require("redControl")
local reactorControl = require("reactorControl")
local config = require("reactorConfig")
local chest = require("chestControl")

local direction = config.direction
local mode = config.mode

-- 获取所有转运器组件
local transposers = {}
for address, _ in component.list("transposer") do
    table.insert(transposers, component.proxy(address))
end

-- 全局变量
local coolingNeeded = false
local stopSignal = false
local heLock = false
local fuelLock = false
local running = true
local threads = {}

local function start(outSide, isReady, transposer, id)
    print("核电仓 " .. id .. " 正在操作: 启动或停止反应堆")
    if coolingNeeded then
        print("核电仓 " .. id .. " 停止中，因有冷却单元需要更换")
        redControl.stop(direction["reactor"])
        return
    end

    if outSide ~= 0 and isReady then
        print("核电仓 " .. id .. " 启动中")
        redControl.start(direction["reactor"])
    elseif outSide == 0 then
        print("核电仓 " .. id .. " 接受到外部信号，关闭核电仓")
        redControl.stop(direction["reactor"])
        stopSignal = true
        os.exit()
    else
        print("核电仓 " .. id .. " 不满足配置，无法启动")
        redControl.stop(direction["reactor"])
        
    end
end

local function gtBatteryStart(outSide, isReady, transposer, id)
    start(outSide, isReady, transposer, id)
end

local function machineStart(outSide, isReady, transposer, id)
    start(outSide, isReady, transposer, id)
end

local function checkHe(transposer, id)
    print("核电仓 " .. id .. " 正在操作: 检查冷却单元")
    local hePull = reactorControl.checkReactorDamage(transposer, direction["reactor"])
    if hePull then
        print("核电仓 " .. id .. " 检测到受损的冷却单元")
        coolingNeeded = true
        redControl.stop(direction["reactor"])

        while heLock do
            print("核电仓 " .. id .. " 在更换冷却单元时发现当前存在核电仓更换冷却单元中")
            os.sleep(1)
        end
        heLock = true

        local heSlot = chest.checkHeSlotIsEnough(transposer, direction["heChest"], hePull)
        while not heSlot do
            print("核电仓 " .. id .. " 箱子槽位不足，请取出物品")
            heSlot = chest.checkHeSlotIsEnough(transposer, direction["heChest"], hePull)
            os.sleep(3)
        end

        reactorControl.pullUranAndHe(transposer, hePull, nil, direction["reactor"], direction["drainedUranChest"], direction["heChest"], heSlot, nil)
        local he = chest.checkHasReplace(transposer, hePull, nil)[1]
        while not he do
            print("核电仓 " .. id .. " 冷却单元不足，请补充")
            he = chest.checkHasReplace(transposer, hePull, nil)[1]
            os.sleep(3)
        end

        reactorControl.putFuelAndHe(transposer, hePull, nil, direction["heChest"], direction["uranChest"], direction["reactor"], he, nil)
        coolingNeeded = false
        heLock = false
        print("核电仓 " .. id .. " 冷却单元更换完成")
    end
end

local function checkUran(transposer, id)
    print("核电仓 " .. id .. " 正在操作: 检查燃料棒")
    local uranPull = reactorControl.checkReactorFuelDrained(transposer, direction["reactor"])
    if uranPull then
        print("核电仓 " .. id .. " 检测到燃料棒枯竭")
        redControl.stop(direction["reactor"])

        while fuelLock do
            print("核电仓 " .. id .. " 在更换燃料时发现当前存在核电仓更换燃料中")
            os.sleep(1)
        end
        fuelLock = true

        local uranSlot = chest.checkUranSlotIsEnough(transposer, direction["drainedUranChest"], uranPull)
        while not uranSlot do
            print("核电仓 " .. id .. " 箱子槽位不足，请取出物品")
            uranSlot = chest.checkUranSlotIsEnough(transposer, direction["drainedUranChest"], uranPull)
            os.sleep(3)
        end

        reactorControl.pullUranAndHe(transposer, nil, uranPull, direction["reactor"], direction["drainedUranChest"], direction["heChest"], nil, uranSlot)
        local uran = chest.checkHasReplace(transposer, nil, uranPull)[2]
        while not uran do
            print("核电仓 " .. id .. " 燃料不足，请补充")
            uran = chest.checkHasReplace(transposer, nil, uranPull)[2]
            os.sleep(3)
        end

        reactorControl.putFuelAndHe(transposer, nil, uranPull, direction["heChest"], direction["uranChest"], direction["reactor"], nil, uran)
        fuelLock = false
    end
end

local function initializeReactor(transposer, id)
    print("核电仓 " .. id .. " 正在操作: 初始化反应堆")
    local isReady = reactorControl.checkReactor(transposer, direction["reactor"])
    if not isReady then
        local returnTable = reactorControl.firstPut(transposer, direction["heChest"], direction["uranChest"], direction["reactor"])
        if not returnTable[1] then
            print("核电仓 " .. id .. " 无法启动，需要配置足数的冷却单元")
            return false
        end
        if not returnTable[2] then
            print("核电仓 " .. id .. " 无法启动，需要配置足数的燃料")
            return false
        end
    end
    return true
end

local function controlReactor(transposer, id)
    print("核电仓 " .. id .. " 正在操作: 控制反应堆")

    if stopSignal then
        print("核电仓 " .. id .. " 接受到外部信号，关闭所有线程")
        return
    end

    local isReady = reactorControl.checkReactor(transposer, direction["reactor"])
    local outSide = redControl.getOutSide(direction["outSideRed"])

    if mode.gtBattery == 1 then
        gtBatteryStart(outSide, isReady, transposer, id)
    elseif mode.gtMachine == 1 then
        machineStart(outSide, isReady, transposer, id)
    else
        start(outSide, isReady, transposer, id)
    end
end

-- 主线程负责输出电量和时间
local function mainThread()
    local startTime = os.time()
    while running do
        if stopSignal then
            print("接收到外部信号，关闭主线程")
            running = false
            return
        end
        local executionTime = os.time()
        local totalTime = executionTime - startTime
        print("系统已运行时间: " .. config.minecraftToRealTime(totalTime))

        local gtBatteryMaxEU, gtStoredEU, gtMachineMaxEU, gtStoredEU
        if mode.gtBattery == 1 then
            local gtBattery = component.gt_batterybuffer
            gtBatteryMaxEU = gtBattery.getMaxBatteryCharge(1) * mode.batterySize + gtBattery.getEUCapacity()
            gtStoredEU = gtBattery.getBatteryCharge(1) * mode.batterySize + gtBattery.getEUStored()
        elseif mode.gtMachine == 1 then
            local gtMachine = component.gt_machine
            gtMachineMaxEU = gtMachine.getEUMaxStored()
            gtStoredEU = gtMachine.getEUStored()
        end

        for id, transposer in ipairs(transposers) do
            if mode.gtBattery == 1 then
                print("核电仓 " .. id .. " 可存储电量为: " .. gtBatteryMaxEU)
                print(string.format("核电仓 " .. id .. " 当前电量: %.2f%%", gtStoredEU / gtBatteryMaxEU * 100))
            elseif mode.gtMachine == 1 then
                print("核电仓 " .. id .. " 可存储电量为: " .. gtMachineMaxEU)
                print(string.format("核电仓 " .. id .. " 当前电量: %.2f%%", gtStoredEU / gtMachineMaxEU * 100))
            end
        end

        os.sleep(1)
    end
end

-- 为每个转运器创建并启动一个线程
for id, transposer in ipairs(transposers) do
    if initializeReactor(transposer, id) then
        local controlThread = thread.create(function()
            while running do
                if stopSignal then
                    print("核电仓 " .. id .. " 接收到外部信号，关闭线程")
                    return
                end

                checkHe(transposer, id)
                checkUran(transposer, id)

                local outSide = redControl.getOutSide(direction["outSideRed"])
                if outSide == 0 then
                    stopSignal = true
                    print("核电仓 " .. id .. " 接收到外部红石信号，关闭所有线程并退出程序")
                    redControl.stop(direction["reactor"])
                    running = false
                    return
                end

                controlReactor(transposer, id)
                os.sleep(0.1)  -- 确保线程让出控制权
            end
        end)

        controlThread:detach()
        table.insert(threads, controlThread)
    end
end

-- 启动主线程
local mainThreadInstance = thread.create(mainThread)
mainThreadInstance:detach()
table.insert(threads, mainThreadInstance)

-- 等待所有线程结束
for _, t in ipairs(threads) do
    t:join()
end

print("所有线程已停止")

