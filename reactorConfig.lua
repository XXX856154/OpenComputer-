local com=require("component");
local sides=require("sides");
--local gt=com.gt_machine;
--local totalEU=gt.getStoredEU();
--local capacity=gt.getEUCapacity();
local JSON = (loadfile "JSON.lua")()
local heliumCoolantcell={};
local uraniumQuadrupleFuel={};
local direction={
reactor=sides.north,--反应堆存放位置
uranChest=sides.west,--燃料棒存放位置
heChest=sides.east,--冷却单元存放位置
drainedUranChest=sides.up,--枯竭燃料棒存放的箱子
outSideRed=sides.up--外置红石信号位置
}
local function load()


  local file=io.open("./config.json","r");
  if  not file then 
  print("file not exist");
  return ;
  end;
 
  local config=JSON:decode(file:read("*a"));
  file:close();
  local data= config["uraniumQuadrupleFuel"];
  local table={}; 
  for i,item in ipairs(data) do 
    table[i]={
     --print(item.name);
     name=item.name;
     damage=item.dmg;
     count=item.count;
     slot=item.slot;
     changeName=item.changeName;
 }    

  end 
 
 return table;
end   

local function minecraftToRealTime(mcTime)
    -- Minecraft时间转换为现实时间的系数
    local realTimePerMcSecond = 0.0138

    -- 将Minecraft时间转换为现实时间（秒）
    local totalTime = mcTime * realTimePerMcSecond

    -- 计算天数、小时、分钟和秒
    local seconds = math.floor(totalTime % 60)
    local minutes = math.floor((totalTime / 60) % 60)
    local hours = math.floor((totalTime / (60 * 60)) % 24)
    local days = math.floor(totalTime / (60 * 60 * 24))
    
    return days .. "天 " .. hours .. "小时 " .. minutes .. "分钟 " .. seconds .. "秒"
end
local loadData= load()
heliumCoolantcell=loadData[1];
uraniumQuadrupleFuel=loadData[2];
return {
  --gt=gt,
  --totalEU=totalEU,
  --capacity=capacity;
  heliumCoolantcell=heliumCoolantcell,
  uraniumQuadrupleFuel=uraniumQuadrupleFuel,
  minecraftToRealTime=minecraftToRealTime,
  direction=direction
}