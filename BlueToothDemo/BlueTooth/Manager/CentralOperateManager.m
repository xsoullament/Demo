//
//  CentralOperateManager.m
//  BlueTooth
//
//  Created by Kangqj on 15/11/2.
//  Copyright © 2015年 Kangqj. All rights reserved.
//

#import "CentralOperateManager.h"

@interface CentralOperateManager ()
{
    
}

@property(nonatomic, strong) CBCentralManager *centralManager;
@property(nonatomic, strong) CBCharacteristic *writeCharacteristic;
@property(nonatomic, strong) NSTimer          *timer;


@end

@implementation CentralOperateManager

@synthesize curPeripheral;

+ (CentralOperateManager *)sharedManager
{
    static CentralOperateManager *instance = nil;
    static dispatch_once_t predicate;
    
    dispatch_once(&predicate, ^{
        instance = [[self alloc] init];
    });
    
    return instance;
}

- (id)init
{
    if (self)
    {
        self = [super init];
        
    }
    
    return self;
}

- (void)scanPeripheralSignal:(FindSignalBlock)block;
{
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    self.findSignalBlock = block;
}

- (void)connectPeripheral
{
    [self.centralManager connectPeripheral:self.curPeripheral options:nil];
    //@{CBConnectPeripheralOptionNotifyOnDisconnectionKey:@YES}
}

- (void)disconnectPeripheral
{
    [self.centralManager cancelPeripheralConnection:self.curPeripheral];
}

- (void)stopScanSign
{
    [self.centralManager stopScan];
    
    self.centralManager.delegate = nil;
    self.centralManager = nil;
}


- (void)getRSSIData:(RSSIDataBlock)rssi
{
    self.rssieBlock = rssi;
}

- (float)calcDistByRSSI:(int)rssi
{
    int iRssi = abs(rssi);
    float power = (iRssi-59)/(10*2.0);
    return pow(10, power);
}


- (void)reciveData:(ReceiveDataBlock)receive
{
    self.receiveBlock = receive;
}


- (void)sendData:(NSString *)string
{
    if (self.writeCharacteristic)
    {
        NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
        [self.curPeripheral writeValue:data forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithResponse];
    }
}

#pragma mark CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state)
    {
        case CBCentralManagerStatePoweredOn:
            
            [self.centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@NO}];//已发现的设备是否重复扫描
            
            break;
            
        default:
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    self.findSignalBlock(peripheral);
    
    [self.centralManager stopScan];
    
    if (self.curPeripheral != peripheral)
    {
        self.curPeripheral = peripheral;
        
//        [self.centralManager connectPeripheral:self.curPeripheral options:nil];
    }
}


- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    peripheral.delegate = self;
    [peripheral discoverServices:@[[CBUUID UUIDWithString:ServiceUUID]]];
    
    if (self.timer)
    {
        [self.timer invalidate];
        self.timer = nil;
    }
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                  target:peripheral
                                                selector:@selector(readRSSI)
                                                userInfo:nil
                                                 repeats:YES];
//    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    
}

#pragma mark CBPeripheralDelegate
- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
    if (!error)
    {
        if (self.rssieBlock)
        {
            self.rssieBlock([[peripheral RSSI] intValue]);
            
            if ([[peripheral RSSI] intValue] > -36)
            {
                [self sendData:BumpKey];
            }
        }
        
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (!error)
    {
        for (CBService *service in peripheral.services)
        {
            NSLog(@"Service found with UUID: %@",service.UUID);
            [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:CharacteristicUUID]] forService:service];
        }
    }
    else
    {
        NSLog(@"didDiscoverServices Error:%@", [error localizedDescription]);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error discovering characteristic:%@", [error localizedDescription]);
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        self.writeCharacteristic = characteristic;
        
        [peripheral readValueForCharacteristic:characteristic];
        [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        [peripheral discoverDescriptorsForCharacteristic:characteristic];
        
        [self sendData:BumpKey];
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSData *imageData = characteristic.value;
    if (self.receiveBlock)
    {
        self.receiveBlock(imageData);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error changing notification state:%@", error.localizedDescription);
    }
    
    if (characteristic.isNotifying)
    {
        NSLog(@"Notification began on %@", characteristic);
        [peripheral readValueForCharacteristic:characteristic];
    }
    else
    {
        NSLog(@"Notification stopped on %@.Disconnecting", characteristic);
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    
    
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
{
    
}

//写数据回调
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    
}

//设置通知
-(void)notifyCharacteristic:(CBPeripheral *)peripheral
             characteristic:(CBCharacteristic *)characteristic{
    //设置通知，数据通知会进入：didUpdateValueForCharacteristic方法
    [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    
}

//取消通知
-(void)cancelNotifyCharacteristic:(CBPeripheral *)peripheral
                   characteristic:(CBCharacteristic *)characteristic{
    
    [peripheral setNotifyValue:NO forCharacteristic:characteristic];
}

//停止扫描并断开连接
-(void)disconnectPeripheral:(CBCentralManager *)centralManager
                 peripheral:(CBPeripheral *)peripheral{
    //停止扫描
    [centralManager stopScan];
    //断开连接
    [centralManager cancelPeripheralConnection:peripheral];
}

@end