//
//  QCCentralManager.m
//  HappyDiet - from ebowwa/HeyCyanSmartGlassesSDK
//

#import "QCCentralManager.h"
#import <QCSDK/QCSDK.h>

static NSString *const QCLastConnectedIdentifier = @"QCLastConnectedIdentifier";
static NSInteger const QCBleDefaultTimeout = 15;
static NSInteger const QCBleDefaultConnectTimeout = 6;

@implementation QCBlePeripheral
@end

@interface QCCentralManager () <CBCentralManagerDelegate>
@property (strong, nonatomic) CBCentralManager *centerManager;
@property (strong, nonatomic) NSMutableArray<QCBlePeripheral *> *peripherals;
@property (strong, nonatomic) CBPeripheral *connectedPeripheral;
@property (nonatomic, copy) void (^connectCompletedHandle)(BOOL);
@property (nonatomic, strong) NSTimer *reconTimer;
@property (assign, nonatomic) QCDeviceType deviceType;
@property (assign, nonatomic) QCState deviceState;
@property (assign, nonatomic) QCBluetoothState bleState;
@property (assign, nonatomic) NSInteger scanTimeout;
@property (assign, nonatomic) NSInteger connectTimeout;
@end

@implementation QCCentralManager

+ (instancetype)shared {
    static QCCentralManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[QCCentralManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSDictionary *options = @{
            CBCentralManagerOptionShowPowerAlertKey: @YES,
            CBConnectPeripheralOptionNotifyOnConnectionKey: @YES,
            CBCentralManagerOptionRestoreIdentifierKey: @"QCWXBluetoothRestore"
        };
        _centerManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:options];
        _peripherals = [NSMutableArray array];
        _scanTimeout = QCBleDefaultTimeout;
        _connectTimeout = QCBleDefaultConnectTimeout;
    }
    return self;
}

- (void)setDeviceState:(QCState)deviceState {
    _deviceState = deviceState;
    if (self.delegate && [self.delegate respondsToSelector:@selector(didState:)]) {
        [self.delegate didState:self.deviceState];
    }
}

- (void)scan {
    [self scanWithTimeout:QCBleDefaultTimeout];
}

- (void)scanWithTimeout:(NSInteger)timeout {
    self.scanTimeout = timeout;
    [self stopScan];
    [self.peripherals removeAllObjects];

    NSArray<CBUUID *> *uuids = @[[CBUUID UUIDWithString:QCSDKSERVERUUID1], [CBUUID UUIDWithString:QCSDKSERVERUUID2]];
    NSArray *connectedP = [self retrieveConnectPeripheral:uuids];
    for (CBPeripheral *per in connectedP) {
        QCBlePeripheral *qcPer = [[QCBlePeripheral alloc] init];
        qcPer.peripheral = per;
        qcPer.mac = @"";
        qcPer.isPaired = YES;
        [self.peripherals addObject:qcPer];
    }

    if (connectedP.count > 0 && self.delegate && [self.delegate respondsToSelector:@selector(didScanPeripherals:)]) {
        [self.delegate didScanPeripherals:self.peripherals];
    }

    NSDictionary *option = @{CBCentralManagerScanOptionAllowDuplicatesKey: @NO};
    [_centerManager scanForPeripheralsWithServices:nil options:option];

    [self stopTimer];
    self.reconTimer = [NSTimer scheduledTimerWithTimeInterval:self.scanTimeout target:self selector:@selector(stopScanFinishTimer:) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:self.reconTimer forMode:NSRunLoopCommonModes];
}

- (void)stopScan {
    if (_centerManager) {
        [_centerManager stopScan];
    }
    if (self.reconTimer && [self.reconTimer isValid]) {
        [self.reconTimer invalidate];
        self.reconTimer = nil;
    }
}

- (void)connect:(CBPeripheral *)peripheral {
    [self connect:peripheral deviceType:QCDeviceTypeGlasses];
}

- (void)connect:(CBPeripheral *)peripheral deviceType:(QCDeviceType)deviceType {
    [self connect:peripheral timeout:QCBleDefaultConnectTimeout deviceType:deviceType];
}

- (void)connect:(CBPeripheral *)peripheral timeout:(NSInteger)timeout {
    [self connect:peripheral timeout:timeout deviceType:QCDeviceTypeGlasses];
}

