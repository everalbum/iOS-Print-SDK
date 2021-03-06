//
//  PrintStudio.m
//  Kite SDK
//
//  Created by Deon Botha on 19/12/2013.
//  Copyright (c) 2013 Deon Botha. All rights reserved.
//

#import "OLKitePrintSDK.h"
#import "OLPayPalCard.h"
#import "OLProductTemplate.h"
#ifdef OL_KITE_OFFER_PAYPAL
#import <PayPal-iOS-SDK/PayPalMobile.h>
#endif
#import "OLJudoPayCard.h"
#import "OLProductHomeViewController.h"
#import "OLIntegratedCheckoutViewController.h"
#import "OLKiteABTesting.h"
#import "OLAddressEditViewController.h"
#ifdef OL_KITE_OFFER_APPLE_PAY
#import <Stripe+ApplePay.h>
#endif
#import "OLPaymentViewController.h"
#import "OLKiteUtils.h"

static NSString *const kJudoClientId      = @"100170-877";
static NSString *const kJudoSandboxToken     = @"oLMiwCPBeLs0iVX4";
static NSString *const kJudoSandboxSecret  = @"3bf983df93ceb422bc81fd0289c3eb95ea1d39d990ba27306679ed069826805c";
static NSString *const kJudoLiveToken     = @"JjOZ49Z9XCYy2FAc";
static NSString *const kJudoLiveSecret  = @"b8d5950ec68e27e7dfdb314dbd7160e7421c3bddd4d883d9aef5e94788def934";

static NSString *apiKey = nil;
static NSString *const kOLStripePublishableKeyTest = @"pk_test_FxzXniUJWigFysP0bowWbuy3";
static NSString *const kOLStripePublishableKeyLive = @"pk_live_o1egYds0rWu43ln7FjEyOU5E";
static NSString *applePayMerchantID = nil;
static NSString *applePayPayToString = nil;
static OLKitePrintSDKEnvironment environment;

static NSString *const kOLAPIEndpointLive = @"https://api.kite.ly";
static NSString *const kOLAPIEndpointSandbox = @"https://api.kite.ly";
static NSString *const kOLPayPalClientIdLive = @"ASYVBBCHF_KwVUstugKy4qvpQaPlUeE_5beKRJHpIP2d3SA_jZrsaUDTmLQY";
static NSString *const kOLPayPalClientIdSandbox = @"AcEcBRDxqcCKiikjm05FyD4Sfi4pkNP98AYN67sr3_yZdBe23xEk0qhdhZLM";
static NSString *const kOLPayPalRecipientEmailLive = @"hello@kite.ly";
static NSString *const kOLPayPalRecipientEmailSandbox = @"sandbox-merchant@kite.ly";
static NSString *const kOLAPIEndpointVersion = @"v1.4";

static BOOL useJudoPayForGBP = NO;
static BOOL cacheTemplates = NO;

#ifdef OL_KITE_OFFER_INSTAGRAM
static NSString *instagramClientID = nil;
static NSString *instagramSecret = nil;
static NSString *instagramRedirectURI = nil;
#endif

@implementation OLKitePrintSDK

+ (BOOL)useJudoPayForGBP {
    return useJudoPayForGBP;
}

+ (void)setUseJudoPayForGBP:(BOOL)use {
    useJudoPayForGBP = use;
}

+ (void)setCacheTemplates:(BOOL)cache{
    if (!cache){
        [OLProductTemplate deleteCachedTemplates];
    }
    cacheTemplates = cache;
}

+ (BOOL)cacheTemplates{
    return cacheTemplates;
}

+ (void)setAPIKey:(NSString *_Nonnull)_apiKey withEnvironment:(OLKitePrintSDKEnvironment)_environment {
    apiKey = _apiKey;
    environment = _environment;
    if (environment == kOLKitePrintSDKEnvironmentLive) {
        [OLPayPalCard setClientId:[self paypalClientId] withEnvironment:kOLPayPalEnvironmentLive];
        [OLJudoPayCard setClientId:kJudoClientId token:kJudoLiveToken secret:kJudoLiveSecret withEnvironment:kOLJudoPayEnvironmentLive];
    } else {
        [OLPayPalCard setClientId:[self paypalClientId] withEnvironment:kOLPayPalEnvironmentSandbox];
        [OLJudoPayCard setClientId:kJudoClientId token:kJudoSandboxToken secret:kJudoSandboxSecret withEnvironment:kOLJudoPayEnvironmentSandbox];
    }
}

+ (NSString *_Nullable)apiKey {
    return apiKey;
}

+ (OLKitePrintSDKEnvironment)environment {
    return environment;
}

+ (NSString *)apiEndpoint {
    switch (environment) {
        case kOLKitePrintSDKEnvironmentLive: return kOLAPIEndpointLive;
        case kOLKitePrintSDKEnvironmentSandbox: return kOLAPIEndpointSandbox;
    }
}

+ (NSString *)apiVersion{
    return kOLAPIEndpointVersion;
}

#ifdef OL_KITE_OFFER_PAYPAL
+ (NSString *_Nonnull)paypalEnvironment {
    switch (environment) {
        case kOLKitePrintSDKEnvironmentLive: return PayPalEnvironmentProduction;
        case kOLKitePrintSDKEnvironmentSandbox: return PayPalEnvironmentSandbox;
    }
}
#endif

+ (NSString *_Nonnull)paypalClientId {
    switch (environment) {
        case kOLKitePrintSDKEnvironmentLive: return kOLPayPalClientIdLive;
        case kOLKitePrintSDKEnvironmentSandbox: return kOLPayPalClientIdSandbox;
    }
}

#ifdef OL_KITE_OFFER_APPLE_PAY
+ (void)setApplePayMerchantID:(NSString *_Nonnull)mID{
    applePayMerchantID = mID;
}

+ (void)setApplePayPayToString:(NSString *_Nonnull)name{
    applePayPayToString = name;
}

+ (NSString *)applePayPayToString{
    if (applePayPayToString){
        return applePayPayToString;
    }
    else{
        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        NSString *bundleName = nil;
        if ([info objectForKey:@"CFBundleDisplayName"] == nil) {
            bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *) kCFBundleNameKey];
        } else {
            bundleName = [NSString stringWithFormat:@"%@", [info objectForKey:@"CFBundleDisplayName"]];
        }
        
        return [NSString stringWithFormat:@"Kite.ly (via %@)", bundleName];
    }
}

+ (NSString *_Nonnull)stripePublishableKey {
    switch (environment) {
        case kOLKitePrintSDKEnvironmentLive: return kOLStripePublishableKeyLive;
        case kOLKitePrintSDKEnvironmentSandbox: return kOLStripePublishableKeyTest;
    }
}

+ (NSString *_Nonnull)appleMerchantID {
    return applePayMerchantID;
}
#endif

#pragma mark - Internal

#ifdef OL_KITE_OFFER_INSTAGRAM
+ (void)setInstagramEnabledWithClientID:(NSString *_Nonnull)clientID secret:(NSString *_Nonnull)secret redirectURI:(NSString *_Nonnull)redirectURI {
    instagramRedirectURI = redirectURI;
    instagramSecret = secret;
    instagramClientID = clientID;
}

+ (NSString *)instagramRedirectURI {
    return instagramRedirectURI;
}

+ (NSString *)instagramSecret{
    return instagramSecret;
}

+ (NSString *)instagramClientID{
    return instagramClientID;
}
#endif

@end
