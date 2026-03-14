//
//  QCCentralManager.h
//  HappyDiet - from ebowwa/HeyCyanSmartGlassesSDK
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, QCDeviceType) {
    QCDeviceTypeUnkown = 0,
    QCDeviceTypeWatch,
    QCDeviceTypeRing,
    QCDeviceTypeGlasses,
};

typedef NS_ENUM(NSInteger, QCState) {
    QCStateUnkown = 0,
    QCStateUnbind,
    QCStateConnecting,
    QCStateConnected,
    QCStateDisconnecting,
    QCStateDisconnected,
};

typedef NS_ENUM(NSInteger, QCBluetoothState) {
    QCBluetoothStateUnkown = 0,
    QCBluetoothStateResetting,
    QCBluetoothStateUnsupported,
    QCBluetoothStateUnauthorized,
    QCBluetoothStatePoweredOff,
    QCBluetoothStatePoweredOn,
};

@interface QCBlePeripheral : NSObject
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, copy) NSString *mac;
@property (nonatomic, strong) NSDictionary<NSString *,id> *advertisementData;
@property (nonatomic, strong) NSNumber *RSSI;
@property (nonatomic, assign) BOOL isPaired;
@end

@protocol QCCentralManagerDelegate <NSObject>
@optional
- (void)didState:(QCState)state;
- (void)didBluetoothState:(QCBluetoothState)state;
- (void)didScanPeripherals:(NSArray<QCBlePeripheral *> *)peripheralArr;
- (void)scanPeripheralFinish;
- (void)didFailConnected:(CBPeripheral *)peripheral error:(nullable NSError *)error;
@end

@interface QCCentralManager : NSObject
@property (nonatomic, weak) id<QCCentralManagerDelegate> delegate;
@property (strong, nonatomic, readonly) CBCentralManager *centerManager;
@property (strong, nonatomic, readonly) CBPeripheral *connectedPeripheral;
@property (nonatomic, assign, readonly) QCState deviceState;
@property (nonatomic, assign, readonly) QCBluetoothState bleState;

+ (instancetype)shared;
- (void)scan;
- (void)scanWithTimeout:(NSInteger)timeout;
- (void)stopScan;
- (void)connect:(CBPeripheral *)peripheral;
- (void)connect:(CBPeripheral *)peripheral deviceType:(QCDeviceType)deviceType;
- (void)connect:(CBPeripheral *)peripheral timeout:(NSInteger)timeout;
- (void)connect:(CBPeripheral *)peripheral timeout:(NSInteger)timeout deviceType:(QCDeviceType)deviceType;
- (void)remove;
@end

NS_ASSUME_NONNULL_END
