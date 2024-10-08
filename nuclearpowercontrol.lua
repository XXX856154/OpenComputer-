local thread = require("thread")
local component = require("component")
local redControl = require("redControl")
local reactorControl = require("reactorControl")
local chest = require("chestControl")
local config = require("reactorConfig")
local sides = require("sides")
local Log = require("Log")
local direction = config.direction
local mode = config.mode
local rconfig = config.rconfig
local heliumCoolantcell = config.heliumCoolantcell
local uraniumQuadrupleFuel = config.uraniumQuadrupleFuel
local startTime=os.time();
local batchProcessId;
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
local heCheckInterval = 50  -- 基础冷却单元检查间隔
local uranCheckInterval = 7200-- 基础燃料棒检查间隔
local gtBattery={};
local gtMachine={};
local timeoutThread = nil  -- 用于保存超时线程的全局变量
local lockTimeout = 1200   -- 超时时间
local delayTime = 0 --延迟持有锁时长
--local logFile = "./nuclear_reactor_log.txt"

-- 为每个核电仓创建独立的锁
for id, transposer in ipairs(transposers) do
    reactorLocks[id] = {
        heLock = false,
        fuelLock = false,
        heLockThread = nil,
        fuelLockThread = nil,
        lastHeCheckTime = os.time(),
        lastUranCheckTime = os.time(),
        heCheckFrequency = heCheckInterval,
        uranCheckFrequency = uranCheckInterval,
        state = "OK",
        transposer = transposer , -- 使用当前循环中的 transposer
        isReady=false;
    }
end
local  storedEU=0;
local maxEU=0;
if mode.gtBattery==1 then 
  gtBattery=component.gt_batterybuffer;
   storedEU=gtBattery.getBatteryCharge(1) * mode.batterySize + gtBattery.getEUStored()
   maxEU = gtBattery.getMaxBatteryCharge(1) * mode.batterySize + gtBattery.getEUCapacity()
elseif mode.gtMachine==1  then
 
 gtMachine=component.gt_machine;
  storedEU = gtMachine.getEUStored()
   maxEU = gtMachine.getEUCapacity()

 end
-- 自定义锁实现
local Lock = {}--状态锁
Lock.__index = Lock



local function log(message)
    local file = io.open("reactor_log.txt", "a")
    file:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. message .. "\n")
    file:close()
end
function Lock.new()
    local self = setmetatable({}, Lock)
    self.locked = false
    return self
end
-- 修改 Lock 类，增加日志记录
function Lock:acquire(timeout)
    local startTime = os.time()
    while self.locked do
        if timeout and os.time() - startTime > timeout then
           -- log("错误: 锁获取超时")
            return false
        end
        os.sleep(0.1)
    end
    self.locked = true
   -- log("锁被获取")
    return true
end


function Lock:release()
    self.locked = false
    --log("锁被释放")
end

-- 定义 Thread 类
Thread = {}
Thread.__index = Thread

-- 创建新的线程对象
function Thread:new(func)
    local t = setmetatable({}, self)
    t.func = func
    t.running = false
    t.thread = nil
    return t
end

-- 启动线程
function Thread:start()
    if not self.running then
        self.thread = coroutine.create(self.func)
        self.running = true
        coroutine.resume(self.thread)
    end
end

-- 等待线程完成
function Thread:join()
    if self.thread then
        while coroutine.status(self.thread) ~= "dead" do
            os.sleep(0.1)
        end
        self.running = false
    end
end

-- 检查线程是否正在运行
function Thread:isRunning()
    return self.running and (coroutine.status(self.thread) ~= "dead")
end
-- 创建锁实例
local lock = Lock.new()

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

local function start(outSide,transposer, id)
     Log:append("核电仓 " .. id .. " 正在操作: 启动或停止反应堆")
    if coolingNeeded then
          Log:append("核电仓 " .. id .. " 停止中，因有冷却单元需要更换")
        redControl.stop(direction["reactor"])
        return
    end
    local isReady=true;
 
for _, reactor in ipairs(reactorLocks) do
    if not reactor.isReady then
        isReady = false
        break
    end
