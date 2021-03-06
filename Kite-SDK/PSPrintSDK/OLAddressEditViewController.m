//
//  OLAddressEditViewController.m
//  Kite SDK
//
//  Created by Deon Botha on 04/01/2014.
//  Copyright (c) 2014 Deon Botha. All rights reserved.
//

#import "OLAddressEditViewController.h"

#import "OLAddress+AddressBook.h"
#import "OLCountry.h"
#import "OLCountryPickerController.h"
#import "OLAddressSelectionViewController.h"
#import "OLAddressPickerController.h"

static const NSUInteger kTagTextField = 99;

@interface OLAddressSelectionViewController ()
@property (nonatomic, strong) OLAddress *addressToAddToListOnViewDidAppear;
@end

@interface OLAddressEditViewController () <UITextFieldDelegate, UINavigationControllerDelegate, OLCountryPickerControllerDelegate>
@property (nonatomic, strong) OLAddress *address;
@property (nonatomic, strong) OLAddress *originalAddress; // so we can restore if user returns without saving
@property (nonatomic, strong) UITextField *textFieldFirstName, *textFieldLastName, *textFieldLine1, *textFieldLine2, *textFieldCity, *textFieldCounty, *textFieldPostCode, *textFieldCountry;
@property (nonatomic, assign) BOOL editingExistingSavedAddress;
@property (nonatomic, assign) BOOL userSavedAddress;
@end

@implementation OLAddressEditViewController

- (id)init {
    return [self initWithAddress:nil];
}

- (id)initWithAddress:(OLAddress *)address {
    if (self = [super initWithStyle:UITableViewStyleGrouped]) {
        self.address = address;
        self.originalAddress = [address copy];
        self.userSavedAddress = NO;
        if (self.address == nil) {
            self.address = [[OLAddress alloc] init];
        }
        
        if (self.address.country == nil) {
            self.address.country = [OLCountry countryForCurrentLocale];
        }
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.editingExistingSavedAddress = self.address.isSavedInAddressBook;
    self.title = self.editingExistingSavedAddress ? NSLocalizedStringFromTableInBundle(@"Edit Address", @"KitePrintSDK", [NSBundle mainBundle], @"") : NSLocalizedStringFromTableInBundle(@"Add Address", @"KitePrintSDK", [NSBundle mainBundle], @"");
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:self.editingExistingSavedAddress ? NSLocalizedStringFromTableInBundle(@"Save", @"KitePrintSDK", [NSBundle mainBundle], @"") : NSLocalizedStringFromTableInBundle(@"Add", @"KitePrintSDK", [NSBundle mainBundle], @"") style:UIBarButtonItemStyleDone target:self action:@selector(onSaveButtonClicked)];
    self.navigationItem.rightBarButtonItem = doneButton;
    
    if ([self.navigationController.viewControllers firstObject] == self){
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Cancel", @"KitePrintSDK", [NSBundle mainBundle], @"") style:UIBarButtonItemStylePlain target:self action:@selector(onCancelButtonClicked)];
        self.navigationItem.leftBarButtonItem = cancelButton;
    }
    
    if ([self.tableView respondsToSelector:@selector(setCellLayoutMarginsFollowReadableWidth:)]){
        self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    }
}

- (void)didMoveToParentViewController:(UIViewController *)parent {
    if (parent == nil) {
        // we're being popped from the stack, possibly restore original address
        if (self.editingExistingSavedAddress && !self.userSavedAddress && self.originalAddress != nil) {
            self.address.recipientFirstName = self.originalAddress.recipientFirstName;
            self.address.recipientLastName = self.originalAddress.recipientLastName;
            self.address.line1 = self.originalAddress.line1;
            self.address.line2 = self.originalAddress.line2;
            self.address.city = self.originalAddress.city;
            self.address.stateOrCounty = self.originalAddress.stateOrCounty;
            self.address.zipOrPostcode = self.originalAddress.zipOrPostcode;
            self.address.country = self.originalAddress.country;
        }
    }
}

- (void)onSaveButtonClicked {
    if ([self isValidAddress]){
        [self saveAddressAndReturn];
    }
}

