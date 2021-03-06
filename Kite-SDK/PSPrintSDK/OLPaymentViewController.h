//
//  PaymentViewController.h
//  Kite Print SDK
//
//  Created by Deon Botha on 06/01/2014.
//  Copyright (c) 2014 Ocean Labs. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OLCheckoutDelegate.h"
#import "OLKiteViewController.h"

@class OLPrintOrder;

@interface OLPaymentViewController : UIViewController

@property (weak, nonatomic) id<OLCheckoutDelegate> delegate;
@property (assign, nonatomic) BOOL showOtherOptions;

- (id)initWithPrintOrder:(OLPrintOrder *)printOrder;
@end