end

     
    if outSide ~= 0 and isReady and storedEU<maxEU*mode.capacity  then
         Log:append("核电仓 " .. id .. " 启动中")
        redControl.start(direction["reactor"])
    elseif outSide == 0 then
          Log:append("核电仓 " .. id .. " 接受到外部信号，关闭核电仓")
        redControl.stop(direction["reactor"])
        stopSignal = true
        os.exit()
     elseif not isReady then 
          Log:append("存在核电仓不满足配置，无法启动")
        redControl.stop(direction["reactor"])
     elseif mode.noneBuffer==1 then
         redControl.start(direction["reactor"])
     elseif storedEU>=maxEU*mode.capacity then
          Log:append("当前电量充足，暂停关机");
          redControl.stop(direction["reactor"])
    end

end

local function gtBatteryStart(outSide,transposer, id)
    start(outSide,transposer, id)
end

local function machineStart(outSide,transposer, id)
    start(outSide,transposer, id)
end
local function checkDamageHe(transposer,id, hePull)
     
   
    local lock = reactorLocks[id]
    redControl.stop(direction["reactor"])

    if lock.heLock then
          Log:append("核电仓 " .. id .. " 当前存在冷却单元更换中")
        return
    end

    lock.heLock = true  -- 锁定，防止其他线程同时操作
    if lock.heLockThread then
        lock.heLockThread:join()
    end

    lock.heLockThread = thread.create(function()
        -- 捕获所有异常
        local status, err = pcall(function() 
             Log:append("线程 " .. id .. " 执行冷却单元更换")
            
            -- 详细调试信息，监控 heSlot 和操作
            local heSlot = chest.checkHeSlotIsEnough(transposer, direction["heChest"], hePull)
            if not heSlot then
                  Log:append("核电仓 " .. id .. " 箱子槽位不足")
            end
            while not heSlot do
                 Log:append("核电仓 " .. id .. " 箱子槽位不足，请取出物品")
                heSlot = chest.checkHeSlotIsEnough(transposer, direction["heChest"], hePull)
                os.sleep(3)
            end

          
            local he = chest.checkHasReplace(transposer, hePull, nil)[1]
            if not he then
                  Log:append("核电仓 " .. id .. " 缺少冷却单元")
            end
             
       
            while not he do
                  Log:append("核电仓 " .. id .. " 冷却单元不足，请补充")
                    
                      local isReady=reactorControl.checkReactor(transposer, direction["reactor"])
                       if  isReady then
                     
                       hePull=nil;
                    break; 
                    end
                    reactorControl.manageCoolantCells(transposer, direction["heChest"], direction["reactor"],direction["heChest"], heliumCoolantcell.damage-10)
                   
                 
                 delayTime=delayTime+4000--延迟释放锁的时间
       
            
               
            end
                 reactorControl.pullUranAndHe(transposer, hePull, nil, direction["reactor"], direction["drainedUranChest"], direction["heChest"], heSlot, nil)
            -- 再次输出调试信息，确保能追踪到问题点
              Log:append("核电仓 " .. id .. " 准备替换冷却单元")
            reactorControl.putFuelAndHe(transposer, hePull, nil, direction["heChest"], direction["uranChest"], direction["reactor"], he, nil)

            -- 操作完成
            lock.heLock = false  -- 解锁
            delayTime=0;
             Log:append("核电仓 " .. id .. " 冷却单元更换完成")
        end)

        -- 输出捕获到的错误
        if not status then
              Log:append("错误: " .. tostring(err))
            lock.heLock = false  -- 出错时解锁
        end
    end)

    -- 确保线程不被阻塞
    lock.heLockThread:detach()
end

local function batchProcess(id)
    local startTime = os.time()
    Log:append("线程" .. id .. "开始批处理操作")

    if #reactorLocks == 1 then 
        Log:append("核电数量太少，无需批处理")
        return
    end

   
 local status, err = pcall(function()  -- 开始 pcall 函数体
    -- 遍历所有 reactorLocks 进行批处理检查
    for i, check in ipairs(reactorLocks) do
        local transposer = check.transposer
        local state = check.state

        -- 输出当前线程信息（确保 id 是已定义的变量）
        Log:append("当前线程 " .. tostring(id) .. " 正在执行批处理操作")

        -- 检查状态，如果状态不为 "OK" 则执行检查
        if state ~= "OK" then
            -- 检查冷却单元损坏状态
            local hePull = reactorControl.checkReactorDamage(transposer, direction["reactor"])

            -- 调用冷却单元损坏处理逻辑（确保 checkDamageHe 函数的参数合法）
            checkDamageHe(transposer, i, hePull)

            -- 更新状态为 "OK"
            reactorLocks[i].state = "OK"
        end
    end  -- `for` 循环体结束
end)  -- `pcall` 函数体结束，并且 `function()` 和 `pcall` 本身都有配对的括号

 
end