-(BOOL)isValidAddress{
    BOOL flag = YES;
    NSString *errorMessage;
    if ([self.textFieldFirstName.text isEqualToString:@""] || [self.textFieldLastName.text isEqualToString:@""]){
        flag = NO;
        errorMessage = NSLocalizedString(@"Please enter your first and last name.", @"");
    }
    else if ([self.textFieldLine1.text isEqualToString:@""]){
        flag = NO;
        errorMessage = NSLocalizedString(@"Please fill in Line 1 of the address.", @"");
    }
    else if ([self.textFieldPostCode.text isEqualToString:@""]){
        flag = NO;
        errorMessage = NSLocalizedString(@"Please fill in your postal code", @"");
    }

    if (!flag){
        if ([UIAlertController class]) // iOS 8 or greater
        {
            UIAlertController *alert= [UIAlertController
                                       alertControllerWithTitle:NSLocalizedString(@"", @"")
                                       message:errorMessage
                                       preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action){}];
            
            [alert addAction:ok];
            [self presentViewController:alert animated:YES completion:nil];
        }
        else{
            UIAlertView* dialog = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"", @"")
                                                             message:errorMessage
                                                            delegate:self
                                                   cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil, nil];
            [dialog show];
        }
    }
    
    
    return flag;
}

- (void)saveAddressAndReturn {
    self.userSavedAddress = YES;
    self.address.recipientFirstName = self.textFieldFirstName.text;
    self.address.recipientLastName = self.textFieldLastName.text;
    self.address.line1 = self.textFieldLine1.text;
    self.address.line2 = self.textFieldLine2.text;
    self.address.city = self.textFieldCity.text;
    self.address.stateOrCounty = self.textFieldCounty.text;
    self.address.zipOrPostcode = self.textFieldPostCode.text;
    
    OLAddressSelectionViewController *vc = self.navigationController.viewControllers[0];
    if ([vc.delegate respondsToSelector:@selector(addressSelectionController:didFinishPickingAddresses:)]){
        if (self.address.isSavedInAddressBook) {
            [self.address saveToAddressBook]; // save
            [vc.tableView reloadData];
        } else {
            vc.addressToAddToListOnViewDidAppear = self.address;
        }
        [self.address saveToAddressBook];
        if (vc.allowMultipleSelection){
            [self.navigationController popToRootViewControllerAnimated:YES];
        }
        else{
            [vc.delegate addressSelectionController:vc didFinishPickingAddresses:@[self.address]];
        }
    }
    else if ([vc.delegate respondsToSelector:@selector(addressPicker:didFinishPickingAddresses:)]){
        [self.address saveToAddressBook];
        [(id)(vc.delegate) addressPicker:nil didFinishPickingAddresses:@[self.address]];
    }
}

