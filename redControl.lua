local com=require("component");
local sides=require("sides");
local redStone=com.redstone;

------
local function stop(side)
 
 if side~=nil  then
    return redStone.setOutput(side,0);
 end
end
------
local function start(side)

  if side~=nil  then
    redStone.setOutput(side,5);
 end
end 
------
local function getOutSide(side)
   return redStone.getInput(side);
end
return 
{
start=start,
stop=stop,
getOutSide=getOutSide
} 