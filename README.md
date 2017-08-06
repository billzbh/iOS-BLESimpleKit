# iOS-BLE-SimpleKit
对ios系统中，BLE蓝牙当做中央模式下的轻量级封装。适合和智能硬件如手环、读卡器等设备的蓝牙交互
## 一. demo效果

iPad demo:

![IPAD](https://github.com/billzbh/iOS-SimpleBLEKit/blob/master/image/IMG_0010.jpg)

iphone demo：

![iphone_1](https://github.com/billzbh/iOS-SimpleBLEKit/blob/master/image/IMG_0011.jpg) 

![iphone_2](https://github.com/billzbh/iOS-SimpleBLEKit/blob/master/image/IMG_0012.jpg) 

![iphone_3](https://github.com/billzbh/iOS-SimpleBLEKit/blob/master/image/IMG_0013.jpg)

## 二. 解决什么需求
1. 单例，中央设备只维护一个，提供基础的搜索和连接接口
2. 能同时连接多个外设，各自通讯互不影响
3. 中央设备能管理所有已经连接的设备：断开所有，断开某个指定的设备，获取指定的设备等
4. 封装一些常用的关于二进制数据与字符串互转的方法，方便新手使用
5. 外设对象能封装基本的通讯方法，适合【发请求-等待回应】串口型的通讯协议

## 三. 如何导入（以下三选一）
### 1.直接拷贝源代码
将SimpleBLEKit文件夹整个加入到你的工程里，这个方式你可以自己再根据自己的需要修改代码
### 2.直接拷贝SimpleBLEKit.framework加入到你的工程里
直接引入SDK工程生成的SimpleBLEKit.framework

> 注意：以上两种方式都需要在build Paases中添加coreBluetooth.framework。如果是ios10以上的版本，info.plist还需要添加关于蓝牙使用的声明Privacy - Bluetooth Peripheral Usage Description。如果要使能后台模式，在工程的 Capacities--Background Modes中选择Uses Bluetooth LE accessory  

### 3.CocoaPods导入(我还没有搞，后续支持)

## 四. 调用流程说明


### （1）流程举例:
流程1：
搜索-->连接-->设定外设通讯协议-->和外设通讯-->断开连接

* **在AppDelegate.m中调用一次**

```
[[BLEManager getInstance] setIsLogOn:YES];//初始化顺便设置一下log是否显示在xcode里
```

* **1. 执行搜索功能，上报外设对象给上层app**



```
[[BLEManager getInstance] stopScan];//搜索前先停止之前的搜索

[[BLEManager getInstance] startScan:^(SimplePeripheral * _Nonnull peripheral) 
{        
        //搜索到设备走这个block
        } nameFilter:nil  timeout:10];

```


* **2. 开始连接**

```
    [[BLEManager getInstance] connectDevice:_selectedPeripheral callback:^(BOOL isPrepareToCommunicate) {
        
        NSLog(@"设备连接%@",isPrepareToCommunicate?@"成功":@"失败");
        
    }];

```

* **3. 设置收包规则**

比如你调试的通讯协议中，认为字节个数达到30，数据就收全，那你可以这么做:

```
[_selectedPeripheral setPacketVerifyEvaluator:^BOOL(NSData * inputData) {
    if(inputData.length>=30)
        return YES;//报告包完整
    return NO;    
}];
```

又比如你的协议可能比较复杂。规定第一个字节必须是02，第2个字节是后面有效数据的长度，最后一个字节是03

| Start | DataLen | Data | End |
| --- | --- | --- | --- |
| 0x02 | 0x?? | N个字节 = DataLen | 0x03 |

那你可以这么做:

```
[_selectedPeripheral setPacketVerifyEvaluator:^BOOL(NSData * inputData) {
    Byte *packBytes = (Byte*)[inputData bytes];
    if (packBytes[0]!=0x02) {
        return NO;
    }
    int dataLen = packBytes[1];
    int inputDataLen = (int)inputData.length;
    //包完整的数据应该是 开头1字节 + 长度1字节 + 结尾1字节 + 中间数据N字节
    if(inputDataLen < dataLen + 1 + 1 + 1)
        return NO;
    
    if(packBytes[1+dataLen]!=0x03)
        return NO;
    
    return YES;//报告包完整
}];
```

或者 如果你每次都是可以预先知道收到的数据大小，那么你可以这么做：
*比如你期望的包大小为28字节，第一个字节为0x02，最后的一个字节为0x03*

```
[_selectedPeripheral setResponseMatch:@"02" sufferString:@"03" NSDataExpectLength:28];
```



* **4. 发送接收数据**


```

[_selectedPeripheral sendData:data withWC:writeuuid withNC:notifyuuid timeout:5.5 receiveData:^(NSData * _Nullable outData, NSError * _Nullable error) {
        
        if(error){
            //发生超时错误
        }else{
            //根据你之前设置的收包规则，这里会收到一个完整包数据。在这里解析数据的含义
        }
    }];

```

* **断开连接**

```
[[BLEManager getInstance] isconnect:_selectedPeripheral];
```


* **其他**

  如果想实现直接连接某些特定设备，也可以直接调用下面的方法，它可以直接连接符合蓝牙名称的设备
  

```[[BLEManager getInstance] scanAndConnected:@[@"Dual-SPP",@"iKG",@"K200"] callback:^(SimplePeripheral * _Nonnull peripheral, BOOL isPrepareToCommunicate) {    NSLog(@"%@",[peripheral getPeripheralName]);}];

```
  
  

*以上就是一个简单的完整流程* 


-------



## 六. 注意事项

* 建议在AppDelegate中初始化BLEManager对象
* 听说BLE最多连接7个外设，我也没有办法测试
* 如果需要模拟器版本和真机版本合并。请看framework工程中的CreateFrameWork.txt
* 支持后台通讯，只要你的info.plist声明使用BLE后台模式
* 读取广播数据啥的，RSS啥的，我都不用，目前为止没用过，要用自己实现在外设里面。
* 只支持中央模式，不支持ios模拟为外设的模式。
* 此SDK不考虑多个指令并发的情况。比如我们的设备，每次都只响应一个指令，如果它还在工作中，你马上给它发下一个工作指令，它可能不会响应，除了一些取消操作指令，重置指令。所以假如你需要多个指令同时发送和接收数据，同一个notify特征应该会很难解析数据，而如果硬件支持使用不同的notify特征来接收数据的话，并且确实支持同时应答多个指令，SDK是支持同时发送接收多个指令的，互不影响。

## 七. 更多使用方法见WiKi