- (void)onCancelButtonClicked{
    OLAddressSelectionViewController *vc = self.navigationController.viewControllers[0];
    if ([vc.delegate respondsToSelector:@selector(addressSelectionControllerDidCancelPicking:)]){
        [vc.delegate addressSelectionControllerDidCancelPicking:vc];
    }
    else if ([vc.delegate respondsToSelector:@selector(addressPickerDidCancelPicking:)]){
        [(id)(vc.delegate) addressPickerDidCancelPicking:nil];
    }
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 7;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const kCellIdentifier = @"CellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.frame = CGRectMake(0, 0, self.view.frame.size.width, 43);
        
        UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(20, 0, cell.frame.size.width - 20, cell.frame.size.height)];
        tf.adjustsFontSizeToFitWidth = YES;
        tf.textColor = [UIColor blackColor];
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.textAlignment = NSTextAlignmentLeft;
        tf.tag = kTagTextField;
        tf.clearButtonMode = UITextFieldViewModeNever;
        tf.delegate = self;
        
        [cell.contentView addSubview:tf];
    }
    
    UITextField *tf = (UITextField *) [cell viewWithTag:kTagTextField];
    tf.enabled = YES;
    tf.returnKeyType = UIReturnKeyNext;
    cell.accessoryType = UITableViewCellAccessoryNone;
    tf.autocapitalizationType = UITextAutocapitalizationTypeWords;
    switch (indexPath.row) {
            case 0:
            [tf.superview removeConstraints:tf.superview.constraints];
            tf.translatesAutoresizingMaskIntoConstraints = YES;
            tf.text = self.address.recipientFirstName;
            tf.frame = CGRectMake(20, 0, ((cell.frame.size.width - 20) / 2.0)-10, cell.frame.size.height);
            tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTableInBundle(@"First Name", @"KitePrintSDK", [NSBundle mainBundle], @"") attributes:@{NSForegroundColorAttributeName : [UIColor colorWithRed:108.0/255.0 green:108.0/255.0 blue:108.0/255.0 alpha:1]}];
            self.textFieldFirstName = tf;
            
            self.textFieldLastName = [[UITextField alloc] initWithFrame:CGRectMake(((cell.frame.size.width - 20) / 2.0)+20, 0, (cell.frame.size.width - 20) / 2.0, cell.frame.size.height)];
            [cell.contentView addSubview:self.textFieldLastName];
            self.textFieldLastName.text = self.address.recipientLastName;
            self.textFieldLastName.returnKeyType = UIReturnKeyNext;
            self.textFieldLastName.adjustsFontSizeToFitWidth = YES;
            self.textFieldLastName.textColor = [UIColor blackColor];
            self.textFieldLastName.autocorrectionType = UITextAutocorrectionTypeNo;
            self.textFieldLastName.textAlignment = NSTextAlignmentLeft;
            self.textFieldLastName.tag = kTagTextField;
            self.textFieldLastName.clearButtonMode = UITextFieldViewModeNever;
            self.textFieldLastName.delegate = self;
            self.textFieldLastName.attributedPlaceholder = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTableInBundle(@"Last Name", @"KitePrintSDK", [NSBundle mainBundle], @"") attributes:@{NSForegroundColorAttributeName : [UIColor colorWithRed:108.0/255.0 green:108.0/255.0 blue:108.0/255.0 alpha:1]}];
            
            if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8){
                UIView *view = self.textFieldLastName;
                view.translatesAutoresizingMaskIntoConstraints = NO;
                tf.translatesAutoresizingMaskIntoConstraints = NO;
                NSDictionary *views = NSDictionaryOfVariableBindings(view, tf);
                NSMutableArray *con = [[NSMutableArray alloc] init];
                
                NSArray *visuals = @[@"H:|-20-[tf]-0-[view]-0-|"];
                
                
                for (NSString *visual in visuals) {
                    [con addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:visual options:0 metrics:nil views:views]];
                }
                
                NSLayoutConstraint *centerY = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:view.superview attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];
                [con addObject:centerY];
                
                [cell addConstraints:con];
                
                centerY = [NSLayoutConstraint constraintWithItem:tf attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:tf.superview attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];
                [cell addConstraint:centerY];
                
                [cell addConstraint:[NSLayoutConstraint constraintWithItem:tf attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.textFieldLastName attribute:NSLayoutAttributeWidth multiplier:1 constant:0]];
            }
            
            break;
        case 1:
            tf.text = self.address.line1;
            self.textFieldLine1 = tf;
            tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTableInBundle(@"Line 1", @"KitePrintSDK", [NSBundle mainBundle], @"") attributes:@{NSForegroundColorAttributeName : [UIColor colorWithRed:108.0/255.0 green:108.0/255.0 blue:108.0/255.0 alpha:1]}];
            break;
        case 2:
            tf.text = self.address.line2;
            self.textFieldLine2 = tf;
            tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTableInBundle(@"Line 2", @"KitePrintSDK", [NSBundle mainBundle], @"") attributes:@{NSForegroundColorAttributeName : [UIColor colorWithRed:108.0/255.0 green:108.0/255.0 blue:108.0/255.0 alpha:1]}];
            break;
        case 3:
            tf.text = self.address.city;
            self.textFieldCity = tf;
            tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTableInBundle(@"City", @"KitePrintSDK", [NSBundle mainBundle], @"") attributes:@{NSForegroundColorAttributeName : [UIColor colorWithRed:108.0/255.0 green:108.0/255.0 blue:108.0/255.0 alpha:1]}];
            break;
        case 4:
            if (self.address.country == [OLCountry countryForCode:@"USA"]) {
                tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"State" attributes:@{NSForegroundColorAttributeName : [UIColor colorWithRed:108.0/255.0 green:108.0/255.0 blue:108.0/255.0 alpha:1]}];
            } else {
                tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTableInBundle(@"County", @"KitePrintSDK", [NSBundle mainBundle], @"") attributes:@{NSForegroundColorAttributeName : [UIColor colorWithRed:108.0/255.0 green:108.0/255.0 blue:108.0/255.0 alpha:1]}];
            }
            tf.text = self.address.stateOrCounty;
            self.textFieldCounty = tf;
            break;
        case 5:
            if (self.address.country == [OLCountry countryForCode:@"USA"]) {
                tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTableInBundle(@"ZIP Code", @"KitePrintSDK", [NSBundle mainBundle], @"") attributes:@{NSForegroundColorAttributeName : [UIColor colorWithRed:108.0/255.0 green:108.0/255.0 blue:108.0/255.0 alpha:1]}];
            } else {
                tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTableInBundle(@"Postcode", @"KitePrintSDK", [NSBundle mainBundle], @"") attributes:@{NSForegroundColorAttributeName : [UIColor colorWithRed:108.0/255.0 green:108.0/255.0 blue:108.0/255.0 alpha:1]}];
            }
            tf.text = self.address.zipOrPostcode;
            tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
            self.textFieldPostCode = tf;
            break;
        case 6:
            tf.text = self.address.country.name;
            tf.enabled = NO;
            [tf setNeedsLayout];
            [tf setNeedsDisplay];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            tf.returnKeyType = UIReturnKeyDone;
            self.textFieldCountry = tf;
            break;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 6) {
        OLCountryPickerController *controller = [[OLCountryPickerController alloc] init];
        controller.delegate = self;
        OLCountry *selectedCountry = self.address.country;
        controller.selected = @[selectedCountry ? selectedCountry : [OLCountry countryForCode:@"GBR"]];
        [self presentViewController:controller animated:YES completion:nil];
    }
}

