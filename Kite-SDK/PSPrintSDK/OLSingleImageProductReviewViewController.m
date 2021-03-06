//
//  OLSingleImageProductReviewViewController.m
//  KitePrintSDK
//
//  Created by Konstadinos Karayannis on 2/24/15.
//  Copyright (c) 2015 Deon Botha. All rights reserved.
//

#import "OLSingleImageProductReviewViewController.h"
#import "OLPrintPhoto.h"
#import "OLAnalytics.h"
#import "OLAsset+Private.h"
#import <SDWebImage/SDWebImageManager.h>
#import "OLProductPrintJob.h"
#import "OLKitePrintSDK.h"
#import "OLAssetsPickerController.h"
#import "OLKiteUtils.h"
#ifdef OL_KITE_AT_LEAST_IOS8
#import <CTAssetsPickerController/CTAssetsPickerController.h>
#endif
#import "NSArray+QueryingExtras.h"
#import "OLKiteViewController.h"
#import "OLKiteABTesting.h"
#import "NSObject+Utils.h"
#import "OLImageCachingManager.h"
#import "OLRemoteImageView.h"
#import "OLRemoteImageCropper.h"

#ifdef OL_KITE_OFFER_INSTAGRAM
#import <InstagramImagePicker/OLInstagramImagePickerController.h>
#import <InstagramImagePicker/OLInstagramImage.h>
#endif

#ifdef OL_KITE_OFFER_FACEBOOK
#import <FacebookImagePicker/OLFacebookImagePickerController.h>
#import <FacebookImagePicker/OLFacebookImage.h>
#endif

@interface OLKiteViewController ()

@property (strong, nonatomic) OLPrintOrder *printOrder;
- (void)dismiss;

@end

@interface OLKitePrintSDK (InternalUtils)
#ifdef OL_KITE_OFFER_INSTAGRAM
+ (NSString *) instagramRedirectURI;
+ (NSString *) instagramSecret;
+ (NSString *) instagramClientID;
#endif
@end

@interface OLSingleImageProductReviewViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UINavigationControllerDelegate, UIActionSheetDelegate, UIAlertViewDelegate,
#ifdef OL_KITE_OFFER_INSTAGRAM
OLInstagramImagePickerControllerDelegate,
#endif
#ifdef OL_KITE_OFFER_FACEBOOK
OLFacebookImagePickerControllerDelegate,
#endif
#ifdef OL_KITE_AT_LEAST_IOS8
CTAssetsPickerControllerDelegate,
#endif
OLAssetsPickerControllerDelegate>

@property (weak, nonatomic) IBOutlet UILabel *quantityLabel;
@property (assign, nonatomic) NSUInteger quantity;

@property (weak, nonatomic) IBOutlet UICollectionView *imagesCollectionView;

@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (weak, nonatomic) IBOutlet OLRemoteImageCropper *imageCropView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *maskAspectRatio;
@property (strong, nonatomic) OLPrintPhoto *imagePicked;

-(void) doCheckout;

@end

@implementation OLSingleImageProductReviewViewController

-(void)viewDidLoad{
    [super viewDidLoad];
    
#ifndef OL_NO_ANALYTICS
    [OLAnalytics trackReviewScreenViewed:self.product.productTemplate.name];
#endif
    
    OLKiteViewController *kiteVc = [self kiteVc];
    if ([kiteVc printOrder] && !self.userSelectedPhotos){
        self.title = NSLocalizedString(@"Review", @"");
        self.userSelectedPhotos = [[NSMutableArray alloc] init];
        for (OLAsset *asset in [[kiteVc.printOrder.jobs firstObject] assetsForUploading]){
            OLPrintPhoto *printPhoto = [[OLPrintPhoto alloc] init];
            printPhoto.asset = asset;
            [self.userSelectedPhotos addObject:printPhoto];
        }
    }
    else{
        [self setTitle:NSLocalizedString(@"Reposition the Photo", @"")];
    }
    
    if (self.imageCropView){
        [[self.userSelectedPhotos firstObject] getImageWithProgress:NULL completion:^(UIImage *image){
            self.imageCropView.image = image;
        }];
    }
    
    for (OLPrintPhoto *printPhoto in self.userSelectedPhotos){
        [printPhoto unloadImage];
    }
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                              initWithTitle:@"Next"
                                              style:UIBarButtonItemStylePlain
                                              target:self
                                              action:@selector(onButtonNextClicked)];
    
    self.quantity = 1;
    [self updateQuantityLabel];
    
    self.imagesCollectionView.dataSource = self;
    self.imagesCollectionView.delegate = self;
    
    if (![self shouldShowAddMorePhotos] && self.userSelectedPhotos.count == 1){
        self.imagesCollectionView.hidden = YES;
    }
    
    if ([self shouldShowAddMorePhotos] && self.userSelectedPhotos.count == 0 && [[[UIDevice currentDevice] systemVersion] floatValue] >= 8){
        [self collectionView:self.imagesCollectionView didSelectItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
    }
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
}

