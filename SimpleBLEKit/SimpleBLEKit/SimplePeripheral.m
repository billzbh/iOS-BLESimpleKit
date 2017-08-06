//
//  SimplePeripheral.m
//  SimpleBLEKit
//
//  Created by zbh on 17/3/14.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#import "SimplePeripheral.h"
#import "SimplePeripheralPrivate.h"
#import "DataDescription.h"
#import "BLEManager.h"

@interface SimplePeripheral () <CBPeripheralDelegate>

@property (copy, nonatomic)   BLEStatusBlock _Nullable    MyStatusBlock;
@property (strong, nonatomic) CBCentralManager          *centralManager;
@property (strong, nonatomic) NSDictionary              *serviceAndCharacteristicsDictionary;
@property (strong, nonatomic) NSMutableDictionary       *Services;
@property (strong, nonatomic) NSMutableDictionary       *Characteristics;
@property (copy, nonatomic)   PacketVerifyEvaluator      packetVerifyEvaluator;
@property (copy, nonatomic)   setupAfterConnected        AfterConnectedDoSomething;
@property (strong,nonatomic)  DataDescription            *dataDescription;
@property (assign,nonatomic)  int                       MTU;
@property (assign,nonatomic)  int                       CharacteristicsCount;
@property (assign,nonatomic)  int                       ServicesCount;
@property (assign,nonatomic)  CBCharacteristicWriteType ResponseType;
@property (assign,nonatomic)  BOOL                      isLog;
@property (assign,nonatomic)  BOOL                      isReadDescriptors;
@property (assign,nonatomic)  BOOL                      isWorking;
@property (strong,nonatomic)  NSData                    *AckData;
@property (strong,nonatomic)  NSString                  *AckWriteCharacteristicUUIDString;
@property (strong,nonatomic)  NSMutableDictionary       *continueNotifyUUIDStringAndBlockDict;

//都需要添加和删除元素
@property (strong,nonatomic)  NSMutableDictionary       *DescriptionDict;
@property (strong,nonatomic)  NSMutableDictionary       *NotifyUUIDStringAndBlockDict;
@property (strong,nonatomic)  NSMutableDictionary       *NotifyUUIDStringAndNSTimerDict;
@property (strong,nonatomic)  NSMutableDictionary       *workingStatusDict;//每个特征通讯工作状态，主要记录订阅通知的工作状态
@end


@implementation SimplePeripheral

- (instancetype)initWithCentralManager:(CBCentralManager *)manager
{
    self = [super init];
    if (!self)
        return nil;

    //初始化各个成员变量
    _centralManager = manager;
    _dataDescription = [[DataDescription alloc] init];
    _isLog = NO;
    _isReadDescriptors = NO;
    _isAutoReconnect =NO;
    _MTU = -1;
    _CharacteristicsCount = 0;
    _ServicesCount = 0;
    _isWorking = NO;
    _ResponseType = CBCharacteristicWriteWithoutResponse;
    _Characteristics = [[NSMutableDictionary alloc] init];
    _Services = [[NSMutableDictionary alloc] init];
    _continueNotifyUUIDStringAndBlockDict = [[NSMutableDictionary alloc] init];
    _NotifyUUIDStringAndBlockDict = [[NSMutableDictionary alloc] init];
    _NotifyUUIDStringAndNSTimerDict = [[NSMutableDictionary alloc] init];
    _workingStatusDict = [[NSMutableDictionary alloc] init];
    _DescriptionDict = [[NSMutableDictionary alloc] init];
    return self;
}

- (void)dealloc
{
    _centralManager = nil;
    _dataDescription = nil;
    _serviceAndCharacteristicsDictionary = nil;
    _Characteristics= nil;
    _Services = nil;
    _peripheral = nil;
    _MyStatusBlock = nil;
    _packetVerifyEvaluator = nil;
    _AfterConnectedDoSomething = nil;
    _AckWriteCharacteristicUUIDString = nil;
    _continueNotifyUUIDStringAndBlockDict = nil;
    _NotifyUUIDStringAndBlockDict = nil;
    _NotifyUUIDStringAndNSTimerDict = nil;
    _DescriptionDict = nil;
    _workingStatusDict = nil;
}

