//
//  QCScanView.m
//  HappyDiet - from ebowwa/HeyCyanSmartGlassesSDK
//

#import "QCScanView.h"

@implementation QCScanView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor systemBackgroundColor];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    _indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
#else
    _indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
#endif
    _indicatorView.frame = CGRectMake(0, 64, self.frame.size.width, 20);
    [self addSubview:_indicatorView];

    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(_indicatorView.frame), CGRectGetWidth(self.frame), CGRectGetHeight(self.frame) - CGRectGetMaxY(_indicatorView.frame)) style:UITableViewStylePlain];
    [self addSubview:_tableView];
}

@end