local function checkHe(transposer, id)

  if coolingNeeded and batchProcessId~=id then 
     Log("当前存在核电冷却单元更换，线程同步中")
    end  
    local lock = reactorLocks[id]
    local currentTime = os.time()
    local elapsedTime = currentTime - lock.lastHeCheckTime

    if elapsedTime < lock.heCheckFrequency then
        return
    end

    lock.lastHeCheckTime = currentTime
      Log:append("核电仓 " .. id .. " 正在操作: 检查冷却单元")

    local hePull = reactorControl.checkReactorDamage(transposer, direction["reactor"])
    
    if hePull  then
        for i, he in pairs(hePull) do
            if he.damage >= heliumCoolantcell.damage then
                 coolingNeeded = true 
                 
                local status, err = pcall(function() 
                     reactorLocks[id].isReady=false;
                    checkDamageHe(transposer, id, hePull)
                end)
                if not status then
                      Log:append("错误: 在冷却单元检查中发生错误 - " .. tostring(err))
                else
                    reactorLocks[id].state = "OK"
                end
               
                local batchStatus, batchErr = pcall(function()
                    batchProcessId=id--标记当前进行批处理的线程
                    batchProcess(id)  -- 批处理操作
                    
                end)
                if not batchStatus then
                      Log:append("错误: 批处理操作失败 - " .. tostring(batchErr))
                end
               
                coolingNeeded = false
                 reactorLocks[id].isReady=true;
                 batchProcessId=nil;
                 break
            else if he.damage+5>= heliumCoolantcell.damage  then
                reactorLocks[id].state = "EXCEEDED_10"
             
             end
            end
        end
    else
         Log:append("没有需要处理的冷却单元")
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
      Log:append("核电仓 " .. id .. " 正在操作: 检查燃料棒")

    local uranPull = reactorControl.checkReactorFuelDrained(transposer, direction["reactor"])
    if uranPull then
         Log:append("核电仓 " .. id .. " 检测到燃料棒枯竭")
        redControl.stop(direction["reactor"])

        if lock.fuelLock then
             Log:append("核电仓 " .. id .. " 当前存在燃料更换中")
            return
        end
        lock.fuelLock = true

        if lock.fuelLockThread then
            lock.fuelLockThread:join()
        end
        lock.fuelLockThread = thread.create(function()
            local uranSlot = chest.checkUranSlotIsEnough(transposer, direction["drainedUranChest"], uranPull)
            while not uranSlot do
                  Log:append("核电仓 " .. id .. " 箱子槽位不足，请取出物品")
                uranSlot = chest.checkUranSlotIsEnough(transposer, direction["drainedUranChest"], uranPull)
                os.sleep(3)
            end
         
            reactorControl.pullUranAndHe(transposer, nil, uranPull, direction["reactor"], direction["drainedUranChest"], direction["heChest"], nil, uranSlot)
       
           local uran = chest.checkHasReplace(transposer, nil, uranPull)[2]
            while not uran do
                  Log:append("核电仓 " .. id .. " 燃料不足，请补充")
                uran = chest.checkHasReplace(transposer, nil, uranPull)[2]
                os.sleep(3)
            end
             local status, err = pcall(function()
     reactorControl.putFuelAndHe(transposer, nil, uranPull, direction["heChest"], direction["uranChest"], direction["reactor"], nil, uran)
end)
if not status then
    print("发生错误: " .. err)
end
           
           
             lock.fuelLock = false
        end)
        lock.fuelLockThread:detach()
    end
end

local function initializeReactor(transposer, id)
      Log:append("核电仓 " .. id .. " 正在操作: 初始化反应堆")
    local isReady = reactorControl.checkReactor(transposer, direction["reactor"])
    if not isReady then
        local returnTable = reactorControl.firstPut(transposer, direction["heChest"], direction["uranChest"], direction["reactor"])
        if not returnTable[1] then
             Log:append("核电仓 " .. id .. " 无法启动，需要配置足数的冷却单元")
            return false
        end
        if not returnTable[2] then
              Log:append("核电仓 " .. id .. " 无法启动，需要配置足数的燃料")
            return false
        end
    end
    reactorLocks[id].isReady=true;
    return true
