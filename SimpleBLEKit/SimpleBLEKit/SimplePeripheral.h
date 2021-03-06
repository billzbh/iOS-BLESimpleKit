//
//  SimplePeripheral.h
//  SimpleBLEKit
//
//  Created by zbh on 17/3/14.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "SimpleBLEKitTypeDef.h"

@interface SimplePeripheral : NSObject

#pragma mark - 必须的操作方法

//一簇设置收包完整规则的方法（二选一），默认收到数据就认为包完整。需要根据自己的需要自定义
//收包完整规则尽量不要太复杂，执行时间越短越好
-(void)setPacketVerifyEvaluator:(PacketVerifyEvaluator _Nullable)packetEvaluator;
-(void)setResponseMatch:(NSString* _Nonnull)prefixString
           sufferString:(NSString* _Nonnull)sufferString
     NSDataExpectLength:(int)expectLen;


#pragma mark - 通讯方法
//1. 只发送
//2. 发送接收(同步)
//3. 发送接收(异步)
//只发送
-(BOOL)sendData:(NSData * _Nonnull)data withWC:(NSString* _Nonnull)writeUUIDString;

//发送接收(同步),返回的字典包含"data"和"error"字段
-(NSDictionary *_Nonnull)sendData:(NSData * _Nonnull)data
                            withWC:(NSString* _Nonnull)writeUUIDString
                            withNC:(NSString* _Nonnull)notifyUUIDString
                           timeout:(double)timeInterval;
//发送接收(异步)
-(void)sendData:(NSData * _Nonnull)data
         withWC:(NSString* _Nonnull)writeUUIDString
         withNC:(NSString* _Nonnull)notifyUUIDString
        timeout:(double)timeInterval
    receiveData:(receiveDataBlock _Nonnull)callback;


#pragma mark 只订阅通知，不发送数据
//开始不断监听数据更新
-(void)startListenWithNC:(NSString* _Nonnull)notifyUUIDString updateDataBlock:(updateDataBlock _Nullable)callback;
//停止监听数据更新
-(void)stopListenwithNC:(NSString* _Nonnull)notifyUUIDString;

#pragma mark 间隔时间内读取一次当前的RSSI值
//timeInterval <=0                        直接读取RSSI
//timeInterval > 0                        直接读取一次RSSI，延迟timeInterval秒后再次读取一次RSSI
//timeInterval > 0 && isRepeat==YES       直接读取一次RSSI，直接每间隔timeInterval秒后再次读取一次RSSI
-(void)readRSSI:(double)timeInterval repeats:(BOOL)isRepeat callback:(readRSSIBlock _Nonnull)callback;
//对应 readRSSI，如果启动间隔方式读取RSSI，不需要的时候取消定时器
-(void)cancelReadRSSITimer;


#pragma mark - 常用方法
//蓝牙名称
-(NSString* _Nonnull)getPeripheralName;
//查询是否已连接
-(BOOL)isConnected;

#pragma mark - 如果不需要用到相关功能，请不要设置这些方法
//是否打开日志打印，默认是NO
-(void)setIsLog:(BOOL)isLog;
//是否断开后自动重连，默认是YES
-(void)setIsAutoReconnect:(BOOL)isAutoReconnect;
//设置写数据的通知类型,默认是CBCharacteristicWriteWithoutResponse
-(void)setResponseType:(CBCharacteristicWriteType)ResponseType;
//设置是否分包发送。大于0，则按照数值分包。小于0，则不分包。默认是不分包
-(void)setMTU:(int)MTU;
//设置要搜索的服务和特征，加快连接速度
//格式: @{service1:@[characterist1,characterist2],service2:@[characterist3,characterist4]}
-(void)setServiceAndCharacteristicsDictionary:(NSDictionary * _Nullable)dict;
//报告成功连接前，可以预先做一些事情
-(void)setupDeviceAfterConnected:(setupAfterConnected _Nullable)setupAfterConnectedBlock;

#pragma mark  应答设置方法
//设置是否收到数据后回给蓝牙设备应答数据，自定义应答数据和应答规则。默认不应答
//应答规则的执行时间越短越好
-(void)setAckData:(NSData* _Nullable)data withWC:(NSString * _Nullable)writeUUIDString
 withACKEvaluator:(NeekAckEvaluator _Nullable)ackEvaluator;

@end