- (void)connect:(CBPeripheral *)peripheral timeout:(NSInteger)timeout deviceType:(QCDeviceType)deviceType {
    self.connectTimeout = timeout;
    self.deviceType = deviceType;
    self.connectedPeripheral = peripheral;

    [self stopTimer];
    [self connectCurrentPeripheral];
    self.reconTimer = [NSTimer scheduledTimerWithTimeInterval:self.connectTimeout target:self selector:@selector(stopConnectFinishTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.reconTimer forMode:NSRunLoopCommonModes];
}

- (void)connectCurrentPeripheral {
    CBPeripheral *lastPer = [self lastPeripheral];
    if (!lastPer) return;
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    options[CBConnectPeripheralOptionNotifyOnDisconnectionKey] = @YES;
    if (@available(iOS 13.0, *)) {
        options[CBConnectPeripheralOptionEnableTransportBridgingKey] = @YES;
        if (self.deviceType != QCDeviceTypeRing) {
            options[CBConnectPeripheralOptionRequiresANCS] = @YES;
        }
    }
    [_centerManager connectPeripheral:lastPer options:options];
}

- (void)remove {
    [self stopTimer];
    if (self.connectedPeripheral) {
        @try {
            [_centerManager cancelPeripheralConnection:self.connectedPeripheral];
        } @catch (NSException *e) {
            NSLog(@"QCCentralManager: cancel connection exception");
        }
    }
    [[QCSDKManager shareInstance] removeAllPeripheral];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:QCLastConnectedIdentifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.deviceState = QCStateDisconnecting;
}

- (void)startToReconnect {
    if (self.bleState != QCBluetoothStatePoweredOn) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didFailConnected:error:)]) {
            [self.delegate didFailConnected:self.connectedPeripheral error:[NSError errorWithDomain:@"Bluetooth" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Bluetooth powered off"}]];
        }
        return;
    }
    CBPeripheral *lastPer = [self lastPeripheral];
    if (lastPer) {
        [self connect:lastPer];
    } else if (self.delegate && [self.delegate respondsToSelector:@selector(didFailConnected:error:)]) {
        [self.delegate didFailConnected:self.connectedPeripheral error:[NSError errorWithDomain:@"Bluetooth" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Device not found"}]];
    }
}

- (CBPeripheral *)lastPeripheral {
    if (self.connectedPeripheral) return self.connectedPeripheral;
    NSString *uuidStr = [[NSUserDefaults standardUserDefaults] objectForKey:QCLastConnectedIdentifier];
    if (uuidStr.length > 0) return [self periperalWithUUID:uuidStr];
    return nil;
}

#pragma mark - CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    QCBluetoothState bleState = QCBluetoothStateUnkown;
    switch (central.state) {
        case CBManagerStateUnknown: bleState = QCBluetoothStateUnkown; break;
        case CBManagerStateResetting: bleState = QCBluetoothStateResetting; break;
        case CBManagerStateUnsupported: bleState = QCBluetoothStateUnsupported; break;
        case CBManagerStatePoweredOff: bleState = QCBluetoothStatePoweredOff; break;
        case CBManagerStatePoweredOn: bleState = QCBluetoothStatePoweredOn; break;
        default: break;
    }
    _bleState = bleState;
    if (self.delegate && [self.delegate respondsToSelector:@selector(didBluetoothState:)]) {
        [self.delegate didBluetoothState:bleState];
    }
    self.deviceState = [self isBindDevice] ? QCStateConnecting : QCStateUnbind;
    if (bleState == QCBluetoothStatePoweredOn && self.deviceState == QCStateConnecting) {
        [self startToReconnect];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if (peripheral.name.length == 0) return;
    NSString *mac = [self macFromAdvertisementData:advertisementData];
    for (QCBlePeripheral *per in self.peripherals) {
        if ([per.peripheral.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString]) {
            per.peripheral = peripheral;
            per.mac = mac;
            per.advertisementData = advertisementData;
            per.RSSI = RSSI;
            if (self.delegate && [self.delegate respondsToSelector:@selector(didScanPeripherals:)]) {
                [self.delegate didScanPeripherals:self.peripherals];
            }
            return;
        }
    }
    QCBlePeripheral *per = [[QCBlePeripheral alloc] init];
    per.peripheral = peripheral;
    per.mac = mac;
    per.advertisementData = advertisementData;
    per.RSSI = RSSI;
    [self.peripherals addObject:per];
    if (self.delegate && [self.delegate respondsToSelector:@selector(didScanPeripherals:)]) {
        [self.delegate didScanPeripherals:self.peripherals];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [self stopTimer];
    [[QCSDKManager shareInstance] removePeripheral:peripheral];
    [[QCSDKManager shareInstance] addPeripheral:peripheral finished:^(BOOL success) {
        if (success) {
            [[NSUserDefaults standardUserDefaults] setValue:peripheral.identifier.UUIDString forKey:QCLastConnectedIdentifier];
            [[NSUserDefaults standardUserDefaults] synchronize];
            self.deviceState = QCStateConnected;
        } else if (self.delegate && [self.delegate respondsToSelector:@selector(didFailConnected:error:)]) {
            [self.delegate didFailConnected:peripheral error:[NSError errorWithDomain:@"QCSDK" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Add peripheral failed"}]];
        }
    }];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (self.deviceState == QCStateDisconnecting) {
        self.deviceState = QCStateUnbind;
    } else {
        [[QCSDKManager shareInstance] removeAllPeripheral];
        self.deviceState = QCStateConnecting;
        [self startToReconnect];
    }
}

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary *)dict {
    NSArray *peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey];
    if (peripherals.count > 0) {
        NSString *uuidStr = [[NSUserDefaults standardUserDefaults] objectForKey:QCLastConnectedIdentifier];
        if (uuidStr.length > 0) {
            for (CBPeripheral *pr in peripherals) {
                if ([uuidStr isEqualToString:pr.identifier.UUIDString]) {
                    self.connectedPeripheral = pr;
                    break;
                }
            }
        }
    }
}

#pragma mark - Helpers
- (NSArray *)retrieveConnectPeripheral:(NSArray<CBUUID *> *)uuidArray {
    NSArray *connectedDevice = [_centerManager retrieveConnectedPeripheralsWithServices:uuidArray];
    NSMutableArray *result = [NSMutableArray array];
    for (id obj in connectedDevice) {
        if ([obj isKindOfClass:[CBPeripheral class]]) [result addObject:obj];
    }
    return [result copy];
}

- (CBPeripheral *)periperalWithUUID:(NSString *)uuid {
    if (!uuid.length) return nil;
    NSUUID *UUID = [[NSUUID alloc] initWithUUIDString:uuid];
    if (!UUID) return nil;
    NSArray *peripherals = [_centerManager retrievePeripheralsWithIdentifiers:@[UUID]];
    return peripherals.count > 0 ? peripherals.firstObject : nil;
}

- (NSString *)macFromAdvertisementData:(NSDictionary *)advertisementData {
    NSString *mac = @"";
    NSData *manufacturerData = advertisementData[@"kCBAdvDataManufacturerData"];
    mac = [self macFromData:manufacturerData];
    if (mac.length == 0) {
        NSDictionary *serviceData = advertisementData[@"kCBAdvDataServiceData"];
        if ([serviceData isKindOfClass:[NSDictionary class]]) {
            for (id dataValue in [serviceData allValues]) {
                if ([dataValue isKindOfClass:[NSData class]]) {
                    mac = [self macFromData:dataValue];
                    if (mac.length > 0) break;
                }
            }
        }
    }
    return mac;
}

- (NSString *)macFromData:(NSData *)macData {
    if (![macData isKindOfClass:[NSData class]] || macData.length == 0) return @"";
    NSData *data = macData;
    Byte *bytes = (Byte *)data.bytes;
    if (data.length >= 10) {
        data = [data subdataWithRange:NSMakeRange(4, 6)];
        bytes = (Byte *)data.bytes;
    } else if (data.length == 8) {
        data = [data subdataWithRange:NSMakeRange(2, 6)];
        bytes = (Byte *)data.bytes;
    } else if (data.length < 6) {
        return @"";
    }
    return [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x", bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]];
}

- (BOOL)isBindDevice {
    NSString *uuidStr = [[NSUserDefaults standardUserDefaults] objectForKey:QCLastConnectedIdentifier];
    return [uuidStr isKindOfClass:[NSString class]] && uuidStr.length > 0;
}

- (void)stopTimer {
    if (self.reconTimer && [self.reconTimer isValid]) {
        [self.reconTimer invalidate];
        self.reconTimer = nil;
    }
}

- (void)stopConnectFinishTimer:(NSTimer *)timer {
    [self stopTimer];
    if (self.delegate && [self.delegate respondsToSelector:@selector(didFailConnected:error:)]) {
        [self.delegate didFailConnected:self.connectedPeripheral error:[NSError errorWithDomain:@"QCSDK" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Connection timeout"}]];
    }
}

- (void)stopScanFinishTimer:(NSTimer *)timer {
    [self stopScan];
    if (self.delegate && [self.delegate respondsToSelector:@selector(scanPeripheralFinish)]) {
        [self.delegate scanPeripheralFinish];
    }
}

@end