-(void)setAckData:(NSData* _Nullable)data withWC:(NSString * _Nullable)writeUUIDString
 withACKEvaluator:(NeekAckEvaluator _Nullable)ackEvaluator
{
    _AckWriteCharacteristicUUIDString = writeUUIDString;
    [_dataDescription setNeekAckEvaluator:ackEvaluator];
    self.AckData = data;
}

-(void)setupDeviceAfterConnected:(setupAfterConnected)setupAfterConnectedBlock{
    _AfterConnectedDoSomething = setupAfterConnectedBlock;
}

-(void)setServiceAndCharacteristicsDictionary:(NSDictionary * _Nullable)dict;
{
    _serviceAndCharacteristicsDictionary = dict;
    [_Services removeAllObjects];
    [_Characteristics removeAllObjects];
    _ServicesCount = 0;
    _CharacteristicsCount = 0;
}

-(void)setPacketVerifyEvaluator:(PacketVerifyEvaluator)packetEvaluator
{
    _packetVerifyEvaluator = packetEvaluator;
    [_dataDescription setPacketVerifyEvaluator:_packetVerifyEvaluator];
}

-(void)setResponseMatch:(NSString*)prefixString sufferString:(NSString*)sufferString NSDataExpectLength:(int)expectLen
{
    
    _packetVerifyEvaluator = ^BOOL(NSData * _Nullable inputData) {
        
        if (inputData.length<expectLen) {
            return NO;
        }
        
        NSString *hexString = [BLEManager NSData2hexString:inputData];
        NSString *regularExpressions =[NSString
                                       stringWithFormat:@"%@[A-Fa-f0-9]+%@",prefixString,sufferString];
        NSRange range = [hexString rangeOfString:regularExpressions options:NSRegularExpressionSearch];
        if (range.location != NSNotFound) {
            NSString *rangeString = [hexString substringWithRange:range];
            if(rangeString.length%2==0)
                return YES;
            else
                return NO;
        }
        return NO;
    };
    
    [_dataDescription setPacketVerifyEvaluator:_packetVerifyEvaluator];
}


-(BOOL)isConnected{
    
    if (_peripheral) {
        if (_peripheral.state==CBPeripheralStateDisconnected) {
            return NO;
        }else if (_peripheral.state==CBPeripheralStateConnected){
            return YES;
        }else{
            return NO;
        }
    }else{
        return NO;
    }
}

-(NSString*)getPeripheralName{
    return _peripheral.name;
}

#pragma mark  -  操作方法

-(void)connectDevice:(BLEStatusBlock)myStatusBlock{
    _MyStatusBlock = myStatusBlock;

    if ([self isConnected]) {
        __weak typeof(self) weakself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if(weakself.isLog) NSLog(@"设备已处于连接状态");
            if(weakself.MyStatusBlock!=nil)
                weakself.MyStatusBlock(YES);
        });
        return;
    }
    
    if(_serviceAndCharacteristicsDictionary!=nil){
        if([_serviceAndCharacteristicsDictionary count] <=0 ){
            if(_isLog) NSLog(@"请先设置服务UUIDs");
            return;
        }
        
        if([[[_serviceAndCharacteristicsDictionary allValues] objectAtIndex:0] count] <=0 ){
            if(_isLog) NSLog(@"请先设置特征UUIDs");
            return;
        }
    }
    
    if(_packetVerifyEvaluator==nil){
        NSLog(@"PacketVerifyEvaluator未设置\n-----默认规则是收到数据包size大于0就认为收包完整\n自定义收包完整的规则,调用(二选一):\n-(void)setPacketVerifyEvaluator:(PacketVerifyEvaluator)packetEvaluator\n-(void)setResponseMatch:(NSString*)prefixString sufferString:(NSString*)sufferString NSDataExpectLength:(int)expectLen\n");
        return;
    }
    
    if(_isLog) NSLog(@"开始连接设备...");
    
    if([_centralManager isScanning])
        [_centralManager stopScan];
    
    if (_peripheral==nil) {
        if(_isLog) NSLog(@"发生nil错误,可能外设SimplePeripheral并不是来自搜索得来的对象");
        return;
    }
    
    [self.centralManager connectPeripheral:_peripheral
                                   options:nil];
    
}