- (void) updateQuantityLabel{
    self.quantityLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.quantity];
}

- (IBAction)onButtonDownArrowClicked:(UIButton *)sender {
    if (self.quantity > 1){
        self.quantity--;
        [self updateQuantityLabel];
    }
}

- (IBAction)onButtonUpArrowClicked:(UIButton *)sender {
    self.quantity++;
    [self updateQuantityLabel];
}

-(void)onButtonNextClicked{
    [self doCheckout];
}

- (OLKiteViewController *)kiteVc{
    UIViewController *vc = self.parentViewController;
    while (vc) {
        if ([vc isKindOfClass:[OLKiteViewController class]]){
            return (OLKiteViewController *)vc;
            break;
        }
        else{
            vc = vc.parentViewController;
        }
    }
    return nil;
}

-(void) doCheckout{
    if (!self.imageCropView.image) {
        return;
    }
    
    UIImage *croppedImage = self.imageCropView.editedImage;
    
    OLAsset *asset = [OLAsset assetWithImageAsJPEG:croppedImage];
    
    [asset dataLengthWithCompletionHandler:^(long long dataLength, NSError *error){
        if (dataLength < 40000){
            if ([UIAlertController class]){
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Image Is Too Small", @"") message:NSLocalizedString(@"Please zoom out or pick a higher quality image", @"") preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleDefault handler:NULL]];
                [self presentViewController:alert animated:YES completion:NULL];
            }
            else{
                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Image Too Small", @"") message:NSLocalizedString(@"Please zoom out or pick higher quality image", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
            }
        }
        else{
            
            NSMutableArray *assetArray = [[NSMutableArray alloc] initWithCapacity:self.quantity];
            for (NSInteger i = 0; i < self.quantity; i++){
                [assetArray addObject:asset];
            }
            
            NSUInteger iphonePhotoCount = 1;
            OLProductPrintJob *job = [[OLProductPrintJob alloc] initWithTemplateId:self.product.templateId OLAssets:assetArray];
            job.uuid = [[NSUUID UUID] UUIDString];
            OLPrintOrder *printOrder = [[OLPrintOrder alloc] init];
            NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
            NSString *appVersion = [infoDict objectForKey:@"CFBundleShortVersionString"];
            NSNumber *buildNumber = [infoDict objectForKey:@"CFBundleVersion"];
            printOrder.userData = @{@"photo_count_iphone": [NSNumber numberWithUnsignedInteger:iphonePhotoCount],
                                    @"sdk_version": kOLKiteSDKVersion,
                                    @"platform": @"iOS",
                                    @"uid": [[[UIDevice currentDevice] identifierForVendor] UUIDString],
                                    @"app_version": [NSString stringWithFormat:@"Version: %@ (%@)", appVersion, buildNumber]
                                    };
            
            
            //Check if we have launched with a Print Order
            OLKiteViewController *kiteVC = [self kiteVc];
            if ([kiteVC printOrder]){
                printOrder = [kiteVC printOrder];
            }
            
            for (id<OLPrintJob> job in printOrder.jobs){
                [printOrder removePrintJob:job];
            }
            [printOrder addPrintJob:job];
            
            if ([kiteVC printOrder]){
                [kiteVC setPrintOrder:printOrder];
            }
            
            if ([kiteVC printOrder] && [[OLKiteABTesting sharedInstance].launchWithPrintOrderVariant isEqualToString:@"Review-Overview-Checkout"]){
                UIViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"OLProductOverviewViewController"];
                [vc safePerformSelector:@selector(setUserEmail:) withObject:[(OLKiteViewController *)vc userEmail]];
                [vc safePerformSelector:@selector(setUserPhone:) withObject:[(OLKiteViewController *)vc userPhone]];
                [vc safePerformSelector:@selector(setKiteDelegate:) withObject:self.delegate];
                [vc safePerformSelector:@selector(setProduct:) withObject:self.product];
                [self.navigationController pushViewController:vc animated:YES];
            }
            else{
                [OLKiteUtils checkoutViewControllerForPrintOrder:printOrder handler:^(id vc){
                    [vc safePerformSelector:@selector(setUserEmail:) withObject:[OLKiteUtils userEmail:self]];
                    [vc safePerformSelector:@selector(setUserPhone:) withObject:[OLKiteUtils userPhone:self]];
                    [vc safePerformSelector:@selector(setKiteDelegate:) withObject:[OLKiteUtils kiteDelegate:self]];

                    
                    [self.navigationController pushViewController:vc animated:YES];
                }];
            }
        }
    }];
}

