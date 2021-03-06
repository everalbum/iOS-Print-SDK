//
//  OLAddressSelectionViewController.m
//  Kite SDK
//
//  Created by Deon Botha on 04/01/2014.
//  Copyright (c) 2014 Deon Botha. All rights reserved.
//

#import "OLAddressSelectionViewController.h"
#import "OLAddress.h"
#import "OLAddress+AddressBook.h"
#import "OLCountry.h"
#import "OLAddressEditViewController.h"
#import "OLAddressLookupViewController.h"
#import "OLConstants.h"
#import "UIImage+ImageNamedInKiteBundle.h"

static const NSInteger kSectionAddressList = 0;
static const NSInteger kSectionAddAddress = 1;

//static const NSInteger kRowAddAddressFromContacts = 0;
static const NSInteger kRowAddAddressSearch = 1;
static const NSInteger kRowAddAddressManually = 0;

@interface OLAddressSelectionViewController ()
@property (strong, nonatomic) NSMutableSet *selectedAddresses;
@property (strong, nonatomic) OLAddress *addressToAddToListOnViewDidAppear;
@end

@implementation OLAddressSelectionViewController

- (id)init {
    return [self initWithStyle:UITableViewStyleGrouped];
}

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        self.title = NSLocalizedStringFromTableInBundle(@"Choose Address", @"KitePrintSDK", [OLConstants bundle], @"");
        self.selectedAddresses = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.allowsMultipleSelection = self.allowMultipleSelection;
    self.allowMultipleSelection = _allowMultipleSelection;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Done", @"KitePrinSDK", [OLConstants bundle], @"") style:UIBarButtonItemStyleDone target:self action:@selector(onButtonCancelClicked)];
    if ([self.tableView respondsToSelector:@selector(setCellLayoutMarginsFollowReadableWidth:)]){
        self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    }
}

- (void)setAllowMultipleSelection:(BOOL)allowMultipleSelection {
    _allowMultipleSelection = allowMultipleSelection;
    self.tableView.allowsMultipleSelection = _allowMultipleSelection;
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (NSArray *)selected {
    return self.selectedAddresses.allObjects;
}

- (void)setSelected:(NSArray *)selected {
    [self.selectedAddresses removeAllObjects];
    [self.selectedAddresses addObjectsFromArray:selected];
    [self.tableView reloadData];
}

- (void)onButtonCancelClicked {
    if (self.selected.count > 0){
        if ([self.delegate respondsToSelector:@selector(addressSelectionController:didFinishPickingAddresses:)]){
            [self.delegate addressSelectionController:self didFinishPickingAddresses:self.selected];
        }
        else if ([self.delegate respondsToSelector:@selector(addressPicker:didFinishPickingAddresses:)]){
            [(id)(self.delegate) addressPicker:nil didFinishPickingAddresses:self.selected];
        }
    }
    else{
        if ([self.delegate respondsToSelector:@selector(addressSelectionControllerDidCancelPicking:)]){
            [self.delegate addressSelectionControllerDidCancelPicking:self];
        }
        else if ([self.delegate respondsToSelector:@selector(addressPickerDidCancelPicking:)]){
            [(id)(self.delegate) addressPickerDidCancelPicking:nil];
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [OLAddress addressBook].count > 0 ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([OLAddress addressBook].count == 0) { ++section; }
    if (section == 0) {
        return [OLAddress addressBook].count;
    } else {
        return self.allowAddressSearch ? 2 : 1;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ([OLAddress addressBook].count == 0) { ++section; }
    if (section == 0) {
        return [OLAddress addressBook].count > 0 ? NSLocalizedStringFromTableInBundle(@"Address Book", @"KitePrintSDK", [OLConstants bundle], "") : nil;
    } else {
        return NSLocalizedStringFromTableInBundle(@"Add New Address", @"KitePrintSDK", [OLConstants bundle], @"");
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([OLAddress addressBook].count == 0) { indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section + 1]; }
    UITableViewCell *cell = nil;
    if(indexPath.section == kSectionAddressList) {
        static NSString *kAddressCellIdentifier = @"AddressCell";
        cell = [tableView dequeueReusableCellWithIdentifier:kAddressCellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kAddressCellIdentifier];
            cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        }
        
        OLAddress *address = [OLAddress addressBook][indexPath.row];
        
        cell.imageView.image = [self.selectedAddresses containsObject:address] ? [UIImage imageNamedInKiteBundle:@"checkmark_on"] : nil;
        cell.textLabel.text = address.fullNameFromFirstAndLast;
        cell.detailTextLabel.text = address.descriptionWithoutRecipient;
    } else {
        NSAssert(indexPath.section == kSectionAddAddress, @"oops");
        static NSString *kManageCellIdentifier = @"ManageCell";
        cell = [tableView dequeueReusableCellWithIdentifier:kManageCellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kManageCellIdentifier];
        }
        
        if (indexPath.row == kRowAddAddressSearch) {
            cell.textLabel.text = NSLocalizedStringFromTableInBundle(@"Search for Address", @"KitePrintSDK", [OLConstants bundle], @"");
        } else {
            cell.textLabel.text = NSLocalizedStringFromTableInBundle(@"Enter Address Manually", @"KitePrintSDK", [OLConstants bundle], @"");
        }
        
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.textLabel.textColor = [UIColor colorWithRed:0 / 255.0 green:122 / 255.0 blue:255 / 255.0 alpha:1.0];
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([OLAddress addressBook].count == 0) { indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section + 1]; }
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        OLAddress *address = [OLAddress addressBook][indexPath.row];
        [address deleteFromAddressBook];
        NSArray *deleteIndexPaths = [[NSArray alloc] initWithObjects:indexPath, nil];
        if ([OLAddress addressBook].count == 0) {
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
        } else {
            [self.tableView deleteRowsAtIndexPaths:deleteIndexPaths withRowAnimation:UITableViewRowAnimationFade];
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([OLAddress addressBook].count == 0) { indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section + 1]; }
    return indexPath.section == kSectionAddressList;
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([OLAddress addressBook].count == 0) { indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section + 1]; }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == kSectionAddressList) {
        if (!self.allowMultipleSelection) {
            OLAddress *address = [OLAddress addressBook][indexPath.row];
            self.selected = @[address];
            [self onButtonCancelClicked];
        } else {
            OLAddress *address = [OLAddress addressBook][indexPath.row];
            BOOL selected = YES;
            if ([self.selectedAddresses containsObject:address]) {
                selected = NO;
                [self.selectedAddresses removeObject:address];
            } else {
                [self.selectedAddresses addObject:address];
            }
            
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            cell.imageView.image = selected ? [UIImage imageNamedInKiteBundle:@"checkmark_on"] : nil;
        }
    } else if (indexPath.section == kSectionAddAddress) {
        
        if (indexPath.row == kRowAddAddressManually) {
            [self.navigationController pushViewController:[[OLAddressEditViewController alloc] init] animated:YES];
        } else if (indexPath.row == kRowAddAddressSearch) {
            [self.navigationController pushViewController:[[OLAddressLookupViewController alloc] init] animated:YES];
        }
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    if ([OLAddress addressBook].count == 0) { indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section + 1]; }
    if (indexPath.section == kSectionAddressList) {
        OLAddress *address = [OLAddress addressBook][indexPath.row];
        [self.navigationController pushViewController:[[OLAddressEditViewController alloc] initWithAddress:address] animated:YES];
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
