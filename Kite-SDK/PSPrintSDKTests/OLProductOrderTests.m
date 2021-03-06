//
//  OLProductOrderTests.m
//  KitePrintSDK
//
//  Created by Konstadinos Karayannis on 06/10/15.
//  Copyright © 2015 Kite.ly. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "OLProductTemplate.h"
#import "OLKitePrintSDK.h"
#import <SDWebImage/SDWebImageManager.h>
#import <Stripe/Stripe.h>
#import "OLPrintPhoto.h"
#import "OLKiteTestHelper.h"
#import <AssetsLibrary/AssetsLibrary.h>

@import Photos;

@interface OLPrintOrder (Private)
- (BOOL)hasCachedCost;
@end

@interface OLKitePrintSDK (PrivateMethods)

+ (NSString *_Nonnull)stripePublishableKey;

@end

@interface OLProductOrderTests : XCTestCase

@end

@implementation OLProductOrderTests

#pragma mark XCTest methods

- (void)setUp {
    [super setUp];
    
    [OLKitePrintSDK setAPIKey:@"a45bf7f39523d31aa1ca4ecf64d422b4d810d9c4" withEnvironment:kOLKitePrintSDKEnvironmentSandbox];
    
    
    [self templateSyncWithSuccessHandler:NULL];
    [self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)tearDown {
    [super tearDown];
}

#pragma mark Kite SDK helper methods

- (void)submitOrder:(OLPrintOrder *)printOrder WithSuccessHandler:(void(^)())handler{
    [self submitStripeOrder:printOrder WithSuccessHandler:handler];
}

- (OLPrintOrder *)submitJobs:(NSArray <id<OLPrintJob>>*)jobs{
    OLPrintOrder *printOrder = [[OLPrintOrder alloc] init];
    printOrder.shippingAddress = [OLAddress kiteTeamAddress];
    
    [printOrder addPrintJob:jobs.firstObject];
    [printOrder removePrintJob:jobs.firstObject];
    
    [printOrder setUserData:@{@"Unit Tests" : @YES}];
    
    XCTAssert(printOrder.jobs.count == 0, @"Exptected 0 jobs");
    
    for (id<OLPrintJob> job in jobs){
        [printOrder addPrintJob:job];
    }
    
    XCTAssert(![printOrder hasCachedCost], @"Should not have cached cost");
    
    [printOrder preemptAssetUpload];
    
    [self submitOrder:printOrder WithSuccessHandler:NULL];
    
    [self waitForExpectationsWithTimeout:60 handler:nil];
    
    XCTAssert(printOrder.printed, @"Order not printed");
    XCTAssert([printOrder.receipt hasPrefix:@"PS"], @"Order does not have valid receipt");
    
    return printOrder;
}

- (void)submitStripeOrder:(OLPrintOrder *)printOrder WithSuccessHandler:(void(^)())handler{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Print order submitted"];
    
    STPAPIClient *client = [[STPAPIClient alloc] initWithPublishableKey:[OLKitePrintSDK stripePublishableKey]];
    
    STPCard *card = [STPCard new];
    card.number = @"4242424242424242";
    card.expMonth = 12;
    card.expYear = 2020;
    card.cvc = @"123";
    [client createTokenWithCard:card completion:^(STPToken *token, NSError *error) {
        XCTAssert(!error, @"Failed to create Stripe token with: %@", error);
        printOrder.proofOfPayment = token.tokenId;
        
        [printOrder submitForPrintingWithProgressHandler:NULL completionHandler:^(NSString *orderIdReceipt, NSError *error) {
            XCTAssert(!error, @"Failed to submit order to Kite with: %@", error);
            
            [printOrder saveToHistory];
            [expectation fulfill];
            if (handler) handler();
        }];
    }];
}

- (void)submitPayPalOrder:(OLPrintOrder *)printOrder WithSuccessHandler:(void(^)())handler{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Print order submitted"];
    
    OLPayPalCard *card = [[OLPayPalCard alloc] init];
    card.type = kOLPayPalCardTypeVisa;
    card.number = @"4242424242424242";
    card.expireMonth = 12;
    card.expireYear = 2020;
    card.cvv2 = @"111";
    
    [printOrder costWithCompletionHandler:^(OLPrintOrderCost *cost, NSError *error){
        XCTAssert(!error, @"Failed to get order cost with: %@", error);
        
        [card chargeCard:[cost totalCostInCurrency:printOrder.currencyCode] currencyCode:printOrder.currencyCode description:printOrder.paymentDescription completionHandler:^(NSString *proofOfPayment, NSError *error) {
            XCTAssert(!error, @"Failed to charge card with: %@", error);
            
            printOrder.proofOfPayment = proofOfPayment;
            [printOrder submitForPrintingWithCompletionHandler:^(NSString *orderIdReceipt, NSError *error) {
                XCTAssert(!error, @"Failed to submit order to Kite with: %@", error);
                
                [printOrder saveToHistory];
                [expectation fulfill];
                if (handler) handler();
            }];
        }];
    }];
}

- (void)templateSyncWithSuccessHandler:(void(^)())handler{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Template Sync Completed"];
    [OLProductTemplate syncWithCompletionHandler:^(NSArray <OLProductTemplate *>* _Nullable templates, NSError * _Nullable error){
        XCTAssert(!error, @"Template Sync Request failed with: %@", error);
        
        XCTAssert(templates.count > 0, @"Template Sync returned 0 templates. Maintenance mode?");
        
        [expectation fulfill];
        if (handler) handler();
    }];
}

#pragma mark Test cases

- (void)testSquaresOrderWithURLOLAssets{
    OLProductPrintJob *job = [OLPrintJob printJobWithTemplateId:@"squares" OLAssets:[OLKiteTestHelper urlAssets]];
    [self submitJobs:@[job]];
}

- (void)testSquaresOrderWithImageOLAssets{
    OLProductPrintJob *job = [OLPrintJob printJobWithTemplateId:@"squares" OLAssets:[OLKiteTestHelper imageAssets]];
    [self submitJobs:@[job]];
}

- (void)testSquaresOrderWithJpgDataOLAssets{
    NSData *data = [NSData dataWithContentsOfFile:[[NSBundle bundleForClass:[OLProductOrderTests class]] pathForResource:@"1" ofType:@"jpg"]];
    XCTAssert(data, @"No data");
    
    OLProductPrintJob *job = [OLPrintJob printJobWithTemplateId:@"squares" OLAssets:@[[OLAsset assetWithDataAsJPEG:data]]];
    [self submitJobs:@[job]];
}

- (void)testSquaresOrderWithPngDataOLAssets{
    NSData *data = [NSData dataWithContentsOfFile:[[NSBundle bundleForClass:[OLProductOrderTests class]] pathForResource:@"2" ofType:@"png"]];
    XCTAssert(data, @"No data");
    
    OLProductPrintJob *job = [OLPrintJob printJobWithTemplateId:@"squares" OLAssets:@[[OLAsset assetWithDataAsJPEG:data]]];
    [self submitJobs:@[job]];
}

- (void)testSquaresOrderWithImages{
    NSData *data = [NSData dataWithContentsOfFile:[[NSBundle bundleForClass:[OLProductOrderTests class]] pathForResource:@"1" ofType:@"jpg"]];
    XCTAssert(data, @"No data");
    
    UIImage *image = [UIImage imageWithData:data];
    XCTAssert(image, @"No image");
    
    OLProductPrintJob *job = [OLPrintJob printJobWithTemplateId:@"squares" images:@[image]];
    [self submitJobs:@[job]];
}

- (void)testSquaresOrderWithFilePaths{
    NSString *path = [[NSBundle bundleForClass:[OLProductOrderTests class]] pathForResource:@"1" ofType:@"jpg"];
    XCTAssert(path, @"No path");
    
    OLProductPrintJob *job = [OLPrintJob printJobWithTemplateId:@"squares" imageFilePaths:@[path]];
    [self submitJobs:@[job]];
}

- (void)testSquaresOrderWithPHAssetOLAssets{
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:nil];
    XCTAssert(fetchResult.count > 0, @"There are no assets available");
    
    PHAsset *asset = [fetchResult objectAtIndex:arc4random() % fetchResult.count];
    
    OLProductPrintJob *job = [OLPrintJob printJobWithTemplateId:@"squares" OLAssets:@[[OLAsset assetWithPHAsset:asset]]];
    [self submitJobs:@[job]];
}