- (BOOL)instagramEnabled{
#ifdef OL_KITE_OFFER_INSTAGRAM
    return [OLKitePrintSDK instagramSecret] && ![[OLKitePrintSDK instagramSecret] isEqualToString:@""] && [OLKitePrintSDK instagramClientID] && ![[OLKitePrintSDK instagramClientID] isEqualToString:@""] && [OLKitePrintSDK instagramRedirectURI] && ![[OLKitePrintSDK instagramRedirectURI] isEqualToString:@""];
#else
    return NO;
#endif
}

- (BOOL)facebookEnabled{
#ifdef OL_KITE_OFFER_FACEBOOK
    return YES;
#else
    return NO;
#endif
}

#pragma mark CollectionView delegate and data source

- (NSInteger) sectionForMoreCell{
    return 0;
}

- (NSInteger) sectionForImageCells{
    return [self shouldShowAddMorePhotos] ? 1 : 0;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    if (section == [self sectionForImageCells]){
        return self.userSelectedPhotos.count;
    }
    else if (section == [self sectionForMoreCell]){
        return 1;
    }
    else{
        return 0;
    }
}

- (BOOL)shouldShowAddMorePhotos{
    if ([[self kiteVc] printOrder]){
        return NO;
    }
    else if (![self.delegate respondsToSelector:@selector(kiteControllerShouldAllowUserToAddMorePhotos:)]){
        return YES;
    }
    else{
        return [self.delegate kiteControllerShouldAllowUserToAddMorePhotos:[self kiteVc]];
    }
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    if ([self shouldShowAddMorePhotos]){
        return 2;
    }
    else{
        return 1;
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.section == [self sectionForImageCells]){
        UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"imageCell" forIndexPath:indexPath];
        
        for (UIView *view in cell.subviews){
            if ([view isKindOfClass:[OLRemoteImageView class]]){
                [view removeFromSuperview];
            }
        }
        
        OLRemoteImageView *imageView = [[OLRemoteImageView alloc] initWithFrame:CGRectMake(0, 0, 138, 138)];
        imageView.tag = 11;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        [cell addSubview:imageView];
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        NSDictionary *views = NSDictionaryOfVariableBindings(imageView);
        NSMutableArray *con = [[NSMutableArray alloc] init];
        
        NSArray *visuals = @[@"H:|-0-[imageView]-0-|",
                             @"V:|-0-[imageView]-0-|"];
        
        
        for (NSString *visual in visuals) {
            [con addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:visual options:0 metrics:nil views:views]];
        }
        
        [imageView.superview addConstraints:con];

        
        [self.userSelectedPhotos[indexPath.item] setImageSize:imageView.frame.size cropped:NO progress:^(float progress){
            [imageView setProgress:progress];
        }completionHandler:^(UIImage *image){
            dispatch_async(dispatch_get_main_queue(), ^{
                imageView.image = image;
            });
        }];
        
        return cell;
    }
    
    else {
        UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"moreCell" forIndexPath:indexPath];
        return cell;
    }
    
    
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    return CGSizeMake(collectionView.frame.size.height, collectionView.frame.size.height);
}

- (CGFloat) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section{
    return 0;
}

- (CGFloat) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section{
    return 0;
}