-(void)disconnect{

    [self setIsAutoReconnect:NO];

    if (self.peripheral) {
        
        for (CBCharacteristic* characteristic in [_Characteristics allValues]) {
            if (characteristic.isNotifying) {
                [self.peripheral setNotifyValue:NO forCharacteristic:characteristic];
            }
        }
        [_Characteristics removeAllObjects];
    }
    
    if (self.peripheral && (self.peripheral.state == CBPeripheralStateConnecting || self.peripheral.state == CBPeripheralStateConnected)) {
        [_centralManager cancelPeripheralConnection:self.peripheral];
    }
    if(_isLog) NSLog(@"开始主动断开连接");
}

#pragma mark 发送接收方法(订阅通知)
//只发送
-(BOOL)sendData:(NSData * _Nonnull)data withWC:(NSString* _Nonnull)writeUUIDString
{
    CBCharacteristic* characteristic = [_Characteristics objectForKey:writeUUIDString];
    if (characteristic ==nil) {
        //写特征为nil，可能外设SimplePeripheral找不到此特征
        if(_isLog) NSLog(@"写特征【%@】 找不到",writeUUIDString);
        return NO;
    }
    
    __weak typeof(self) weakself = self;
    dispatch_async(dispatch_get_main_queue(), ^{ //解决多线程写数据冲突的问题，使用main_queue进行排队
        
        if (_MTU <= 0 ) {//直接发送
            
            [weakself.peripheral writeValue:data
                      forCharacteristic:characteristic
                                   type:weakself.ResponseType];
            
        }else{//分包发送
            
            int newMTU = (int)[self.peripheral maximumWriteValueLengthForType:_ResponseType];
            if(_isLog)
                NSLog(@"设置的MTU实验值=%d 系统和外设协商的MTU=%d",_MTU,newMTU);
            if (_MTU > newMTU) {//设置的MTU实验值不能大于系统协商的MTU值
                _MTU = newMTU;
            }
        
            int length = (int)data.length;
            int offset = 0;
            int sendLength = 0;
            while (length) {
                sendLength = length;
                if (length > _MTU)
                    sendLength = _MTU;
                
                NSData *tmpData = [data subdataWithRange:NSMakeRange(offset, sendLength)];
                [weakself.peripheral writeValue:tmpData
                          forCharacteristic:characteristic
                                       type:weakself.ResponseType];
                offset += sendLength;
                length -= sendLength;
            }
        }
    });
    return YES;
}


//发送接收(同步),返回的字典包含"data"和"error"字段
-(NSDictionary *_Nullable)sendData:(NSData * _Nonnull)data
                      withWC:(NSString* _Nonnull)writeUUIDString
                      withNC:(NSString* _Nonnull)notifyUUIDString
                     timeout:(double)timeInterval
{
    //创建信号量
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block NSMutableDictionary * result = [[NSMutableDictionary alloc] init];
    //初始化一个错误值
    result[@"error"] = [NSError errorWithDomain:@"com.zhangbh.SimpleBLEKit" code:5 userInfo:@{@"info":@"通讯超时，设备没有响应"}];
    [self sendData:data withWC:writeUUIDString withNC:notifyUUIDString timeout:timeInterval receiveData:^(NSData * _Nullable outData, NSError * _Nullable error) {
        
        result[@"data"] = outData;
        result[@"error"] = error;
        dispatch_semaphore_signal(sem);//释放信号量
    }];
    //这里一直等待，直到超时
    dispatch_time_t waitTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeInterval+0.5) * NSEC_PER_SEC));
    dispatch_semaphore_wait(sem, waitTime);
    return result;
}