end

local function controlReactor(transposer, id)
      Log:append("核电仓 " .. id .. " 正在操作: 控制反应堆")

   if stopSignal then
          Log:append("接收到停机信号，核电仓 " .. id .. " 停止运行")
        redControl.stop(direction["reactor"])
        return
    end

    -- 初始化反应堆
    local isReady = initializeReactor(transposer, id)
    if not isReady then
          Log:append("核电仓 " .. id .. " 初始化失败")
        return
    end

    -- 启动反应堆
    local outSide = component.redstone.getInput(direction["outSideRed"])
    if mode.gtBattery then
        gtBatteryStart(outSide, transposer, id)
    elseif mode.gtMachine then
        machineStart(outSide, transposer, id)
    end

    -- 进行检查
    updateCheckFrequency(id)
    checkHe(transposer, id)
    checkUran(transposer, id)
end
local function printStatus()
    local currentTime = os.time()
    local elapsedTime = currentTime - startTime  -- 程序启动时间
    local batteryCharge, batteryMaxCharge
    local gtStoredEU, gtBatteryMaxEU, gtMachineMaxEU
    local percent

    -- 获取电池信息
    if mode.gtBattery ==1then
        storedEU = gtBattery.getBatteryCharge(1) * mode.batterySize + gtBattery.getEUStored()
        
        percent = storedEU / maxEU * 100
        print("电池电量: " .. storedEU .. " / " .. maxEU)
        print(string.format("当前电量: %.2f%%", percent))
    elseif mode.gtMachine ==1then
        storedEU = gtMachine.getEUStored()
        gtMachineMaxEU = gtMachine.getEUCapacity()
        percent = storedEU / gtMachineMaxEU * 100
        print("机器电量: " .. storedEU .. " / " .. gtMachineMaxEU)
        print(string.format("当前电量: %.2f%%", percent))
    end

    -- 输出程序存活时间
    print("程序存活时间: " .. config.minecraftToRealTime(elapsedTime))
end


local function threadFunction(id, transposer)
    local status, err = pcall(function()
        Log:append("线程 " .. id .. " 启动")
        
        -- 异步日志线程
        local logThread = thread.create(function()
            while running do
                Log:flush() -- 定期将日志缓存写入文件
                os.sleep(10) -- 每10秒刷新一次
            end
        end)
         logThread:detach() 

        while running do
            updateCheckFrequency(id)
            local status, err = pcall(function()
        checkHe(transposer, id)
    end)
    if not status then
        print("Error in checkHe: " .. err)
    end

    status, err = pcall(function()
        checkUran(transposer, id)
    end)
    if not status then
        print("Error in checkUran: " .. err)
    end
            local outSide = component.redstone.getInput(direction["outSideRed"])
            if mode.gtBattery == 1 then
                gtBatteryStart(outSide, transposer, id)
            elseif mode.gtMachine == 1 then
                machineStart(outSide, transposer, id)
            end

            if os.time() % 3== 0 then
                printStatus()
            end

            if stopSignal then
                Log:append("核电仓 " .. id .. " 停止运行")
                redControl.stop(direction["reactor"])
                running = false
                break
            end
            start(outSide,transposer, id)
            os.sleep(1)
        end

        
    end)

    if not status then
        Log:append("线程 " .. id .. " 结束")
    end
end

local function main()
    print("系统启动中...")

    -- 初始化所有反应堆，只执行一次
    for id, transposer in ipairs(transposers) do
        local isReady = initializeReactor(transposer, id)
        if isReady then
            Log:append("核电仓 " .. id .. " 初始化成功")
        else
            Log:append("核电仓 " .. id .. " 初始化失败")
            return  -- 停止程序
        end
    end

    -- 启动线程
    for id, transposer in ipairs(transposers) do
        threads[id] = thread.create(function()
            threadFunction(id, transposer)
        end)
    end

    -- 等待所有线程完成
    for id, t in ipairs(threads) do
        t:join()
    end

    Log:append("已关闭所有线程")
end

main()
