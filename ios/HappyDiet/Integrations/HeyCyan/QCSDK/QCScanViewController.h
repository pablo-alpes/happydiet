//
//  QCScanViewController.h
//  HappyDiet - from ebowwa/HeyCyanSmartGlassesSDK
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "QCCentralManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface QCScanViewController : UIViewController <QCCentralManagerDelegate>
- (instancetype)initWithOnDeviceSelected:(nullable void (^)(CBPeripheral *peripheral))onDeviceSelected;
@end

NS_ASSUME_NONNULL_END