//发送接收(异步)
-(void)sendData:(NSData * _Nonnull)data
         withWC:(NSString* _Nonnull)writeUUIDString
         withNC:(NSString* _Nonnull)notifyUUIDString
        timeout:(double)timeInterval
    receiveData:(receiveDataBlock _Nonnull)callback
{
    //1. 检查工作状态
    //2. 设置工作状态
    //3. 释放工作状态
    NSNumber *isWorking = _workingStatusDict[notifyUUIDString];
    if(isWorking!=nil && [isWorking boolValue]==YES){
        if(_isLog) NSLog(@"通讯正在忙");
        callback(nil,[NSError errorWithDomain:@"com.zhangbh.SimpleBLEKit" code:1 userInfo:@{@"info":@"通讯正在忙，请等待操作完成后再试"}]);
        return;
    }
    _workingStatusDict[notifyUUIDString] = [NSNumber numberWithBool:YES];
    
    __weak typeof(self) weakself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [weakself.dataDescription clearData:notifyUUIDString];
        
        CBCharacteristic* characteristic = [weakself.Characteristics objectForKey:notifyUUIDString];
        if (characteristic ==nil) {
            //通知特征为nil，可能外设SimplePeripheral找不到此特征
            if(weakself.isLog) NSLog(@"可订阅特征【%@】 找不到",notifyUUIDString);
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(nil,[NSError errorWithDomain:@"com.zhangbh.SimpleBLEKit" code:2 userInfo:@{@"info":@"订阅特征找不到"}]);
            });
            _workingStatusDict[notifyUUIDString] = [NSNumber numberWithBool:NO];
            return;
        }else if ((characteristic.properties & CBCharacteristicPropertyNotify) == CBCharacteristicPropertyNotify && characteristic.isNotifying == NO) {
            [weakself.peripheral setNotifyValue:YES forCharacteristic:characteristic];
            usleep(100000);
        }
        [_NotifyUUIDStringAndBlockDict setValue:callback forKey:notifyUUIDString];
        
        if([weakself sendData:data withWC:writeUUIDString]==NO){
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(nil,[NSError errorWithDomain:@"com.zhangbh.SimpleBLEKit" code:3 userInfo:@{@"info":@"写入特征找不到"}]);
            });
            _workingStatusDict[notifyUUIDString] = [NSNumber numberWithBool:NO];
            return;
        }
        
        if (timeInterval<=0) {
            if(weakself.isLog) NSLog(@"超时时间未设置");
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(nil,[NSError errorWithDomain:@"com.zhangbh.SimpleBLEKit" code:4 userInfo:@{@"info":@"超时时间必须大于0"}]);
            });
            _workingStatusDict[notifyUUIDString] = [NSNumber numberWithBool:NO];
            return;
        }
        
        
        //NSTimer只能在主队列建立
        dispatch_async(dispatch_get_main_queue(), ^{
            NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:timeInterval repeats:NO block:^(NSTimer * _Nonnull selfTimer) {
                if(weakself.isLog) NSLog(@"定时器触发");
                callback(nil,[NSError errorWithDomain:@"com.zhangbh.SimpleBLEKit" code:5 userInfo:@{@"info":@"通讯超时，设备没有响应"}]);
                _workingStatusDict[notifyUUIDString] = [NSNumber numberWithBool:NO];
                
                NSTimer *timer = [_NotifyUUIDStringAndNSTimerDict objectForKey:notifyUUIDString];
                if ([timer isValid]) {
                    [timer invalidate];//关闭定时器
                    [_NotifyUUIDStringAndNSTimerDict removeObjectForKey:notifyUUIDString];
                }
            }];
            [_NotifyUUIDStringAndNSTimerDict setValue:timer forKey:notifyUUIDString];
        });
    });
}

