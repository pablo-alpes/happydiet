//
//  QCScanViewController.h
//  HappyDiet - from ebowwa/HeyCyanSmartGlassesSDK
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCScanViewController : UIViewController
- (instancetype)initWithOnDeviceSelected:(nullable void (^)(CBPeripheral *peripheral))onDeviceSelected;
@end

NS_ASSUME_NONNULL_END
