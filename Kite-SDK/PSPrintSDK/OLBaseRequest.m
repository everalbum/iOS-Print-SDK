//
//  OLBaseRequest.m
//  Kite SDK
//
//  Created by Deon Botha on 19/12/2013.
//  Copyright (c) 2013 Deon Botha. All rights reserved.
//

#import "OLBaseRequest.h"
#import "OLConstants.h"

@interface OLBaseRequest () <NSURLConnectionDelegate>

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, strong) NSURLConnection *conn;
@property (nonatomic, assign) BOOL cancelled;
@property (nonatomic, assign) BOOL started;
@property (nonatomic, assign) NSInteger responseHTTPStatusCode;
@property (nonatomic, assign) OLHTTPMethod httpMethod;
@property (nonatomic, strong) NSString *requestBody;
@property (nonatomic, strong) OLBaseRequestHandler handler;
@property (nonatomic, strong) NSDictionary *requestHeaders;
@end

static NSString *httpMethodString(OLHTTPMethod method) {
    switch (method) {
        case kOLHTTPMethodGET:
            return @"GET";
        case kOLHTTPMethodPOST:
            return @"POST";
        case kOLHTTPMethodPATCH:
            return @"PATCH";
    }
}

@implementation OLBaseRequest

- (id)initWithURL:(NSURL *)url httpMethod:(OLHTTPMethod)method headers:(NSDictionary *)headers body:(NSString *)body {
    if (self = [super init]) {
        self.url = url;
        self.cancelled = NO;
        self.started = NO;
        self.httpMethod = method;
        self.requestBody = body;
        self.requestHeaders = headers;
        if (self.requestBody != nil) {
            NSAssert(method == kOLHTTPMethodPOST || method == kOLHTTPMethodPATCH, @"Request body non nil for HTTP %@ method", httpMethodString(method));
        }
    }
    
    return self;
}

- (void)startWithCompletionHandler:(OLBaseRequestHandler)handler {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    NSAssert(!self.cancelled, @"Cannot restart a previously cancelled request");
    NSAssert(!self.started, @"Cannot start a request twice");
    self.started = YES;
    self.responseData = [[NSMutableData alloc] init];
    self.handler = handler;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url];
    request.HTTPMethod = httpMethodString(self.httpMethod);
    if (self.requestBody) {
        request.HTTPBody = [self.requestBody dataUsingEncoding:NSUTF8StringEncoding];
        
        // set Content-Type depending on what the content is.
        NSData *data = [self.requestBody dataUsingEncoding:NSUTF8StringEncoding];
        id jsonObj = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        
        if ([NSJSONSerialization isValidJSONObject:jsonObj]) {
            [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        } else {
            [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        }
        
        [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[request.HTTPBody length]] forHTTPHeaderField:@"Content-Length"];
    }
    
    [request setValue:[NSString stringWithFormat: @"Kite SDK iOS v%@", kOLKiteSDKVersion] forHTTPHeaderField:@"User-Agent"];
    [request setValue:[[NSBundle mainBundle] bundleIdentifier] forHTTPHeaderField:@"X-App-Bundle-Id"];
    [request setValue:[self appName] forHTTPHeaderField:@"X-App-Name"];
    for (NSString *key in self.requestHeaders.allKeys) {
        NSString *value = self.requestHeaders[key];
        [request setValue:value forHTTPHeaderField:key];
    }
    
    self.conn = [NSURLConnection connectionWithRequest:request delegate:self];
}

- (NSString *)appName {
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *bundleName = nil;
    if ([info objectForKey:@"CFBundleDisplayName"] == nil) {
        bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *) kCFBundleNameKey];
    } else {
        bundleName = [NSString stringWithFormat:@"%@", [info objectForKey:@"CFBundleDisplayName"]];
    }
    
    return bundleName;
}

- (void)cancel {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    NSAssert(!self.cancelled, @"Cannot cancel a previously cancelled request");
    NSAssert(self.started, @"Cannot cancel a request that has not been started");
    self.cancelled = YES;
    [self.conn cancel];
    self.conn = nil;
    self.responseData = nil;
}

#pragma mark - NSURLConnectionDelegate Methods

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    if (self.cancelled) {
        return;
    }
    
    if (self.handler) self.handler(0, nil, error);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    self.responseHTTPStatusCode = httpResponse.statusCode;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    NSError *parsingError;
    id json = [NSJSONSerialization JSONObjectWithData:self.responseData options:0 error:&parsingError];
    
    if (self.responseHTTPStatusCode == 503 /*Heroku maintence mode status code*/) {
        parsingError = [NSError errorWithDomain:kOLKiteSDKErrorDomain code:kOLKiteSDKErrorCodeMaintenanceMode userInfo:@{NSLocalizedDescriptionKey: kOLKiteSDKErrorMessageMaintenanceMode}];
    }
    
    if (parsingError) {
        if (self.handler) self.handler(self.responseHTTPStatusCode, nil, parsingError);
        return;
    }
    
    if (self.handler) self.handler(self.responseHTTPStatusCode, json, nil);
}

@end
