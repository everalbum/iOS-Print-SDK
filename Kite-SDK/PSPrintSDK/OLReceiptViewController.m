//
//  ReceiptViewController.m
//  Kite Print SDK
//
//  Created by Deon Botha on 10/01/2014.
//  Copyright (c) 2014 Ocean Labs. All rights reserved.
//

#import "OLReceiptViewController.h"
#import "OLPaymentViewController.h"
#import "Util.h"
#import "OLPrintOrder.h"
#import "OLPrintOrder+History.h"
#import "OLPrintJob.h"
#import "OLProductTemplate.h"
#import "OLConstants.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "OLPaymentLineItem.h"
#import "OLPrintOrderCost.h"
#import "OLOrderReviewViewController.h"
#import "OLKiteViewController.h"
#import <SDWebImage/SDWebImageManager.h>
#import "OLKiteABTesting.h"
#import "UIImage+ColorAtPixel.h"
#import "UIImage+ImageNamedInKiteBundle.h"

static const NSUInteger kSectionOrderSummary = 0;
static const NSUInteger kSectionOrderId = 1;
static const NSUInteger kSectionErrorRetry = 2;

@interface OLReceiptViewController ()
@property (nonatomic, strong) OLPrintOrder *printOrder;
@property (nonatomic, assign) BOOL presentedModally;
@end

@interface OLOrderReviewViewController (Private)

- (UIView *)footerViewForReceiptViewController:(UIViewController *)receiptVc;

@end

@interface OLKiteViewController ()

@property (strong, nonatomic) OLPrintOrder *printOrder;

@end

@implementation OLReceiptViewController

- (id)initWithPrintOrder:(OLPrintOrder *)printOrder {
    if (self = [super initWithStyle:UITableViewStyleGrouped]) {
        self.printOrder = printOrder;
    }
    
    return self;
}

- (void)setupBannerImage:(UIImage *)bannerImage withBgImage:(UIImage *)bannerBgImage{
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, bannerImage.size.height)];
    UIImageView *banner = [[UIImageView alloc] initWithImage:bannerImage];
    
    UIImageView *bannerBg;
    if(bannerBgImage){
        bannerBg = [[UIImageView alloc] initWithImage:bannerBgImage];
    }
    else{
        bannerBg = [[UIImageView alloc] init];
        bannerBg.backgroundColor = [bannerImage colorAtPixel:CGPointMake(3, 3)];
    }
    [self.tableView.tableHeaderView addSubview:bannerBg];
    [self.tableView.tableHeaderView addSubview:banner];
    if (bannerBgImage.size.width > 100){
        bannerBg.contentMode = UIViewContentModeTop;
    }
    else{
        bannerBg.contentMode = UIViewContentModeScaleToFill;
    }
    banner.contentMode = UIViewContentModeCenter;
    
    banner.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *views = NSDictionaryOfVariableBindings(banner);
    NSMutableArray *con = [[NSMutableArray alloc] init];
    
    NSArray *visuals = @[@"H:|-0-[banner]-0-|",
                         @"V:|-0-[banner]-0-|"];
    
    
    for (NSString *visual in visuals) {
        [con addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:visual options:0 metrics:nil views:views]];
    }
    
    [banner.superview addConstraints:con];
    
    bannerBg.translatesAutoresizingMaskIntoConstraints = NO;
    views = NSDictionaryOfVariableBindings(bannerBg);
    con = [[NSMutableArray alloc] init];
    
    visuals = @[@"H:|-0-[bannerBg]-0-|",
                @"V:|-0-[bannerBg]-0-|"];
    
    
    for (NSString *visual in visuals) {
        [con addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:visual options:0 metrics:nil views:views]];
    }
    
    [bannerBg.superview addConstraints:con];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Receipt";
    
    NSString *url = self.printOrder.printed ? [OLKiteABTesting sharedInstance].receiptSuccessURL : [OLKiteABTesting sharedInstance].receiptFailureURL;
    if (url){
        [[SDWebImageManager sharedManager] downloadImageWithURL:[NSURL URLWithString:url] options:0 progress:NULL completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL){
            image = [UIImage imageWithCGImage:image.CGImage scale:2 orientation:image.imageOrientation];
            NSString *bgUrl = self.printOrder.printed ? [OLKiteABTesting sharedInstance].receiptSuccessBgURL : [OLKiteABTesting sharedInstance].receiptFailureBgURL;
            if (bgUrl){
                [[SDWebImageManager sharedManager] downloadImageWithURL:[NSURL URLWithString:bgUrl] options:0 progress:NULL completed:^(UIImage *bgImage, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL){
                    bgImage = [UIImage imageWithCGImage:bgImage.CGImage scale:2 orientation:image.imageOrientation];
                    [self setupBannerImage:image withBgImage:bgImage];
                }];
            }
            else{
                [self setupBannerImage:image withBgImage:nil];
            }
            
        }];
    }
    else{
        [self setupBannerImage:[UIImage imageNamedInKiteBundle:self.printOrder.printed ? @"receipt_success" : @"receipt_failure"] withBgImage:[UIImage imageNamedInKiteBundle:self.printOrder.printed ? @"receipt_success_bg" : @"receipt_failure_bg"]];
    }
    
    if ([self.tableView respondsToSelector:@selector(setCellLayoutMarginsFollowReadableWidth:)]){
        self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    }
    
    if ([self.delegate respondsToSelector:@selector(footerViewForReceiptViewController:)]){
        self.tableView.tableFooterView = [(OLOrderReviewViewController *)self.delegate footerViewForReceiptViewController:self];
    }
}