#pragma mark - OLCountryPickerControllerDelegate methods 

- (void)countryPicker:(OLCountryPickerController *)picker didSucceedWithCountries:(NSArray/*<OLCountry>*/ *)countries {
    [self dismissViewControllerAnimated:YES completion:nil];
    self.address.country = countries.lastObject;
    self.textFieldCountry.text = self.address.country.name;
    [self.tableView reloadData];
}

- (void)countryPickerDidCancelPicking:(OLCountryPickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITextFieldDelegate methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.textFieldFirstName) {
        [self.textFieldLastName becomeFirstResponder];
    } else if (textField == self.textFieldLastName) {
        [self.textFieldLine1 becomeFirstResponder];
    } else if (textField == self.textFieldLine1) {
        [self.textFieldLine2 becomeFirstResponder];
    } else if (textField == self.textFieldLine2) {
        [self.textFieldCity becomeFirstResponder];
    } else if (textField == self.textFieldCity) {
        [self.textFieldCounty becomeFirstResponder];
    } else if (textField == self.textFieldCounty) {
        [self.textFieldPostCode becomeFirstResponder];
    } else if (textField == self.textFieldPostCode) {
        [textField resignFirstResponder];
    } else if (textField == self.textFieldCountry) {
        [self saveAddressAndReturn];
    }
    
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *s = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (textField == self.textFieldFirstName) {
        self.address.recipientFirstName = s;
    }else if (textField == self.textFieldLastName) {
        self.address.recipientLastName = s;
    }else if (textField == self.textFieldLine1) {
        self.address.line1 = s;
    } else if (textField == self.textFieldLine2) {
        self.address.line2 = s;
    } else if (textField == self.textFieldCity) {
        self.address.city = s;
    } else if (textField == self.textFieldCounty) {
        self.address.stateOrCounty = s;
    } else if (textField == self.textFieldPostCode) {
        self.address.zipOrPostcode = s;
    }
    
    return YES;
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
