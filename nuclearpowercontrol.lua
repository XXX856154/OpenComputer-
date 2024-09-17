local thread = require("thread")
local component = require("component")
local redControl = require("redControl")
local reactorControl = require("reactorControl")
local chest = require("chestControl")
local config = require("reactorConfig")
local sides = require("sides")

local direction = config.direction
local mode = config.mode
local rconfig = config.rconfig
local heliumCoolantcell = config.heliumCoolantcell
local uraniumQuadrupleFuel = config.uraniumQuadrupleFuel

-- 获取所有转运器组件
local transposers = {}
for address, _ in component.list("transposer") do
    table.insert(transposers, component.proxy(address))
end

-- 全局变量
local coolingNeeded = false
local stopSignal = false
local running = true
local threads = {}
local reactorLocks = {}
local heCheckInterval = 60  -- 基础冷却单元检查间隔（秒）
local uranCheckInterval = 21600  -- 基础燃料棒检查间隔（秒）

-- 为每个核电仓创建独立的锁
for id, _ in ipairs(transposers) do
    reactorLocks[id] = {
        heLock = false,
        fuelLock = false,
        heLockThread = nil,
        fuelLockThread = nil,
        lastHeCheckTime = os.time(),
        lastUranCheckTime = os.time(),
        heCheckFrequency = heCheckInterval,
        uranCheckFrequency = uranCheckInterval
    }
end

local function updateCheckFrequency(id)
    local lock = reactorLocks[id]
    local elapsedHeTime = os.time() - lock.lastHeCheckTime
    local elapsedUranTime = os.time() - lock.lastUranCheckTime

    -- 动态调整冷却单元检查频率
    local heDamageRatio = (heliumCoolantcell.damage - 1) / heliumCoolantcell.damage
    local heLossRate = (1 - heDamageRatio) * 100
    lock.heCheckFrequency = heCheckInterval / (1 + heLossRate * 0.1)

    -- 动态调整燃料棒检查频率
    local uranDamageRatio = (uraniumQuadrupleFuel.damage - 1) / uraniumQuadrupleFuel.damage
    local uranLossRate = (1 - uranDamageRatio) * 100
    lock.uranCheckFrequency = uranCheckInterval / (1 + uranLossRate * 0.1)
end

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
    local lock = reactorLocks[id]
    local currentTime = os.time()
    local elapsedTime = currentTime - lock.lastHeCheckTime

    if elapsedTime < lock.heCheckFrequency then
        return
    end

    lock.lastHeCheckTime = currentTime
    print("核电仓 " .. id .. " 正在操作: 检查冷却单元")

    local hePull = reactorControl.checkReactorDamage(transposer, direction["reactor"])
    if hePull then
        print("核电仓 " .. id .. " 检测到受损的冷却单元")
        redControl.stop(direction["reactor"])

        if lock.heLock then
            print("核电仓 " .. id .. " 当前存在冷却单元更换中")
            return
        end
        lock.heLock = true

        if lock.heLockThread then
            lock.heLockThread:join()
        end
        lock.heLockThread = thread.create(function()
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
            lock.heLock = false
            print("核电仓 " .. id .. " 冷却单元更换完成")
        end)
        lock.heLockThread:detach()
    end
end

local function checkUran(transposer, id)
    local lock = reactorLocks[id]
    local currentTime = os.time()
    local elapsedTime = currentTime - lock.lastUranCheckTime

    if elapsedTime < lock.uranCheckFrequency then
        return
    end

    lock.lastUranCheckTime = currentTime
    print("核电仓 " .. id .. " 正在操作: 检查燃料棒")

    local uranPull = reactorControl.checkReactorFuelDrained(transposer, direction["reactor"])
    if uranPull then
        print("核电仓 " .. id .. " 检测到燃料棒枯竭")
        redControl.stop(direction["reactor"])

        if lock.fuelLock then
            print("核电仓 " .. id .. " 当前存在燃料更换中")
            return
        end
        lock.fuelLock = true

        if lock.fuelLockThread then
            lock.fuelLockThread:join()
        end
        lock.fuelLockThread = thread.create(function()
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
            lock.fuelLock = false
        end)
        lock.fuelLockThread:detach()
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
        print("接收到停机信号，核电仓 " .. id .. " 停止运行")
        redControl.stop(direction["reactor"])
        return
    end

    -- 初始化反应堆
    local isReady = initializeReactor(transposer, id)
    if not isReady then
        print("核电仓 " .. id .. " 初始化失败")
        return
    end

    -- 启动反应堆
    local outSide = component.redstone.getInput(direction["outSideRed"])
    if mode.gtBattery then
        gtBatteryStart(outSide, isReady, transposer, id)
    elseif mode.gtMachine then
        machineStart(outSide, isReady, transposer, id)
    end

    -- 进行检查
    updateCheckFrequency(id)
    checkHe(transposer, id)
    checkUran(transposer, id)
end

-- 批处理模式管理
local function batchProcess()
    while running do
        local threshold = config.heliumCoolantcell.damage-- 设置冷却单元和燃料棒的阈值百分比
        local batchMode = false

        -- 检查所有核电仓的冷却单元和燃料棒状态
        for id, transposer in ipairs(transposers) do
            local lock = reactorLocks[id]
            local heDamageRatio = (heliumCoolantcell.damage - 1) / heliumCoolantcell.damage
            local uranDamageRatio = (uraniumQuadrupleFuel.damage - 1) / uraniumQuadrupleFuel.damage
            
            -- 判断是否进入批处理模式
            if heDamageRatio >= threshold or uranDamageRatio >= threshold then
                batchMode = true
                break
            end
        end

        if batchMode then
            print("批处理模式激活")
            -- 关机，执行批处理
            for id, _ in ipairs(transposers) do
                redControl.stop(direction["reactor"])
            end
            
            -- 执行批处理操作
            for id, transposer in ipairs(transposers) do
                controlReactor(transposer, id)
            end

            -- 重新开机
            for id, _ in ipairs(transposers) do
                redControl.start(direction["reactor"])
            end
        else
            -- 单独处理每个核电仓
            for id, transposer in ipairs(transposers) do
                controlReactor(transposer, id)
            end
        end

        -- 定时休息，避免高频率的操作
        os.sleep(10)
    end
end

-- 启动批处理线程
local function startBatchProcessing()
    local batchThread = thread.create(batchProcess)
    batchThread:detach()
end

-- 主程序入口
local function main()
    print("系统启动中...")
    startBatchProcessing()
end

-- 执行主程序
main()
