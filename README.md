# OpenComputer-
使用OC控制强冷核电
redControl为红石控制文件
reactorControl为核电控制逻辑文件
chestControl为箱子控制文件
reactorConfig为代码的配置文件
config.json为使用的燃料和冷却单元配置文件(可更换燃料和冷却单元)
JSON.json为JSON库

下面的所有方向皆可改，改reactorConfig里面的配置文件direction即可

使用方法:
核电仓面朝北方
红石i/o端口会向核电仓的方向发出红石信号，控制核电仓开关
转运器右边为存放冷却单元箱子位置
转运器上面为存放枯竭燃料棒箱子位置
转运器左边为存放燃料棒箱子位置 
转运器北面为核电仓。

摆放完毕后，启动nuclearpowercontrol文件(记得在红石i/o端口上面放个拉杆输入红石信号);

多核版本由于代码使用了多线程，低级的主机是跑不起来的，请使用高级主机。
如果要控制单核，推荐使用可选择存储模式那一版

