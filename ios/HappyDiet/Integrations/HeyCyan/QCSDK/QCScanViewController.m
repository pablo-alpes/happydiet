//
//  QCScanViewController.m
//  HappyDiet - from ebowwa/HeyCyanSmartGlassesSDK
//

#import "QCScanViewController.h"
#import "QCCentralManager.h"
#import "QCScanView.h"

static const NSTimeInterval kConnectionTimeoutSeconds = 35;

@interface QCScanViewController () <UITableViewDataSource, UITableViewDelegate, QCCentralManagerDelegate>
@property (nonatomic, strong) QCScanView *scanView;
@property (nonatomic, strong) NSArray<QCBlePeripheral *> *peripherals;
@property (nonatomic, copy, nullable) void (^onDeviceSelected)(CBPeripheral *);
@property (nonatomic, strong) NSTimer *connectionTimeoutTimer;
@end

@implementation QCScanViewController

- (instancetype)initWithOnDeviceSelected:(void (^)(CBPeripheral *))onDeviceSelected {
    self = [super init];
    if (self) {
        _onDeviceSelected = [onDeviceSelected copy];
        _peripherals = @[];
    }
    return self;
}

- (instancetype)init {
    return [self initWithOnDeviceSelected:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Search HeyCyan";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelTapped)];
    self.scanView = [[QCScanView alloc] initWithFrame:self.view.bounds];
    self.scanView.tableView.delegate = self;
    self.scanView.tableView.dataSource = self;
    [self.view addSubview:self.scanView];

    [QCCentralManager shared].delegate = self;
    [[QCCentralManager shared] scan];
    [self.scanView.indicatorView startAnimating];
}

- (void)cancelTapped {
    [self cancelConnectionTimeout];
    [[QCCentralManager shared] stopScan];
    [[QCCentralManager shared] remove];
    UIViewController *presenter = self.navigationController ? self.navigationController.presentingViewController : self.presentingViewController;
    [presenter dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self cancelConnectionTimeout];
    [[QCCentralManager shared] stopScan];
}

#pragma mark - QCCentralManagerDelegate
- (void)didScanPeripherals:(NSArray<QCBlePeripheral *> *)peripheralArr {
    self.peripherals = peripheralArr;
    [self.scanView.tableView reloadData];
}

- (void)didState:(QCState)state {
    if (state == QCStateConnected && self.onDeviceSelected) {
        [self cancelConnectionTimeout];
        CBPeripheral *p = [QCCentralManager shared].connectedPeripheral;
        if (p) self.onDeviceSelected(p);
    }
}

#pragma mark - UITableViewDataSource & Delegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.peripherals.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    QCBlePeripheral *per = self.peripherals[indexPath.row];
    cell.textLabel.text = per.peripheral.name ?: @"Unknown";
    cell.detailTextLabel.text = per.mac.length > 0 ? per.mac : @"";
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.scanView.indicatorView startAnimating];
    [[QCCentralManager shared] stopScan];

    [self cancelConnectionTimeout];
    self.connectionTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:kConnectionTimeoutSeconds target:self selector:@selector(connectionTimedOut:) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:self.connectionTimeoutTimer forMode:NSRunLoopCommonModes];

    QCBlePeripheral *per = self.peripherals[indexPath.row];
    [[QCCentralManager shared] connect:per.peripheral timeout:30 deviceType:QCDeviceTypeGlasses];
}

- (void)cancelConnectionTimeout {
    [self.connectionTimeoutTimer invalidate];
    self.connectionTimeoutTimer = nil;
}

- (void)connectionTimedOut:(NSTimer *)timer {
    [self cancelConnectionTimeout];
    [self.scanView.indicatorView stopAnimating];
    [[QCCentralManager shared] stopScan];
    [[QCCentralManager shared] remove];
    if (self.onConnectionTimeout) {
        self.onConnectionTimeout();
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Connection Timed Out"
                                                                       message:@"The glasses did not respond in time. Try: 1) Put glasses closer. 2) Use WiFi transfer (enter SSID from glasses display)."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            UIViewController *presenter = self.navigationController ? self.navigationController.presentingViewController : self.presentingViewController;
            [presenter dismissViewControllerAnimated:YES completion:nil];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - QCCentralManagerDelegate (connection failure)
- (void)didFailConnected:(CBPeripheral *)peripheral error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self cancelConnectionTimeout];
        [self.scanView.indicatorView stopAnimating];
        NSString *msg = error.localizedDescription ?: @"Connection failed";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Connection Failed" message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

@end