- (void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.section == [self sectionForImageCells]){
        UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
        OLRemoteImageView *imageView = (OLRemoteImageView *)[cell viewWithTag:11];
        if (!imageView.image){
            return;
        }
        
        OLPrintPhoto *printPhoto = self.userSelectedPhotos[indexPath.item];
        
        self.imageCropView.image = nil;
        [printPhoto getImageWithProgress:^(float progress){
//            [self.imageCropView setProgress:progress];
        }completion:^(UIImage *image){
            dispatch_async(dispatch_get_main_queue(), ^{
                self.imageCropView.image = image;
            });
        }];
    }
    else if ([self instagramEnabled] || [self facebookEnabled]){
        if ([UIAlertController class]){
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil message:NSLocalizedString(@"Add photos from:", @"") preferredStyle:UIAlertControllerStyleActionSheet];
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Camera Roll", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                [self showCameraRollImagePicker];
            }]];
            if ([self instagramEnabled]){
                [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Instagram", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                    [self showInstagramImagePicker];
                }]];
            }
            if ([self facebookEnabled]){
                [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Facebook", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                    [self showFacebookImagePicker];
                }]];
            }
            
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
                [ac dismissViewControllerAnimated:YES completion:NULL];
            }]];
            ac.popoverPresentationController.sourceView = collectionView;
            ac.popoverPresentationController.sourceRect = [collectionView cellForItemAtIndexPath:indexPath].frame;
            [self presentViewController:ac animated:YES completion:NULL];
        }
        else{
            UIActionSheet *as;
            if ([self instagramEnabled] && [self facebookEnabled]){
                as = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Add photos from:", @"") delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"Camera Roll", @""),
                      NSLocalizedString(@"Instagram", @""),
                      NSLocalizedString(@"Facebook", @""),
                      nil];
            }
            else if ([self instagramEnabled]){
                as = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Add photos from:", @"") delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"Camera Roll", @""),
                      NSLocalizedString(@"Instagram", @""),
                      nil];
            }
            else if ([self facebookEnabled]){
                as = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Add photos from:", @"") delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"Camera Roll", @""),
                      NSLocalizedString(@"Facebook", @""),
                      nil];
            }
            else{
                as = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Add photos from:", @"") delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"Camera Roll", @""),
                      nil];
            }
            [as showInView:self.view];
        }
    }
    else{
        [self showCameraRollImagePicker];
    }
}

- (NSArray *)createAssetArray {
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:self.userSelectedPhotos.count];
    for (OLPrintPhoto *object in self.userSelectedPhotos) {
        [array addObject:object.asset];
    }
    return array;
}

- (void)showCameraRollImagePicker{
    __block UIViewController *picker;
    __block Class assetClass;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 8 || !definesAtLeastiOS8){
        picker = [[OLAssetsPickerController alloc] init];
        [(OLAssetsPickerController *)picker setAssetsFilter:[ALAssetsFilter allPhotos]];
        assetClass = [ALAsset class];
        ((OLAssetsPickerController *)picker).delegate = self;
    }
#ifdef OL_KITE_AT_LEAST_IOS8
    else{
        if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusNotDetermined){
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status){
                if (status == PHAuthorizationStatusAuthorized){
                    picker = [[CTAssetsPickerController alloc] init];
                    ((CTAssetsPickerController *)picker).showsEmptyAlbums = NO;
                    PHFetchOptions *options = [[PHFetchOptions alloc] init];
                    options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
                    ((CTAssetsPickerController *)picker).assetsFetchOptions = options;
                    assetClass = [PHAsset class];
                    ((CTAssetsPickerController *)picker).delegate = self;
                    NSArray *allAssets = [[self createAssetArray] mutableCopy];
                    NSMutableArray *alAssets = [[NSMutableArray alloc] init];
                    for (id asset in allAssets){
                        if ([asset isKindOfClass:assetClass]){
                            [alAssets addObject:asset];
                        }
                    }
                    [(id)picker setSelectedAssets:alAssets];
                    [self presentViewController:picker animated:YES completion:nil];
                }
            }];
        }
        else{
            picker = [[CTAssetsPickerController alloc] init];
            ((CTAssetsPickerController *)picker).showsEmptyAlbums = NO;
            PHFetchOptions *options = [[PHFetchOptions alloc] init];
            options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
            ((CTAssetsPickerController *)picker).assetsFetchOptions = options;
            assetClass = [PHAsset class];
            ((CTAssetsPickerController *)picker).delegate = self;
        }
    }
