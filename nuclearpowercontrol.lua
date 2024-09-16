local redControl=require("redControl");
local sides=require("sides");
local com=require("component");
local reactorControl=require("reactorControl");
local config=require("reactorConfig");
local chest=require("chestControl");
local direction=config.direction;
local mode=config.mode;
local transposer=com.transposer;
--第一次启动，先检查反应堆

local isReady=reactorControl.checkReactor(transposer,direction["reactor"]);
if not isReady  then --说明核电仓没准备好
   local returnTable=reactorControl.firstPut(transposer,direction["heChest"],direction["uranChest"],direction["reactor"]);--放置原料
   if not  returnTable[1] then print("无法启动，需要配置足数的冷却单元"); return end;
   if not  returnTable[2] then print("无法启动，需要配置足数的燃料"); return end;
end;
   local outSide=redControl.getOutSide(direction["outSideRed"]);
   if outSide~=0 then redControl.start(direction["reactor"]); print("核电仓已启动")
   else print("请输入外部红石信号")  return ;
   end ;



   local startTime=os.time();--返回的是mc世界创建以来的时间
   local gtBattery;
   local gtBatteryMaxEU;
   local gtMachine;
   local gtMachineMaxEU;
     if mode.noneBuffer == 1  then
     elseif mode.gtBattery==1 then gtBattery=com.gt_batterybuffer; 
     gtBatteryMaxEU=gtBattery.getMaxBatteryCharge(1)*mode.batterySize+gtBattery.getEUCapacity();
     elseif mode.gtMachine==1 then gtMachine=com.gt_machine; 
      gtMachineMaxEU=gtMachine.getEUMaxStored();
      end;
     

local function start(outSide,isReady)

     if outSide~=0 and isReady  then --满足才启动
        print("核电仓启动中");
        redControl.start(direction["reactor"]);
      elseif outSide==0  then 
         print("接受到外部信号，关闭核电仓");
        redControl.stop(direction["reactor"]); 
        os.exit();
      else 
          print("核电仓不满足配置，无法启动");
         redControl.stop(direction["reactor"]); 
      end

end
           
local function gtBatteryStart(outSide,isReady)
    
     start(outSide,isReady);

      local gtStoredEU=gtBattery.getBatteryCharge(1)*mode.batterySize+gtBattery.getEUStored();
      print("可存储电量为:"..gtBatteryMaxEU);
      print(string.format("当前电量: %.2f%%",gtStoredEU/gtBatteryMaxEU*100));
      if gtStoredEU>=gtBatteryMaxEU*mode.capacity then  
          print("电量充足，暂停关机");
          redControl.stop(direction["reactor"]); 
      end
 
end
local function machineStart(outSide,isReady)
       start(outSide,isReady);
       local gtStoredEU=gtMachine.getEUStored()
       print("可存储电量为:"..gtMachineMaxEU);
       print(string.format("当前电量: %.2f%%",gtStoredEU/gtMachineMaxEU*100));
      if gtStoredEU>=gtMachineMaxEU *mode.capacity then 
          print("电量充足，暂停关机");
          redControl.stop(direction["reactor"]); 
      end

end
local function checkHe()

 

     local hePull=reactorControl.checkReactorDamage(transposer,direction["reactor"]);--检查受损的冷却单元
       
     
     if hePull then --说明有需要更换的，先停止反应仓
       
        redControl.stop(direction["reactor"]);
        os.sleep(1);--休眠一秒再取出来,核电仓收到信号不会立马关闭
         local heSlot=chest.checkHeSlotIsEnough(transposer,direction["heChest"],hePull);
           while not heSlot  do  
           print("箱子槽位不足,请取出物品");
           heSlot=chest.checkHeSlotIsEnough(transposer,direction["heChest"],hePull);
           os.sleep(3);
           end;
           reactorControl.pullUranAndHe(transposer,hePull,nil,direction["reactor"],direction["drainedUranChest"],direction["heChest"],heSlot,nil);
           local he=chest.checkHasReplace(transposer,hePull,nil)[1];
           while not he do 
             print("冷却单元不足，请补充");
             he=chest.checkHasReplace(transposer,hePull,nil)[1];
             os.sleep(3);
           end
           reactorControl.putFuelAndHe(transposer,hePull,nil,direction["heChest"],direction["uranChest"],direction["reactor"],he,nil);
     
        end;

end;
local function checkUran()

       local uranPull=reactorControl.checkReactorFuelDrained(transposer,direction["reactor"]);
      if uranPull then 
       
        redControl.stop(direction["reactor"]);
        os.sleep(1);--休眠一秒再取出来,核电仓收到信号不会立马关闭
         local uranSlot=chest.checkUranSlotIsEnough(transposer,direction["drainedUranChest"],uranPull);
           while not uranSlot  do  
           print("箱子槽位不足,请取出物品");
           uranSlot=chest.checkUranSlotIsEnough(transposer,direction["drainedUranChest"],uranPull);
           os.sleep(3);
           end;
            reactorControl.pullUranAndHe(transposer,nil,uranPull,direction["reactor"],direction["drainedUranChest"],direction["heChest"],nil,uranSlot);
           
          local uran=chest.checkHasReplace(transposer,nil,uranPull)[2];
     
           while not uran do 
             print("燃料不足，请补充");
             uran=chest.checkHasReplace(transposer,nil,uranPull)[2];
             os.sleep(3);
           end
           reactorControl.putFuelAndHe(transposer,nil,uranPull,direction["heChest"],direction["uranChest"],direction["reactor"],nil,uran);
     
      end;
end;

   while true do 
    
   checkHe();--检查受损冷却单元
   checkUran();--检查燃料棒是否枯竭
     
    
     --检查是否满足配置
    local isReady=reactorControl.checkReactor(transposer,direction["reactor"]);
    local outSide=redControl.getOutSide(direction["outSideRed"]);
    if mode.gtBattery==1 then
   gtBatteryStart(outSide,isReady);
   elseif mode.gtMachine==1 then 
       machineStart(outSide,isReady);
   else 
    start(outSide,isReady);
  end;
    local excutionTime=os.time();
    local totalTime=excutionTime-startTime;
    print("已运行时间:"..config.minecraftToRealTime(totalTime));

   end;
              



    
  
