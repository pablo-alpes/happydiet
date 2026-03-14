//
//  HappyDiet-Bridging-Header.h
//  HappyDiet
//
//  Bridging header for Objective-C (QCSDK + HeyCyan BLE) and C (network discovery).
//  When HEYCYAN_SDK_LINKED: full BLE. Otherwise: Camera/Photo/WiFi only.
//

#include <ifaddrs.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/socket.h>

#if defined(HEYCYAN_SDK_LINKED) && HEYCYAN_SDK_LINKED
#import <QCSDK/QCSDK.h>
#import <QCSDK/QCDFU_Utils.h>
#import "QCCentralManager.h"
#import "QCScanViewController.h"
#endif
