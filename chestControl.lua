local component=require("component");
local transposer=component.transposer;
local sides=require("sides");
local config=require("reactorConfig");
local uran=config.uraniumQuadrupleFuel.name;
local he=config.heliumCoolantcell.name;
local drainedName=config.uraniumQuadrupleFuel.changeName
local direction=config.direction;

--检查第一次启动燃料是否充足
local function checkUran()
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
local function checkHe()

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
local function  checkUranSlotIsEnough(chestSide,uranPull)

 
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
local function  checkHeSlotIsEnough(chestSide,hePull)

    local chestSize=transposer.getInventorySize(chestSide);
    local requireSize=0;
    local slot={};--记录可以放置的位置
    for key,value in pairs(hePull) do 
    requireSize=requireSize+value.size
    end;
     
    为我=1,chestSize 做 
     slot[i]=0;--默认放不下
      当地的 item=transposer.getStackInSlot(chestSide,i);
     --有物品时，计算可以放置的数量
      如果 item 和 item.name==he 然后 
  
         当地的 hasUsed=item.maxSize-item.size;
         requireSize=requireSize-hasUsed;
         slot[i]=hasUsed;
         
      elseif 不 item 然后 --当前槽位不存在物品
         requireSize=requireSize-1;
          slot[i]=1;
      结束
 
     --说明足以放置
     如果 requireSize<=0 然后 
         返回 slot;
     结束;
   结束;
打印("冷却单元存放位置不足");
    返回 无;
结束

--检查替换的材料
当地的 功能checkHasReplace（he pull，uranPull）
     当地的uranRequire=0;
     当地的这里要求=0;
     当地的氦气=无;
     当地的铀=无;

     如果赫普尔然后
打印("正在查看是否有足够的冷却单元");
        为键，值在对子（赫普尔）做 
he require = he require+value . size；
      结束;
 
      当地的heChestSize = transposer . getinventorysize（方向【“赫克斯特”]);
      为我=1，heChestSize做 
        当地的chest he = transposer . getstackinslot（direction【“赫克斯特”】，I）；
       
        如果切斯特和chest he . damage《config . heliumclulantcell . damage然后 
            如果 不氦然后氦= { }；结束;
氦【I】= chest he . size-这个槽位拥有的数量；
here require = here require-chest he . size；
         
           如果here require《=0 然后 破裂; 
          结束; 
        结束 ;
      结束
     其他 
打印("冷却单元尚能工作,无需检查冷却单元");
 
    结束;
      如果此处要求》0 然后 -说明冷却单元不足
氦气=无;
      结束;

     如果铀拉然后 
      为键，值在对（铀拉）做 
uran require = uran require+value . size；
      结束 ;
     当地的uranchetsize = transposer . getinventorysize（direction【“铀箱”]);
      为我=1，胸部大小做 
        当地的chest uran = transposer . getstackinslot（direction【“铀箱”】，I）；
         如果切斯特兰然后 
      
            如果 不铀然后铀= { }；结束;
铀【I】=切斯特兰。size；
uran require = uran require-chest uran . size；
              如果uran require《=0 然后 破裂;  
               结束;
            结束;
         结束 ; 
      其他打印("燃料棒未枯竭,无需检查燃料棒"); 
     结束;

      如果uranRequire》0 然后 -说明冷却单元不足
uranRequire=无;
      结束;
    返回{氦、铀}；
结束

返回{
切克兰=切克兰，
checkHe=checkHe
checkuranslotisough = checkuranslotisough，
checkHeSlotIsEnough = checkHeSlotIsEnough，
checkHasReplace = checkHasReplace
    
}