#pragma mark 只订阅通知，不发送数据
//开始不断监听数据更新
-(void)startListenWithNC:(NSString* _Nonnull)notifyUUIDString updateDataBlock:(updateDataBlock _Nullable)callback
{
    CBCharacteristic* characteristic = [_Characteristics objectForKey:notifyUUIDString];
    if (characteristic ==nil || !characteristic.isNotifying) {
        if(_isLog) NSLog(@"%@ 找不到或者不具备通知属性",notifyUUIDString);
        return;
    }
    [_continueNotifyUUIDStringAndBlockDict setValue:callback forKey:notifyUUIDString];
    return;
}

//停止监听数据更新 (如果想用发送接收方法，刚好notify的UUID和这个一样，需要停止监听)
-(void)stopListenwithNC:(NSString* _Nonnull)notifyUUIDString
{
    [_continueNotifyUUIDStringAndBlockDict removeObjectForKey:notifyUUIDString];
    return;
}


#pragma mark 读取特征的描述文字

-(NSString *)readCharacteristicsDescriptors:(NSString *)characteristicUUID{
    return _DescriptionDict[characteristicUUID];
}

#pragma mark  - BLEManager会调用此外设的method

//发起连接的回调结果
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{

    // Clear the data that we may already have
    if(_isLog) NSLog(@"设备连接正常，开始搜索服务...");
    
//    [self setPeripheral:peripheral];已经持有，不再需要引用
    // Make sure we get the discovery callbacks
    self.peripheral.delegate = self; //实现CBPeripheralDelegate的方法
    
    if(_serviceAndCharacteristicsDictionary==nil){
        [self.peripheral discoverServices:nil];
    }else{
        NSMutableArray<CBUUID *> *servicesArray = [[NSMutableArray alloc] init];
        for (NSString *key in _serviceAndCharacteristicsDictionary) {
            [servicesArray addObject:[CBUUID UUIDWithString:key]];
        }
        [self.peripheral discoverServices:servicesArray];
    }
}

//发起连接的回调结果(假设远端蓝牙关闭电源，自动连接时可能报这个错)
- (void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)aPeripheral
                  error:(NSError *)error
{
    if(_isLog) NSLog(@"设备连接异常:\n %@",error);
    __weak typeof(self) weakself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if(weakself.MyStatusBlock!=nil)
            weakself.MyStatusBlock(NO);
    });
    return;
}

//（主动被动）断开连接的回调结果（主动==【调用cancel接口、系统蓝牙关闭】、被动==【远端蓝牙关闭】）
- (void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral
                  error:(NSError *)error
{
    if (error==nil) {
        if(_isLog) NSLog(@"iOS设备主动断开连接或者ios设备关闭蓝牙");
    }else{
        if(_isLog) NSLog(@"远端蓝牙外设断开连接,可能不在通讯范围内或者外设关闭蓝牙");
        // We're disconnected, so start scanning again
        if(_isAutoReconnect){
            if(_isLog) NSLog(@"准备自动重连");
            [self.centralManager connectPeripheral:_peripheral options:nil];
        }
    }
    
    //取消所有定时器,移除所有定时器
    for (NSTimer * timer in [_NotifyUUIDStringAndNSTimerDict allValues]) {
        if ([timer isValid]) {
            [timer invalidate];
        }
    }
    
    //clear
    _ServicesCount = 0;
    _CharacteristicsCount = 0;
    [_Services removeAllObjects];
    [_Characteristics removeAllObjects];
    [_workingStatusDict removeAllObjects];
    [_DescriptionDict removeAllObjects];
    [_NotifyUUIDStringAndBlockDict removeAllObjects];
    [_NotifyUUIDStringAndNSTimerDict removeAllObjects];
    
    __weak typeof(self) weakself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if(weakself.MyStatusBlock!=nil)
            weakself.MyStatusBlock(NO);
    });
}



