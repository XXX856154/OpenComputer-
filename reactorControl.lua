--加载文件
local component=require("component");
local config=require("reactorConfig");
local chest = require("chestControl")
local sides=require("sides");
local redControl=require("redControl");
--定义变量
local direction=config.direction;--方向
local uraniumQuadrupleFuel =config.uraniumQuadrupleFuel;--燃料配置
local heliumCoolantcell =config.heliumCoolantcell;--冷却单元配置
local size=config.rconfig.size --核电仓的大小
local he=heliumCoolantcell.name;--冷却单元名字
local uranium=uraniumQuadrupleFuel.name;--燃料名字
local Log=require("log")
--初始化
local function init()

    local heSlot=heliumCoolantcell.slot;
    local uraniumSlot=uraniumQuadrupleFuel.slot;
    local uranHash={};
    local heHash={};
    for i,v in ipairs(uraniumSlot) do 
    uranHash[v]=uraniumQuadrupleFuel;
    end;     
    for i,v in ipairs(heSlot)do 
    heHash[v]=heliumCoolantcell;    
    end
    return uranHash,heHash;
   
end;

local uranSlotHash,heSlotHash=init();
local hash={};
hash[he]=heSlotHash;
hash[uranium]=uranSlotHash

--检查核电仓是否满足配置
------
local function checkReactor(transposer,side)
   local uranNam=uraniumQuadrupleFuel.count;
   local heliumNam=heliumCoolantcell.count;


   for i=1,size do
    local item=transposer.getStackInSlot(side,i)
      
     if  item then
        
           if not hash[item.name] or item.damage >=hash[item.name][i].damage then 
                return false;
           end
     else 
        return false;
      end;
    end
   return true;
   
              
 end;  
------
--检查核电仓冷却剂的损坏程度
local function checkReactorDamage(transposer,side)

  local heSlot=heliumCoolantcell.slot;
  local heliumDamage=heliumCoolantcell.damage;
   local hePull=nil;

   
     for i,v in ipairs(heSlot) do 
         
           local item=transposer.getStackInSlot(side,v);
          if item then
            
             if item.damage+10 >=heliumDamage then
                 if not hePull then 
                   hePull={}; 
                   end;
                 hePull[v]=item; --说明这个位置的冷却单元需要取出去
             end;
          end;
       end;

       return hePull;
end; 
    
--检查枯竭燃料棒

local function checkReactorFuelDrained(transposer,side)

  local uraniumSlot = uraniumQuadrupleFuel.slot
  local drainedName = uraniumQuadrupleFuel.changeName

  local uranPull=nil;

 for i,v in ipairs(uraniumSlot) do 
    local item=transposer.getStackInSlot(side,v);
    
   if item then 

      if drainedName==item.name then
          if not uranPull then 
             uranPull={}; end;
          uranPull[v]=item;
 
          
       end;
    end;
  end
  return uranPull;

 end;

local function pullUranAndHe(transposer,hePull,uranPull,reactorSide,uranDrainedChestSide,heChestSide,hePutSlot,uranPutSlot)
   if not reactorSide or  not uranDrainedChestSide or not heChestSide then
    Log:append("该函数需要反应堆方向，枯竭燃料箱方向，冷却剂箱方向");
    return ;
    end;
  
   local uranSize=0;--需要取出的数量
   --有需要取出再执行 
   if uranPull  then
      
   for key,value in pairs(uranPull)do 
     uranSize=uranSize+value.size;
   end;


  local index=1;--箱子槽位索引
  local slotSize=0;--箱子槽位可放置的数量;
  if not uranPutSlot then  Log:append("箱子槽位不足,无法放置"); return;end;
   
    Log:append("取出枯竭燃料中,枯竭燃料棒:"..uranSize);
   for key,value in pairs(uranPull) do
     
      slotSize=uranPutSlot[index];--获取当前槽位能够放置的数量
       
    
      while uranSize >0 and index<=#uranPutSlot do --放置枯竭燃料棒
        
        if slotSize >=value.size then
          transposer.transferItem(reactorSide,uranDrainedChestSide,value.size,key,index);
          slotSize=slotSize-value.size;
          uranSize=uranSize-value.size;
          uranPutSlot[index]=slotSize;--更新能够放置的数量
           break;
         else  
              index=index+1;
              slotSize=uranPutSlot[index]--槽位变更，更新能够放置的数量
         end;
       end;
    end;
    else  Log:append("没有枯竭燃料棒，无需取出");
  end;

  if hePull then 