#endif
    
    if (picker){
        NSArray *allAssets = [[self createAssetArray] mutableCopy];
        NSMutableArray *alAssets = [[NSMutableArray alloc] init];
        for (id asset in allAssets){
            if ([asset isKindOfClass:assetClass]){
                [alAssets addObject:asset];
            }
        }
        [(id)picker setSelectedAssets:alAssets];
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)showFacebookImagePicker{
#ifdef OL_KITE_OFFER_FACEBOOK
    OLFacebookImagePickerController *picker = nil;
    picker = [[OLFacebookImagePickerController alloc] init];
    picker.delegate = self;
    picker.selected = [self createAssetArray];
    [self presentViewController:picker animated:YES completion:nil];
#endif
}

- (void)showInstagramImagePicker{
#ifdef OL_KITE_OFFER_INSTAGRAM
    OLInstagramImagePickerController *picker = nil;
    picker = [[OLInstagramImagePickerController alloc] initWithClientId:[OLKitePrintSDK instagramClientID] secret:[OLKitePrintSDK instagramSecret] redirectURI:[OLKitePrintSDK instagramRedirectURI]];
    picker.delegate = self;
    picker.selected = [self createAssetArray];
    [self presentViewController:picker animated:YES completion:nil];
#endif
}

#pragma mark - CTAssetsPickerControllerDelegate Methods

- (void)populateArrayWithNewArray:(NSArray *)array dataType:(Class)class {
    NSMutableArray *photoArray = [[NSMutableArray alloc] initWithCapacity:array.count];
    NSMutableArray *assetArray = [[NSMutableArray alloc] initWithCapacity:array.count];
    
    for (id object in array) {
        OLPrintPhoto *printPhoto = [[OLPrintPhoto alloc] init];
        printPhoto.asset = object;
        [photoArray addObject:printPhoto];
        
        [assetArray addObject:[OLAsset assetWithPrintPhoto:printPhoto]];
    }
    
    // First remove any that are not returned.
    NSMutableArray *removeArray = [NSMutableArray arrayWithArray:self.userSelectedPhotos];
    for (OLPrintPhoto *object in self.userSelectedPhotos) {
        if (![object.asset isKindOfClass:class] || [photoArray containsObjectIdenticalTo:object]) {
            [removeArray removeObjectIdenticalTo:object];
        }
    }
    
    [self.userSelectedPhotos removeObjectsInArray:removeArray];
    
    // Second, add the remaining objects to the end of the array without replacing any.
    NSMutableArray *addArray = [NSMutableArray arrayWithArray:photoArray];
    NSMutableArray *addAssetArray = [NSMutableArray arrayWithArray:assetArray];
    for (id object in self.userSelectedPhotos) {
        OLAsset *asset = [OLAsset assetWithPrintPhoto:object];
        
        if ([addAssetArray containsObject:asset]){
            [addArray removeObjectAtIndex:[addAssetArray indexOfObject:asset]];
            [addAssetArray removeObject:asset];
        }
    }
    
    for (OLPrintPhoto *photo in addArray){
        if (![removeArray containsObject:photo]){
            self.imagePicked = photo;
            break;
        }
    }
    
    [self.userSelectedPhotos addObjectsFromArray:addArray];
    
    [self.imagesCollectionView reloadData];
}

- (OLKiteViewController *)kiteViewController {
    for (UIViewController *vc in self.navigationController.viewControllers) {
        if ([vc isMemberOfClass:[OLKiteViewController class]]) {
            return (OLKiteViewController *) vc;
        }
    }
    
    return nil;
}

#if __IPHONE_OS_VERSION_MIN_REQUIRED < 80000
- (BOOL)assetsPickerController:(OLAssetsPickerController *)picker isDefaultAssetsGroup:(ALAssetsGroup *)group {
    if ([self.delegate respondsToSelector:@selector(kiteController:isDefaultAssetsGroup:)]) {
        return [self.delegate kiteController:[self kiteViewController] isDefaultAssetsGroup:group];
    }
    
    return NO;
}
#endif

