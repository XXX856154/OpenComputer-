local component=require("component");
local sides=require("sides");
local config=require("reactorConfig");
local uran=config.uraniumQuadrupleFuel.name;
local he=config.heliumCoolantcell.name;
local drainedName=config.uraniumQuadrupleFuel.changeName
local direction=config.direction;

--检查第一次启动燃料是否充足
local function checkUran(transposer)
    local size=transposer.getInventorySize(direction["uranChest"]);
    local uranNam=config.uraniumQuadrupleFuel.count;
     local uranTableInSlot=nil;
--检查燃料
    for i=1,size do 
  
    local projectSlot=transposer.getStackInSlot(direction["uranChest"],i) ;
       
      if  projectSlot then

        if projectSlot.name==uran then
           if not uranTableInSlot then  uranTableInSlot={} end;   
          
           uranNam=uranNam-projectSlot.size;
   
           uranTableInSlot[i]=projectSlot.size;
           if uranNam<=0  then break; end;
        end
       end;
   end;
   
  return uranTableInSlot;
           
end
--检查第一次启动冷却单元是否充足
local function checkHe(transposer)

   local size=transposer.getInventorySize(direction["heChest"]);
    local heNam=config.heliumCoolantcell.count;
    local heTableInSlot=nil
      
    for i=1,size do 
    local projectSlot=transposer.getStackInSlot(direction["heChest"],i) ;
      if  projectSlot then 
     
        if projectSlot.name== he and projectSlot.damage<config.heliumCoolantcell.damage then --检查受损程度
             if  not heTableInSlot then heTableInSlot={}; end;
              
            heNam=heNam-projectSlot.size;
             heTableInSlot[i]=projectSlot.size;
            if heNam<=0  then break; end;
        end
       end;

     end
  return heTableInSlot;
end

--检查箱子是否有足够的空间放枯竭燃料棒
local function  checkUranSlotIsEnough(transposer,chestSide,uranPull)

 
    local chestSize=transposer.getInventorySize(chestSide);

    local requireSize=0;
  
    local slot={};--记录可以放置的位置
    for key,value in pairs(uranPull) do 
    requireSize=requireSize+value.size
    end;
  
    
    for i=1,chestSize do 
     slot[i]=0;--默认存不下
     local item=transposer.getStackInSlot(chestSide,i);
     
     --有物品时，计算可以放置的数量
      if item and item.name==drainedName then 
        
         local hasUsed=item.maxSize-item.size;
             requireSize=requireSize-hasUsed;
             slot[i]=hasUsed;
       elseif not item then
          requireSize=requireSize-64;
          slot[i]=64;
      end
     --说明足以放置
     if requireSize<=0 then
    
      return slot;
   
     end
  
   end
   print("枯竭燃料箱子空间不足")
  return nil;
end

--检查箱子是否有足够的空间放损坏的冷却单元
local function  checkHeSlotIsEnough(transposer,chestSide,hePull)

    local chestSize=transposer.getInventorySize(chestSide);
    local requireSize=0;
    local slot={};--记录可以放置的位置
    for key,value in pairs(hePull) do 
    requireSize=requireSize+value.size
    end;
     
    for i=1,chestSize do 
     slot[i]=0;--默认放不下
      local item=transposer.getStackInSlot(chestSide,i);
     --有物品时，计算可以放置的数量
      if item and item.name==he then 
  
         local hasUsed=item.maxSize-item.size;
         requireSize=requireSize-hasUsed;
         slot[i]=hasUsed;
         
      elseif not item then --当前槽位不存在物品
         requireSize=requireSize-1;
          slot[i]=1;
      end
 
     --说明足以放置
     if requireSize<=0 then 
         return slot;
     end;
   end;
    print("冷却单元存放位置不足");
    return nil;
end

--检查替换的材料
local function checkHasReplace(transposer,hePull,uranPull)
     local uranRequire=0;
     local heRequire=0;
     local helium=nil;
     local uranium=nil;

     if hePull then
       print("正在查看是否有足够的冷却单元");
        for key,value in pairs(hePull)do 
        heRequire=heRequire+value.size;
      end;
 
      local heChestSize=transposer.getInventorySize(direction["heChest"]);
      for i=1,heChestSize do 
        local chestHe=transposer.getStackInSlot(direction["heChest"], i);
       
        if chestHe and chestHe.damage<config.heliumCoolantcell.damage then 
            if not helium then helium={}; end;
            helium[i]=chestHe.size--这个槽位拥有的数量；
            heRequire=heRequire-chestHe.size;
         
           if heRequire<=0 then break; 
          end; 
        end ;
      end
     else 
      print("冷却单元尚能工作，无需检查冷却单元");
 
    end;
      if heRequire >0 then --说明冷却单元不足
         helium=nil;
      end;

     if uranPull then 
      for key,value in pairs(uranPull) do 
      uranRequire=uranRequire+value.size;
      end ;
     local uranChestSize=transposer.getInventorySize(direction["uranChest"]);
      for i=1,uranChestSize do 
        local chestUran=transposer.getStackInSlot(direction["uranChest"],i);
         if chestUran then 
      
            if not uranium then uranium={}; end;
           uranium[i]=chestUran.size;
           uranRequire=uranRequire-chestUran.size; 
              if uranRequire<=0 then break; 
               end;
            end;
         end ; 
      else print("燃料棒未枯竭，无需检查燃料棒"); 
     end;

      if uranRequire >0 then --说明冷却单元不足
         uranRequire=nil;
      end;
    return {helium,uranium};
end

return{
checkUran=checkUran,
checkHe=checkHe,
checkUranSlotIsEnough=checkUranSlotIsEnough,
checkHeSlotIsEnough=checkHeSlotIsEnough,
checkHasReplace=checkHasReplace
    
}