#pragma mark - CBPeripheralDelegate methods

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        if(_isLog) NSLog(@"搜索服务时发生错误:\n %@",error);
        //主动断开设备连接
        [self disconnect];
        return;
    }
    
    if(_serviceAndCharacteristicsDictionary==nil){
        for (CBService *service in peripheral.services) {
            NSString *UUIDString = [service.UUID UUIDString];
            [_Services setValue:service forKey:UUIDString];
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }else{
        
        if ([peripheral.services count]!=[_serviceAndCharacteristicsDictionary count]) {
            if(_isLog) NSLog(@"搜索到的服务数量不符合预期:\n%@",[peripheral.services description]);
            //主动断开设备连接
            [self disconnect];
            return;
        }
        
        
        for (CBService *service in peripheral.services) {
            NSString *UUIDString = [service.UUID UUIDString];
            [_Services setValue:service forKey:UUIDString];
            NSArray<NSString *> *characteristicArray = [_serviceAndCharacteristicsDictionary objectForKey:UUIDString];
            NSMutableArray<CBUUID *> *characteristicCBUUIDArray = [[NSMutableArray alloc] init];
            for (NSString *key in characteristicArray) {
                [characteristicCBUUIDArray addObject:[CBUUID UUIDWithString:key]];
            }
            [peripheral discoverCharacteristics:characteristicCBUUIDArray forService:service];
            _CharacteristicsCount += [characteristicCBUUIDArray count];
        }
    }
    
    
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error
{
    if (error) {

        if(_isLog) NSLog(@"搜索服务的特征时发生错误:\n %@",error);
        //主动断开设备连接
        [self disconnect];
        return;
    }
    NSString *UUIDString = [service.UUID UUIDString];
    if(_isLog) NSLog(@"└┈┈搜索到的服务UUID: %@", UUIDString);
    
    
    if (_serviceAndCharacteristicsDictionary==nil) {
        
        _ServicesCount++;
        for (CBCharacteristic *characteristic in service.characteristics){
            
            if(_isLog) NSLog(@"   └┈┈特征UUID: %@",[characteristic.UUID UUIDString]);
//            if ((characteristic.properties & CBCharacteristicPropertyNotify) == CBCharacteristicPropertyNotify && characteristic.isNotifying == NO) {
//                [self.peripheral setNotifyValue:YES forCharacteristic:characteristic];
//            }
            [_Characteristics setValue:characteristic forKey:[characteristic.UUID UUIDString]];
            
            if(_isReadDescriptors){
                [self.peripheral discoverDescriptorsForCharacteristic:characteristic];
            }
        }
        
        if (_ServicesCount == [_Services count]) {
            //通知成功前，提前做一些事情
            if(_AfterConnectedDoSomething)
                _AfterConnectedDoSomething();
            
            if(_isLog) NSLog(@"连接成功！！！当前连接设备为:%@",_peripheral.name);
            __weak typeof(self) weakself = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                if(weakself.MyStatusBlock!=nil)
                    weakself.MyStatusBlock(YES);
            });
        }
        
    }else{
        
        if ([service.characteristics count]!=[[_serviceAndCharacteristicsDictionary objectForKey:UUIDString] count]) {
            if(_isLog) NSLog(@"搜索到的特征数量不符合预期:\n%@",[service.characteristics description]);
            //主动断开设备连接
            [self disconnect];
            return;
        }
        
        for (CBCharacteristic *characteristic in service.characteristics){
            
            if(_isLog) NSLog(@"   └┈┈特征UUID: %@",[characteristic.UUID UUIDString]);
            
//            if ((characteristic.properties & CBCharacteristicPropertyNotify) == CBCharacteristicPropertyNotify && characteristic.isNotifying == NO) {
//                [self.peripheral setNotifyValue:YES forCharacteristic:characteristic];
//            }
            [_Characteristics setValue:characteristic forKey:[characteristic.UUID UUIDString]];
            
            if(_isReadDescriptors){
                [self.peripheral discoverDescriptorsForCharacteristic:characteristic];
            }
        }
        
        if ([_Characteristics count] == _CharacteristicsCount) {//结束搜索特征
            //通知成功前，提前做一些事情
            if(_AfterConnectedDoSomething)
                _AfterConnectedDoSomething();
            
            if(_isLog) NSLog(@"连接成功！！！当前连接设备为:%@",_peripheral.name);
            __weak typeof(self) weakself = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                if(weakself.MyStatusBlock!=nil)
                    weakself.MyStatusBlock(YES);
            });
        }
    }
}


