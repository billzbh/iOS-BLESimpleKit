//
//  Typedef.h
//  SimpleBLEKit
//
//  Created by zbh on 17/3/15.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#ifndef Typedef_h_SimpleBLEKit
#define Typedef_h_SimpleBLEKit

@class SimplePeripheral;


#define BLESTATUS_CONNECTED    @"com.SimpleBLEKit.Connected"
#define BLESTATUS_DISCONNECTED @"com.zbh.Disconnected"

typedef void (^SearchBlock)(SimplePeripheral* _Nonnull peripheral);

/**
 发送数据后接受数据的结果回调
 @param outData 有值时表示收到的数据包
 @param error 这里有值表示有错误
 */
typedef void (^receiveDataBlock)(NSData * _Nullable outData,NSError * _Nullable error);

/**
 需要优化为delegate方式
 监听通知后的数据回调
 @param updateData 有值时表示收到的数据包
 */
typedef void (^updateDataBlock)(NSData * _Nullable updateData);

/**
 读取RSSI的值
需要优化为delegate方式
 @param RSSI 有值时表示收到的RSSI值
 */
typedef void (^readRSSIBlock)(NSNumber * _Nullable RSSI);


typedef BOOL (^PacketVerifyEvaluator)(NSData * __nullable inputData);
typedef BOOL (^NeekAckEvaluator)(NSData * __nullable inputData);
typedef void (^setupAfterConnected)(void);

#endif /* Typedef_h_SimpleBLEKit */