- (void)assetsPickerController:(id)picker didFinishPickingAssets:(NSArray *)assets {
    [self populateArrayWithNewArray:assets dataType:[picker isKindOfClass:[OLAssetsPickerController class]] ? [ALAsset class] : [PHAsset class]];
    if (self.imagePicked){
        [self.imagePicked getImageWithProgress:NULL completion:^(UIImage *image){
            dispatch_async(dispatch_get_main_queue(), ^{
                self.imageCropView.image = image;
            });
        }];
        self.imagePicked = nil;
    }
    [picker dismissViewControllerAnimated:YES completion:^(void){}];
    
}

- (BOOL)assetsPickerController:(OLAssetsPickerController *)picker shouldShowAssetsGroup:(ALAssetsGroup *)group{
    if (group.numberOfAssets == 0){
        return NO;
    }
    return YES;
}

#ifdef OL_KITE_AT_LEAST_IOS8
- (void)assetsPickerController:(CTAssetsPickerController *)picker didDeSelectAsset:(PHAsset *)asset{
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 8){
        return;
    }
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.networkAccessAllowed = YES;
    [[OLImageCachingManager sharedInstance].photosCachingManager stopCachingImagesForAssets:@[asset] targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeAspectFill options:options];
}

- (void)assetsPickerController:(CTAssetsPickerController *)picker didSelectAsset:(PHAsset *)asset{
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 8){
        return;
    }
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.networkAccessAllowed = YES;
    [[OLImageCachingManager sharedInstance].photosCachingManager startCachingImagesForAssets:@[asset] targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeAspectFill options:options];
}
#endif

- (BOOL)assetsPickerController:(OLAssetsPickerController *)picker shouldShowAsset:(id)asset{
    NSString *fileName = [[[asset defaultRepresentation] filename] lowercaseString];
    if (!([fileName hasSuffix:@".jpg"] || [fileName hasSuffix:@".jpeg"] || [fileName hasSuffix:@"png"])) {
        return NO;
    }
    return YES;
}

#ifdef OL_KITE_OFFER_INSTAGRAM
#pragma mark - OLInstagramImagePickerControllerDelegate Methods

- (void)instagramImagePicker:(OLInstagramImagePickerController *)imagePicker didFailWithError:(NSError *)error {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)instagramImagePicker:(OLInstagramImagePickerController *)imagePicker didFinishPickingImages:(NSArray *)images {
    [self populateArrayWithNewArray:images dataType:[OLInstagramImage class]];
    if (self.imagePicked){
        [self.imagePicked getImageWithProgress:NULL completion:^(UIImage *image){
            dispatch_async(dispatch_get_main_queue(), ^{
                self.imageCropView.image = image;
            });
        }];
        self.imagePicked = nil;
    }
    [self dismissViewControllerAnimated:YES completion:^(void){}];
}

- (void)instagramImagePickerDidCancelPickingImages:(OLInstagramImagePickerController *)imagePicker {
    [self dismissViewControllerAnimated:YES completion:nil];
}
#endif

#ifdef OL_KITE_OFFER_FACEBOOK
#pragma mark - OLFacebookImagePickerControllerDelegate Methods

- (void)facebookImagePicker:(OLFacebookImagePickerController *)imagePicker didFailWithError:(NSError *)error {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)facebookImagePicker:(OLFacebookImagePickerController *)imagePicker didFinishPickingImages:(NSArray *)images {
    [self populateArrayWithNewArray:images dataType:[OLFacebookImage class]];
    if (self.imagePicked){
        [self.imagePicked getImageWithProgress:NULL completion:^(UIImage *image){
            dispatch_async(dispatch_get_main_queue(), ^{
                self.imageCropView.image = image;
            });
        }];
        self.imagePicked = nil;
    }
    [self dismissViewControllerAnimated:YES completion:^(void){}];
}

- (void)facebookImagePickerDidCancelPickingImages:(OLFacebookImagePickerController *)imagePicker {
    [self dismissViewControllerAnimated:YES completion:nil];
}
#endif

#pragma mark UIActionSheet Delegate (only used on iOS 7)

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (buttonIndex == 0){
        [self showCameraRollImagePicker];
    }
    else if (buttonIndex == 1){
        if ([self instagramEnabled]){
            [self showInstagramImagePicker];
        }
        else{
            [self showFacebookImagePicker];
        }
    }
    else if (buttonIndex == 2){
        [self showFacebookImagePicker];
    }
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
