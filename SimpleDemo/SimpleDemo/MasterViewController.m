//
//  MasterViewController.m
//  SimpleDemo
//
//  Created by zbh on 17/3/15.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#import "MasterViewController.h"
#import "DetailViewController.h"
#import <SimpleBLEKit/BLEManager.h>

@interface MasterViewController ()

@property (strong,atomic) NSMutableArray *objects;
@end

@implementation MasterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(myPeripheralFound:) name:BLE_DEVICE_FOUND object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(myPeripheralConnected:) name:BLESTATUS_CONNECTED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(myPeripheralDisconnected:) name:BLESTATUS_DISCONNECTED object:nil];
    
    UIBarButtonItem *disconnectAllButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(disconnectAll:)];
    self.navigationItem.leftBarButtonItem = disconnectAllButton;
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchBLE:)];
    self.navigationItem.rightBarButtonItem = addButton;
    
    [self startSearch];
}


- (void)viewWillAppear:(BOOL)animated {
    self.clearsSelectionOnViewWillAppear = self.splitViewController.isCollapsed;
    [super viewWillAppear:animated];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)disconnectAll:(id)sender{
    
    UIAlertController *alertController = nil;
    alertController = [UIAlertController alertControllerWithTitle:@"提示" message:@"是否确定断开所有设备的连接" preferredStyle:UIAlertControllerStyleAlert];
    
    //取消按钮
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        
        //模拟程序在后台被挂起
        kill(getpid(), SIGKILL);//SIGHUP
        
    }];
    [alertController addAction:cancelAction];
    //确定按钮
    UIAlertAction *destructiveAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[BLEManager getInstance] stopScan];
        [[BLEManager getInstance] disconnectAll];
    }];
    [alertController addAction:destructiveAction];
    [self presentViewController:alertController animated:YES completion:nil];
}


-(void)searchBLE:(id)sender{
    [self startSearch];
}

-(void)startSearch{
    if (!self.objects) {
        self.objects = [[NSMutableArray alloc] init];
    }else{
        [self.objects removeAllObjects];
        [self.tableView reloadData];
    }
    [[BLEManager getInstance] stopScan];
    
    //参数是设备内的serviceuuid其中一个，不是CBPeripheral的identifier
//    [[BLEManager getInstance] setScanServiceUUIDs:@[@"49535343-FE7D-4AE5-8FA9-9FAFD205E455"]];
    
    [[BLEManager getInstance] startScanByNameFilter:nil/*@[@"iMate",@"K203",@"HxBluetooth",@"JXNX"]*/ timeout:10];
}


#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        
        SimplePeripheral *object = self.objects[indexPath.row];
        DetailViewController *controller = (DetailViewController *)[[segue destinationViewController] topViewController];
        [controller setSelectedPeripheral:object];
        controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
        controller.navigationItem.leftItemsSupplementBackButton = YES;
    }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.objects.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

    SimplePeripheral *object = self.objects[indexPath.row];
    cell.textLabel.text = [object getPeripheralName];
    if ([object isConnected]) {//已经连接
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }else{//已经断开
        cell.accessoryType =UITableViewCellAccessoryNone;
    }
    return cell;
}


#pragma mark - 搜索蓝牙的通知
-(void)myPeripheralFound:(NSNotification *)notification{
    SimplePeripheral *peripheral = [notification object];
    if([self.objects containsObject:peripheral])
        return;
    [self.objects insertObject:peripheral atIndex:0];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - 连接蓝牙的delegate
-(void)myPeripheralConnected:(NSNotification *)notification{
    [self.tableView reloadData];
    DetailViewController *detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];

    NSLog(@"应用层得到设备连接成功的通知\n");
    [detailViewController.connectOrDisconnect setTitle:@"断开设备" forState:UIControlStateNormal];
    detailViewController.connectOrDisconnect.tag = 1;
}
-(void)myPeripheralDisconnected:(NSNotification*)notification{
    [self.tableView reloadData];
    DetailViewController *detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    
    NSLog(@"应用层得到设备连接失败的通知\n");
    [detailViewController.connectOrDisconnect setTitle:@"连接设备" forState:UIControlStateNormal];
    detailViewController.connectOrDisconnect.tag = 0;
}



@end