- (void)testSquaresOrderWithALAssetOLAssets{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Get ALAsset"];
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    __block ALAsset *asset;
    [library enumerateGroupsWithTypes: ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop){
        [group enumerateAssetsAtIndexes:[NSIndexSet indexSetWithIndex:0] options:0 usingBlock:^(ALAsset *result, NSUInteger index, BOOL *groupStop){
            if (!*stop && !*groupStop){
                asset = result;
                [expectation fulfill];
            }
            *stop = YES;
            *groupStop = YES;
        }];
    }failureBlock:NULL];
    
    [self waitForExpectationsWithTimeout:15 handler:NULL];
    
    OLPrintPhoto *printPhoto = [[OLPrintPhoto alloc] init];
    printPhoto.asset = asset;
    
    OLProductPrintJob *job = [OLPrintJob printJobWithTemplateId:@"squares" OLAssets:@[[OLAsset assetWithPrintPhoto:printPhoto]]];
    [self submitJobs:@[job]];
}

- (void)testSquaresOrderWithURLOLAssetPrintPhotos{
    OLPrintPhoto *printPhoto = [[OLPrintPhoto alloc] init];
    printPhoto.asset = [OLKiteTestHelper urlAssets].firstObject;
    
    OLProductPrintJob *job = [OLPrintJob printJobWithTemplateId:@"squares" OLAssets:@[[OLAsset assetWithDataSource:printPhoto]]];
    [self submitJobs:@[job]];
}