-- 取出冷却单元
    
    local heSize=0;
    if not hePutSlot then  Log:append("冷却单元箱子槽位不足，无法放置"); return ;end ;
   --需要取出的数量
     for key,value in pairs(hePull) do 
      heSize=heSize+value.size;
      end;
     index=1
     slotSize=0;


     Log:append("即将损坏的冷却单元:"..heSize);
     --冷却单元开始取出
   
      for key,value in pairs(hePull)do 
          slotSize=hePutSlot[index]--获取当前槽位能够放置的数量
        
         while heSize>0  and index <= #hePutSlot do 
             
                  if slotSize>=value.size then     
             
                       transposer.transferItem(reactorSide,heChestSide,value.size,key,index);
                       slotSize=slotSize-value.size;
                       heSize=heSize-value.size; 
                       hePutSlot[index]=slotSize;--更新能够放置的数量
                       break;
                   else 
                        index=index+1;
                        slotSize=hePutSlot[index]--槽位变更，更新能够放置的数量
                   end;
            end;
       end;
    else  Log:append("没有即将损坏的冷却单元，无需取出");
    end;
 end;




--根据上面取出的位置，直接放入
local function putFuelAndHe(transposer,hePull,uranPull,heChestSide,uranChestSide,reactorSide,he,uran)
    local checkTable=chest.checkHasReplace(hePull,uranPull);
  
   if he then  --检查是否足够材料

      for key, value in pairs(hePull) do 
 
          for k,v in pairs(he) do 
           
              if v>0 then  
            
             transposer.transferItem(heChestSide,reactorSide,1,k,key);--v表示原箱子的某个槽位的数量，k表示槽位，key表示目的地槽位
             he[k]=he[k]-1;  
              break;--一次换一个
             end ;
           end;
        end;
             
     end;
    

     if uran then --检查燃料棒是否充足
       
     for key,value in pairs(uranPull) do 
       for k,v in pairs(uran) do  
         
          if v>0 then   
      
          transposer.transferItem(uranChestSide,reactorSide,1,k,key);
          uran[k]=uran[k]-1;
            break;--此次替换已完成
          end ;
        end ;
      end ;

    end

end;

--第一次启动放入所有材料
local function firstPut(transposer,heSide,uranSide,reactorSide)
   local uranCheck=chest.checkUran(transposer);
   local heCheck=chest.checkHe(transposer);
   local heHash=hash[he];
   local uranHash=hash[uranium];
   local returnTable={false,false};
   if heCheck then 
     
      Log:append("核电仓执行，放入冷却单元中");
   
      for key,value in pairs(heHash) do  
           
          for  k,v in pairs(heCheck) do  

               if v> 0  then --检测数量
             
                 local flg=transposer.transferItem(heSide,reactorSide,1,k,key);
                 if flg~=0 then
                 v=v-1;
                heCheck[k]=v;--优化，减少执行的次数
                break; 
                end;
                end;
           end;
       end;
         returnTable[1]=true;
     end ;
 
    if uranCheck then  
          Log:append("核电仓执行，放入燃料棒中");
     for key,value in pairs(uranHash) do 
          for k,v in pairs(uranCheck) do 
    
            if v>0  then 
            local flg=transposer.transferItem(uranSide,reactorSide,1,k,key);
             if flg~=0 then
               v=v-1;
               uranCheck[k]=v;--优化，减少循环次数
               break;
              end;
            end;
          end
      end;
      returnTable[2]=true;
    end;
    return returnTable;
end;

-- 检查并替换损耗超过阈值的冷却单元
local function manageCoolantCells(transposer, heSide, reactorSide, chestSide, damage)
    local heSize = transposer.getInventorySize(heSide)
    local hePull = {}

    -- 取出损耗超过阈值的冷却单元并记录
    for key, _ in pairs(hash[he]) do
        local stack = transposer.getStackInSlot(reactorSide, key)
         if stack then
        if stack and stack.name == he and stack.damage >=damage then
            table.insert(hePull, {slot = key, size = stack.size})
        end
      end
    end
 
    -- 检查箱子是否有足够的空间
    local slot = chest.checkHeSlotIsEnough(transposer, chestSide, hePull)
    if not slot then
        return
    end

    -- 取出损耗超过阈值的冷却单元
    for _, value in ipairs(hePull) do
        local success = transposer.transferItem(reactorSide, heSide, value.size, value.slot)
        if success and success > 0 then
            Log:append("取出损耗超过阈值的冷却单元: 槽位 " .. value.slot)
        end
    end
   
      if hash[he] then
    for key, _ in pairs(hash[he]) do
        -- 你的代码
    end
else
     Log:append("hash[he] is nil")
end
    -- 放入满足条件的冷却单元
    for key, _ in pairs(hash[he]) do
        for i = 1, heSize do
            local stack = transposer.getStackInSlot(heSide, i)
              if stack then
            if  stack.name == he  and stack.damage < damage then
                local success = transposer.transferItem(heSide, reactorSide, stack.size, i, key)
                if success and success > 0 then
                     Log:append("放入满足条件的冷却单元: 槽位 " .. key)
                    break -- 优化，减少执行的次数
                end
            end
           end
        end
    end
end

return {
   firstStart=firstStart,
   firstPut= firstPut,
   putFuelAndHe=putFuelAndHe,
   pullUranAndHe=pullUranAndHe,
   checkReactorFuelDrained=checkReactorFuelDrained,
   checkReactorDamage=checkReactorDamage,
   checkReactor=checkReactor,
   init=init,
   manageCoolantCells=manageCoolantCells
}