-(void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (error) {
        if(_isLog) NSLog(@"读特征的描述文字时发生错误:\n %@",error);
        return;
    }
    
    //把描述文字添加到字典
    [_DescriptionDict setValue:[[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding] forKey:[characteristic.UUID UUIDString]];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        if(_isLog) NSLog(@"读特征收到数据时发生错误:\n %@",error);
        return;
    }
    
    NSString *uuidString = [characteristic.UUID UUIDString];
    if(_isLog) {
        NSLog(@"%@特征收到数据:%@",uuidString,characteristic.value);
    }

    updateDataBlock updateCallback = [_continueNotifyUUIDStringAndBlockDict objectForKey:uuidString];
    receiveDataBlock receiveCallback = [_NotifyUUIDStringAndBlockDict objectForKey:uuidString];
    if (updateCallback !=nil && [_workingStatusDict[uuidString] boolValue]==NO) {
        updateCallback(characteristic.value);
    }else{
        [_dataDescription appendData:characteristic.value uuid:uuidString];//这里不断收集数据。发送接收用
        if(_isLog) {
            NSLog(@"数据长度总长:%ld",(unsigned long)[[_dataDescription getPacketData:uuidString] length]);
        }
        
        if([_dataDescription isValidPacket:uuidString]){//如果收包完整
            
            //关闭定时器，从定时器池中移除定时器
            NSTimer *timer = [_NotifyUUIDStringAndNSTimerDict objectForKey:uuidString];
            if (timer!=nil) {
                if ([timer isValid]) {
                    [timer invalidate];//关闭定时器
                    timer = nil;
                    [_NotifyUUIDStringAndNSTimerDict removeObjectForKey:uuidString];
                }
                receiveCallback([_dataDescription getPacketData:uuidString],nil);
                _workingStatusDict[uuidString] = [NSNumber numberWithBool:NO];//更改状态
            }else{
                NSLog(@"超时后收到的数据，宝宝只能舍弃了");
            }
            
            //移除回调方法
            [_NotifyUUIDStringAndBlockDict removeObjectForKey:uuidString];
            
            return;
        }
    }
    
    if (_AckData!=nil && _AckWriteCharacteristicUUIDString!=nil && [_dataDescription isNeedToACK:uuidString]) {
        
        __weak typeof(self) weakself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [weakself.peripheral writeValue:weakself.AckData
                      forCharacteristic:[weakself.Characteristics objectForKey:weakself.AckWriteCharacteristicUUIDString]
                                   type:weakself.ResponseType];
            if(weakself.isLog) NSLog(@"宝宝赶紧回了一个应答:%@",weakself.AckData);
        });
    };
}


#pragma mark - 基本没什么用的方法

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    if (error) {
        if(_isLog) NSLog(@"发送数据时出错:%@",error);
        return;
    }
    if(_isLog) NSLog(@"特征%@成功发送:%@",[characteristic.UUID UUIDString],characteristic.value);
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    
    if (error) {
        if(_isLog) NSLog(@"设置或取消监听特征时发生错误:%@",error);
        return;
    }
    // Notification has started
    if(_isLog) NSLog(@"%@%@",[characteristic.UUID UUIDString],characteristic.isNotifying?@"订阅成功,监听数据中...":@"取消订阅成功");
}


-(NSTimeInterval)currentTimeSeconds
{
    return [[NSDate date] timeIntervalSince1970];
}
@end
