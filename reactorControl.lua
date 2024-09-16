-- 加载文件
local component = require("component")
local config = require("reactorConfig")
local chest = require("chestControl")
local sides = require("sides")
local redControl = require("redControl")

-- 定义变量
local direction = config.direction
local uraniumQuadrupleFuel = config.uraniumQuadrupleFuel
local heliumCoolantcell = config.heliumCoolantcell
local size = config.rconfig.size
local he = heliumCoolantcell.name
local uranium = uraniumQuadrupleFuel.name

-- 初始化
local function init()
    local heSlot = heliumCoolantcell.slot
    local uraniumSlot = uraniumQuadrupleFuel.slot
    local uranHash, heHash = {}, {}
    
    for _, slot in ipairs(uraniumSlot) do
        uranHash[slot] = uraniumQuadrupleFuel
    end
    
    for _, slot in ipairs(heSlot) do
        heHash[slot] = heliumCoolantcell
    end
    
    return uranHash, heHash
end

local uranSlotHash, heSlotHash = init()
local hash = { [he] = heSlotHash, [uranium] = uranSlotHash }

-- 检查核电仓是否满足配置
local function checkReactor(transposer, side)
    local uranNam = uraniumQuadrupleFuel.count
    local heliumNam = heliumCoolantcell.count

    for i = 1, size do
        local item = transposer.getStackInSlot(side, i)
        local slotHash = hash[item.name]
        
        if item and (not slotHash or item.damage >= slotHash[i].damage) then
            return false
        end
    end
    return true
end

-- 检查核电仓冷却剂的损坏程度
local function checkReactorDamage(transposer, side)
    local heSlot = heliumCoolantcell.slot
    local heliumDamage = heliumCoolantcell.damage
    local hePull = {}

    for _, slot in ipairs(heSlot) do
        local item = transposer.getStackInSlot(side, slot)
        if item and item.damage >= heliumDamage then
            hePull[slot] = item
        end
    end

    return next(hePull) and hePull or nil
end

-- 检查枯竭燃料棒
local function checkReactorFuelDrained(transposer, side)
    local uraniumSlot = uraniumQuadrupleFuel.slot
    local drainedName = uraniumQuadrupleFuel.changeName
    local uranPull = {}

    for _, slot in ipairs(uraniumSlot) do
        local item = transposer.getStackInSlot(side, slot)
        if item and item.name == drainedName then
            uranPull[slot] = item
        end
    end

    return next(uranPull) and uranPull or nil
end

-- 拉取枯竭燃料和冷却剂
local function pullUranAndHe(transposer, hePull, uranPull, reactorSide, uranDrainedChestSide, heChestSide, hePutSlot, uranPutSlot)
    if uranPull then
        local uranSize = 0
        for _, item in pairs(uranPull) do
            uranSize = uranSize + item.size
        end
        
        local index = 1
        local slotSize = 0
        
        if not uranPutSlot then
            print("箱子槽位不足,无法放置")
            return
        end
        
        print("取出枯竭燃料中,枯竭燃料棒:" .. uranSize)
        for _, item in pairs(uranPull) do
            slotSize = uranPutSlot[index]
            
            while uranSize > 0 and index <= #uranPutSlot do
                if slotSize >= item.size then
                    transposer.transferItem(reactorSide, uranDrainedChestSide, item.size, _, index)
                    slotSize = slotSize - item.size
                    uranSize = uranSize - item.size
                    uranPutSlot[index] = slotSize
                    break
                else
                    index = index + 1
                    slotSize = uranPutSlot[index]
                end
            end
        end
    else
        print("没有枯竭燃料棒，无需取出")
    end

    if hePull then
        local heSize = 0
        for _, item in pairs(hePull) do
            heSize = heSize + item.size
        end
        
        local index = 1
        local slotSize = 0
        
        if not hePutSlot then
            print("冷却单元箱子槽位不足，无法放置")
            return
        end
        
        print("即将损坏的冷却单元:" .. heSize)
        for _, item in pairs(hePull) do
            slotSize = hePutSlot[index]
            
            while heSize > 0 and index <= #hePutSlot do
                if slotSize >= item.size then
                    transposer.transferItem(reactorSide, heChestSide, item.size, _, index)
                    slotSize = slotSize - item.size
                    heSize = heSize - item.size
                    hePutSlot[index] = slotSize
                    break
                else
                    index = index + 1
                    slotSize = hePutSlot[index]
                end
            end
        end
    else
        print("没有即将损坏的冷却单元，无需取出")
    end
end

-- 放入燃料和冷却剂
local function putFuelAndHe(transposer, hePull, uranPull, heChestSide, uranChestSide, reactorSide, he, uran)
    local checkTable = chest.checkHasReplace(hePull, uranPull)

    if he then
        for slot, _ in pairs(hePull) do
            for k, v in pairs(he) do
                if v > 0 then
                    transposer.transferItem(heChestSide, reactorSide, 1, k, slot)
                    he[k] = he[k] - 1
                    break
                end
            end
        end
    end

    if uran then
        for slot, _ in pairs(uranPull) do
            for k, v in pairs(uran) do
                if v > 0 then
                    transposer.transferItem(uranChestSide, reactorSide, 1, k, slot)
                    uran[k] = uran[k] - 1
                    break
                end
            end
        end
    end
end

-- 第一次启动放入所有材料
local function firstPut(transposer, heSide, uranSide, reactorSide)
    local uranCheck = chest.checkUran(transposer)
    local heCheck = chest.checkHe(transposer)
    local heHash = hash[he]
    local uranHash = hash[uranium]
    local returnTable = {false, false}

    if heCheck then
        print("第一次执行，放入冷却单元中")
        for slot, _ in pairs(heHash) do
            for k, v in pairs(heCheck) do
                if v > 0 then
                    local flg = transposer.transferItem(heSide, reactorSide, 1, k, slot)
                    if flg ~= 0 then
                        v = v - 1
                        heCheck[k] = v
                        break
                    end
                end
            end
        end
        returnTable[1] = true
    end

    if uranCheck then
        print("第一次执行，放入燃料棒中")
        for slot, _ in pairs(uranHash) do
            for k, v in pairs(uranCheck) do
                if v > 0 then
                    local flg = transposer.transferItem(uranSide, reactorSide, 1, k, slot)
                    if flg ~= 0 then
                        v = v - 1
                        uranCheck[k] = v
                        break
                    end
                end
            end
        end
        returnTable[2] = true
    end

    return returnTable
end

return {
    firstPut = firstPut,
    putFuelAndHe = putFuelAndHe,
    pullUranAndHe = pullUranAndHe,
    checkReactorFuelDrained = checkReactorFuelDrained,
    checkReactorDamage = checkReactorDamage,
    checkReactor = checkReactor,
    init = init
}