- (void)onButtonDoneClicked {
    [self.parentViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    UIViewController *vc = self.parentViewController;
    BOOL launchedToShipping = NO;
    self.presentedModally |= ([self.delegate respondsToSelector:@selector(receiptViewControllerShouldBeDismissable)] && [self.delegate receiptViewControllerShouldBeDismissable]);
    while (vc) {
        if ([vc isKindOfClass:[OLKiteViewController class]]){
            launchedToShipping = [(OLKiteViewController *)vc printOrder] != nil;
            break;
        }
        else{
            vc = vc.parentViewController;
        }
    }
    if (self.presentedModally || launchedToShipping) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Done", @"KitePrintSDK", [OLConstants bundle], @"") style:UIBarButtonItemStylePlain target:self action:@selector(onButtonDoneClicked)];
        self.navigationController.viewControllers = @[self];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    UIViewController *vc = self.parentViewController;
    BOOL launchedToShipping = NO;
    while (vc) {
        if ([vc isKindOfClass:[OLKiteViewController class]]){
            launchedToShipping = [(OLKiteViewController *)vc printOrder] != nil;
            break;
        }
        else{
            vc = vc.parentViewController;
        }
    }
    if (!(self.presentedModally || launchedToShipping)) {
        NSMutableArray *navigationStack = self.navigationController.viewControllers.mutableCopy;
        if (navigationStack.count >= 2 &&
            [navigationStack[navigationStack.count - 2] isKindOfClass:[OLPaymentViewController class]]) {
            // clear the stack as we don't want the user to be able to return to payment as that stage of the journey is now complete.
            [navigationStack removeObjectsInRange:NSMakeRange(1, navigationStack.count - 2)];
            self.navigationController.viewControllers = navigationStack;
        }
    }
}

- (void)retrySubmittingOrderForPrinting {
    [SVProgressHUD showWithStatus:@"Processing" maskType:SVProgressHUDMaskTypeBlack];
    [self.printOrder submitForPrintingWithProgressHandler:^(NSUInteger totalAssetsUploaded, NSUInteger totalAssetsToUpload,
                                                            long long totalAssetBytesWritten, long long totalAssetBytesExpectedToWrite,
                                                            long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        const float step = (1.0f / totalAssetsToUpload);
        float progress = totalAssetsUploaded * step + (totalAssetBytesWritten / (float) totalAssetBytesExpectedToWrite) * step;
        [SVProgressHUD showProgress:progress status:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Uploading Images \n%lu / %lu", @"KitePrintSDK", [OLConstants bundle], @""), (unsigned long) totalAssetsUploaded + 1, (unsigned long) totalAssetsToUpload] maskType:SVProgressHUDMaskTypeBlack];
    } completionHandler:^(NSString *orderIdReceipt, NSError *error) {
        [self.printOrder saveToHistory]; // save again as the print order has it's receipt set if it was successful, otherwise last error is set
        [SVProgressHUD dismiss];
        
        if (error) {
            [[[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Oops!", @"KitePrintSDK", [OLConstants bundle], @"") message:error.localizedDescription delegate:nil cancelButtonTitle:NSLocalizedStringFromTableInBundle(@"OK", @"KitePrintSDK", [OLConstants bundle], @"") otherButtonTitles:nil] show];
        } else {
            [UIView transitionWithView:self.view duration:0.3f options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                
                ((UIImageView *) [self.tableView.tableHeaderView viewWithTag:1100]).image = [UIImage imageNamedInKiteBundle:@"receipt_success"];
            } completion:nil];
            
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:kSectionErrorRetry] withRowAnimation:UITableViewRowAnimationFade];
            [self.tableView reloadData];
        }
    }];
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.printOrder.printed ? 2 : 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == kSectionOrderSummary) {
        __block NSUInteger count = 0;
        [self.printOrder costWithCompletionHandler:^(OLPrintOrderCost *cost, NSError *error) {
            // this will actually do the right thing. Either this will callback immediately because printOrder
            // has cached costs and the count will be updated before below conditionals are hit or it will make an async request and count will remain 0 for below.
            count = cost.lineItems.count;
        }];
        if (count <= 1) {
            return count;
        } else {
            return count + 1; // additional cell to show total
        }
    } else if (section == kSectionOrderId) {
        return 1;
    } else if (section  == kSectionErrorRetry) {
        return self.printOrder.printed ? 0 : 1;
    } else {
        return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == kSectionOrderSummary) {
        return NSLocalizedStringFromTableInBundle(@"Order Summary", @"KitePrintSDK", [OLConstants bundle], @"");
    } else if (section == kSectionOrderId) {
        return NSLocalizedStringFromTableInBundle(@"Order Id", @"KitePrintSDK", [OLConstants bundle], @"");
    }
    
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    if (indexPath.section == kSectionOrderId) {
        static NSString *const kCellIdOrderId = @"kCellIdOrderId";
        cell = [tableView dequeueReusableCellWithIdentifier:kCellIdOrderId];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellIdOrderId];
            cell.textLabel.adjustsFontSizeToFitWidth = YES;
            cell.textLabel.minimumScaleFactor = 0.5;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        
        if (self.printOrder.printed) {
            cell.textLabel.text = self.printOrder.receipt;
        } else {
            NSMutableString *receipt = [[NSMutableString alloc] init];
            if (self.printOrder.proofOfPayment) {
                [receipt appendString:self.printOrder.proofOfPayment];
            }
            
            if (self.printOrder.promoCode) {
                if (receipt.length > 0) {
                    [receipt appendString:@" "];
                }
                
                [receipt appendString:@"PROMO-"];
                [receipt appendString:self.printOrder.promoCode];
            }
            
            cell.textLabel.text = receipt;
        }
    } else if (indexPath.section == kSectionOrderSummary) {
        static NSString *const CellIdentifier = @"JobCostSummaryCell";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
            cell.textLabel.font = [UIFont systemFontOfSize:14];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
            cell.textLabel.adjustsFontSizeToFitWidth = YES;
            cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
            cell.textLabel.minimumScaleFactor = 0.5;
            cell.detailTextLabel.minimumScaleFactor = 0.5;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        
        [self.printOrder costWithCompletionHandler:^(OLPrintOrderCost *orderCost, NSError *error) {
            NSArray *lineItems = orderCost.lineItems;
            NSDecimalNumber *totalCost = [orderCost totalCostInCurrency:self.printOrder.currencyCode];
            
            BOOL total = indexPath.row >= lineItems.count;
            NSDecimalNumber *cost;
            NSString *currencyCode = self.printOrder.currencyCode;
            if (total) {
                cell.textLabel.text = NSLocalizedStringFromTableInBundle(@"Total", @"KitePrintSDK", [OLConstants bundle], @"");
                cell.textLabel.font = [UIFont boldSystemFontOfSize:cell.textLabel.font.pointSize];
                cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:cell.detailTextLabel.font.pointSize];
                
                cost = totalCost;
                
                NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
                [formatter setNumberStyle:NSNumberFormatterCurrencyStyle];
                [formatter setCurrencyCode:currencyCode];
                cell.detailTextLabel.text = [formatter stringFromNumber:totalCost];
            }
            else{
                OLPaymentLineItem *item = lineItems[indexPath.row];
                cell.textLabel.text = item.description;
                cell.textLabel.font = [UIFont systemFontOfSize:cell.textLabel.font.pointSize];
                cell.detailTextLabel.font = [UIFont systemFontOfSize:cell.detailTextLabel.font.pointSize];
                cell.detailTextLabel.text = [item costStringInCurrency:self.printOrder.currencyCode];
            }
        }];
    } else if (indexPath.section == kSectionErrorRetry) {
        static NSString *const kCellRetry = @"kCellRetry";
        cell = [tableView dequeueReusableCellWithIdentifier:kCellRetry];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellRetry];
            cell.textLabel.textColor = [UIColor colorWithRed:0 green:135 / 255.0 blue:1 alpha:1];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        
        cell.textLabel.text = NSLocalizedStringFromTableInBundle(@"Retry", @"KitePrintSDK", [OLConstants bundle], @"");
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != kSectionErrorRetry) {
        return;
    }
    
    [self retrySubmittingOrderForPrinting];
}

#pragma mark - Autorotate and Orientation Methods
// Currently here to disable landscape orientations and rotation on iOS 7. When support is dropped, these can be deleted.

- (BOOL)shouldAutorotate {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8) {
        return YES;
    }
    else{
        return NO;
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8) {
        return UIInterfaceOrientationMaskAll;
    }
    else{
        return UIInterfaceOrientationMaskPortrait;
    }
}

@end
