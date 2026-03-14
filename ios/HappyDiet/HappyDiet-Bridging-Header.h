//
//  HappyDiet-Bridging-Header.h
//  HappyDiet
//
//  Bridging header for Objective-C (QCSDK + HeyCyan BLE).
//  When HEYCYAN_SDK_LINKED: full BLE. Otherwise: Camera/Photo/WiFi only.
//

#if defined(HEYCYAN_SDK_LINKED) && HEYCYAN_SDK_LINKED
#import <QCSDK/QCSDK.h>
#import <QCSDK/QCDFU_Utils.h>
#import "QCCentralManager.h"
#import "QCScanViewController.h"
#endif