- (void)testSquaresOrderWithImageOLAssetPrintPhotos{
    OLPrintPhoto *printPhoto = [[OLPrintPhoto alloc] init];
    printPhoto.asset = [OLKiteTestHelper imageAssets].firstObject;
    
    OLProductPrintJob *job = [OLPrintJob printJobWithTemplateId:@"squares" OLAssets:@[[OLAsset assetWithDataSource:printPhoto]]];
    [self submitJobs:@[job]];
}

- (void)testSquaresOrderWithImageOLAssetPrintPhotoOLAsset{
    OLPrintPhoto *printPhoto = [[OLPrintPhoto alloc] init];
    printPhoto.asset = [OLKiteTestHelper imageAssets].firstObject;
    
    OLProductPrintJob *job = [OLPrintJob printJobWithTemplateId:@"squares" OLAssets:@[[OLAsset assetWithPrintPhoto:printPhoto]]];
    [self submitJobs:@[job]];
}

- (void)testSquaresOrderWithPHAssetPrintPhotos{
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:nil];
    XCTAssert(fetchResult.count > 0, @"There are no assets available");
    
    PHAsset *asset = [fetchResult objectAtIndex:arc4random() % fetchResult.count];
    
    OLPrintPhoto *printPhoto = [[OLPrintPhoto alloc] init];
    printPhoto.asset = asset;
    
    OLProductPrintJob *job = [OLPrintJob printJobWithTemplateId:@"squares" OLAssets:@[[OLAsset assetWithDataSource:printPhoto]]];
    [self submitJobs:@[job]];
}

- (void)testSquaresOrderWithPHAssetPrintPhotoOLAsset{
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:nil];
    XCTAssert(fetchResult.count > 0, @"There are no assets available");
    
    PHAsset *asset = [fetchResult objectAtIndex:arc4random() % fetchResult.count];
    
    OLPrintPhoto *printPhoto = [[OLPrintPhoto alloc] init];
    printPhoto.asset = asset;
    
    OLAsset *olAsset = [OLAsset assetWithPrintPhoto:printPhoto];
    
    PHAsset *loadedAsset = [olAsset loadPHAsset];
    
    XCTAssert([[loadedAsset localIdentifier] isEqualToString:[asset localIdentifier]], @"Local IDs should match");
    
    OLProductPrintJob *job = [OLPrintJob printJobWithTemplateId:@"squares" OLAssets:@[olAsset]];
    [self submitJobs:@[job]];
}

- (void)testSquaresOrderWithPHAssetPrintPhotosDataSource{
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:nil];
    XCTAssert(fetchResult.count > 0, @"There are no assets available");
    
    PHAsset *asset = [fetchResult objectAtIndex:arc4random() % fetchResult.count];
    
    OLPrintPhoto *printPhoto = [[OLPrintPhoto alloc] init];
    printPhoto.asset = asset;
    
    OLProductPrintJob *job = [OLPrintJob printJobWithTemplateId:@"squares" dataSources:@[printPhoto]];
    [self submitJobs:@[job]];
}

- (void)testPhotobookOrderWithURLOLAssets{
    OLPhotobookPrintJob *job = [OLPrintJob photobookWithTemplateId:@"rpi_wrap_300x300_sm" OLAssets:[OLKiteTestHelper urlAssets] frontCoverOLAsset:[OLKiteTestHelper urlAssets].firstObject backCoverOLAsset:[OLKiteTestHelper urlAssets].lastObject];
    [self submitJobs:@[job]];
}

- (void)testPostcardOrderWithURLOLAssets{
    id<OLPrintJob> job = [OLPrintJob postcardWithTemplateId:@"postcard" frontImageOLAsset:[OLKiteTestHelper urlAssets].firstObject backImageOLAsset:[OLKiteTestHelper urlAssets].lastObject];
    [self submitJobs:@[job]];
}

- (void)testMultipleAddressesManual{
    OLProductPrintJob *job1 = [OLPrintJob printJobWithTemplateId:@"squares" OLAssets:@[[OLKiteTestHelper urlAssets].firstObject]];
    OLProductPrintJob *job2 = [OLPrintJob printJobWithTemplateId:@"squares" OLAssets:@[[OLKiteTestHelper urlAssets].lastObject]];
    [self submitJobs:@[job1, job2]];
}

- (void)testMultipleAddresses{
    OLProductPrintJob *job = [OLPrintJob printJobWithTemplateId:@"squares" OLAssets:@[[OLKiteTestHelper urlAssets].firstObject]];
    
    OLPrintOrder *printOrder = [[OLPrintOrder alloc] init];
    [printOrder addPrintJob:job];
    
    OLAddress *address1 = [OLAddress kiteTeamAddress];
    OLAddress *a = [[OLAddress alloc] init];
    a.recipientFirstName = @"Deon";
    a.recipientLastName = @"Botha";
    a.line1         = @"27-28 Eastcastle House";
    a.line2         = @"Eastcastle Street";
    a.city          = @"London";
    a.stateOrCounty = @"Greater London";
    a.zipOrPostcode = @"W1W 8DH";
    a.country       = [OLCountry countryForCode:@"GBR"];
    
    [printOrder duplicateJobsForAddresses:@[address1, a]];
    XCTAssert(printOrder.jobs.count == 2, @"Should have 2 jobs, one for each address");
    [printOrder discardDuplicateJobs];
    XCTAssert(printOrder.jobs.count == 1, @"Should have only 1 job");
    [printOrder duplicateJobsForAddresses:@[address1, a]];
    XCTAssert(printOrder.jobs.count == 2, @"Should have 2 jobs, one for each address");
    
    [self submitOrder:printOrder WithSuccessHandler:NULL];
    
    [self waitForExpectationsWithTimeout:60 handler:nil];
    
    XCTAssert(printOrder.printed, @"Order not printed");
    XCTAssert([printOrder.receipt hasPrefix:@"PS"], @"Order does not have valid receipt");
}

- (void)testSingleJobSubmission{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Print order submitted"];
    
    NSArray *assets = @[
                        [OLAsset assetWithURL:[NSURL URLWithString:@"http://psps.s3.amazonaws.com/sdk_static/1.jpg"]],
                        [OLAsset assetWithURL:[NSURL URLWithString:@"http://psps.s3.amazonaws.com/sdk_static/2.jpg"]],
                        [OLAsset assetWithURL:[NSURL URLWithString:@"http://psps.s3.amazonaws.com/sdk_static/3.jpg"]],
                        [OLAsset assetWithURL:[NSURL URLWithString:@"http://psps.s3.amazonaws.com/sdk_static/4.jpg"]]
                        ];
    [OLProductTemplate syncWithCompletionHandler:^(NSArray* templates, NSError *error){
        XCTAssert(!error, @"Template sync failed with: %@", error);
        
        id<OLPrintJob> squarePrints = [OLPrintJob printJobWithTemplateId:@"squares" OLAssets:assets];
        
        __block OLPrintOrder *order = [[OLPrintOrder alloc] init];
        [order addPrintJob:squarePrints];
        
        OLAddress *a    = [[OLAddress alloc] init];
        a.recipientFirstName = @"Deon";
        a.recipientLastName = @"Botha";
        a.line1         = @"27-28 Eastcastle House";
        a.line2         = @"Eastcastle Street";
        a.city          = @"London";
        a.stateOrCounty = @"Greater London";
        a.zipOrPostcode = @"W1W 8DH";
        a.country       = [OLCountry countryForCode:@"GBR"];
        
        order.shippingAddress = a;
        squarePrints.address = a;
        
        OLPayPalCard *card = [[OLPayPalCard alloc] init];
        card.type = kOLPayPalCardTypeVisa;
        card.number = @"4121212121212127";
        card.expireMonth = 12;
        card.expireYear = 2020;
        card.cvv2 = @"123";
        
        [order costWithCompletionHandler:^(OLPrintOrderCost *cost, NSError *error){
            XCTAssert(!error, @"Cost request failed with: %@", error);
            
            [card chargeCard:[cost totalCostInCurrency:order.currencyCode] currencyCode:order.currencyCode description:[order paymentDescription] completionHandler:^(NSString *proofOfPayment, NSError *error) {
                XCTAssert(!error, @"Card charge failed with: %@", error);
                
                order = [OLPrintOrder submitJob:squarePrints withProofOfPayment:proofOfPayment forPrintingWithProgressHandler:NULL completionHandler:^(NSString *orderIdReceipt, NSError *error) {
                    XCTAssert(!error, @"Order submission failed with: %@", error);
                    
                    // If there is no error then you can display a success outcome to the user
                    XCTAssert(order.printed, @"Order not printed");
                    XCTAssert([order.receipt hasPrefix:@"PS"], @"Order does not have valid receipt");
                    [expectation fulfill];
                }];
            }];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:60 handler:NULL];
}


@end
