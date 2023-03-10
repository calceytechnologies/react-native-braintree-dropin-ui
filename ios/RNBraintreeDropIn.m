#import "RNBraintreeDropIn.h"
#import <React/RCTUtils.h>
#import "BTThreeDSecureRequest.h"
#import "BTCard.h"
#import "BTCardClient.h"
#import "BTAPIClient.h"

@implementation RNBraintreeDropIn

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE(RNBraintreeDropIn)

RCT_EXPORT_METHOD(isApplePayAvailable: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    
    self.resolve = resolve;
    self.reject = reject;

    NSNumber *result=[NSNumber numberWithBool:NO];

    if ([PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:@[PKPaymentNetworkVisa, PKPaymentNetworkMasterCard, PKPaymentNetworkAmex, PKPaymentNetworkDiscover]]) {
        result=[NSNumber numberWithBool:YES];
        resolve(result);
        
    } else {
        resolve(result);
    }
    
}

RCT_EXPORT_METHOD(paypalLogin:(NSDictionary*)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    self.resolve = resolve;
    self.reject = reject;

    NSString* clientToken = options[@"clientToken"];
    if (!clientToken) {
        reject(@"NO_CLIENT_TOKEN", @"You must provide a client token", nil);
        return;
    }
    
    
    BTAPIClient *apiClient = [[BTAPIClient alloc] initWithAuthorization:clientToken];
    self.dataCollector = [[BTDataCollector alloc] initWithAPIClient:apiClient];
    [self.dataCollector collectCardFraudData:^(NSString * _Nonnull deviceDataCollector) {
        // Save deviceData
        self.deviceDataCollector = deviceDataCollector;
    }];
    
    self.braintreeClient = apiClient;
    BTPayPalDriver *payPalDriver = [[BTPayPalDriver alloc] initWithAPIClient:self.braintreeClient];
    payPalDriver.viewControllerPresentingDelegate = self;
//    payPalDriver.appSwitchDelegate = self; // Optional
    
    BTPayPalRequest *checkout = [[BTPayPalRequest alloc] init];
    checkout.billingAgreementDescription = @"Your agreement description";
    [payPalDriver requestBillingAgreement:checkout completion:^(BTPayPalAccountNonce * _Nullable tokenizedPayPalCheckout, NSError * _Nullable error) {
        if (error) {
            reject(error.localizedDescription, error.localizedDescription, error);
        } else if (tokenizedPayPalCheckout) {
            [[self class] resolvePayPalLogin:tokenizedPayPalCheckout deviceData:self.deviceDataCollector resolver:resolve];
        } else {
            reject(@"USER_CANCELLATION", @"The process was cancelled by the user", nil);
        }
    }];
}

+ (void)resolvePayPalLogin:(BTPayPalAccountNonce* _Nullable)tokenizedPayPalCheckout deviceData:(NSString * _Nonnull)deviceDataCollector resolver:(RCTPromiseResolveBlock _Nonnull)resolve {
    NSMutableDictionary* result = [NSMutableDictionary new];
    [result setObject:tokenizedPayPalCheckout.nonce forKey:@"nonce"];
    [result setObject:@"PayPal" forKey:@"type"];
    [result setObject:[NSString stringWithFormat: @"%@ %@", @"", tokenizedPayPalCheckout.type] forKey:@"description"];
    [result setObject:[NSNumber numberWithBool:false] forKey:@"isDefault"];
    [result setObject:deviceDataCollector forKey:@"deviceData"];

    resolve(result);
}

RCT_EXPORT_METHOD(show:(NSDictionary*)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{

    if([options[@"darkTheme"] boolValue]){
        if (@available(iOS 13.0, *)) {
            BTUIKAppearance.sharedInstance.colorScheme = BTUIKColorSchemeDynamic;
        } else {
            BTUIKAppearance.sharedInstance.colorScheme = BTUIKColorSchemeDark;
        }
    } else {
        BTUIKAppearance.sharedInstance.colorScheme = BTUIKColorSchemeLight;
    }

    if(options[@"fontFamily"]){
        [BTUIKAppearance sharedInstance].fontFamily = options[@"fontFamily"];
    }
    if(options[@"boldFontFamily"]){
        [BTUIKAppearance sharedInstance].boldFontFamily = options[@"boldFontFamily"];
    }

    self.resolve = resolve;
    self.reject = reject;
    self.applePayAuthorized = NO;

    NSString* clientToken = options[@"clientToken"];
    if (!clientToken) {
        reject(@"NO_CLIENT_TOKEN", @"You must provide a client token", nil);
        return;
    }

    BTDropInRequest *request = [[BTDropInRequest alloc] init];

    NSDictionary* threeDSecureOptions = options[@"threeDSecure"];
    if (threeDSecureOptions) {
        NSNumber* threeDSecureAmount = threeDSecureOptions[@"amount"];
        if (!threeDSecureAmount) {
            reject(@"NO_3DS_AMOUNT", @"You must provide an amount for 3D Secure", nil);
            return;
        }

        request.threeDSecureVerification = YES;
        BTThreeDSecureRequest *threeDSecureRequest = [[BTThreeDSecureRequest alloc] init];
        threeDSecureRequest.amount = [NSDecimalNumber decimalNumberWithString:threeDSecureAmount.stringValue];
        request.threeDSecureRequest = threeDSecureRequest;

    }

    BTAPIClient *apiClient = [[BTAPIClient alloc] initWithAuthorization:clientToken];
    self.dataCollector = [[BTDataCollector alloc] initWithAPIClient:apiClient];
    [self.dataCollector collectCardFraudData:^(NSString * _Nonnull deviceDataCollector) {
        // Save deviceData
        self.deviceDataCollector = deviceDataCollector;
    }];

    if([options[@"vaultManager"] boolValue]){
        request.vaultManager = YES;
    }

    if([options[@"cardDisabled"] boolValue]){
        request.cardDisabled = YES;
    }

    if([options[@"applePay"] boolValue]){
        NSString* merchantIdentifier = options[@"merchantIdentifier"];
        NSString* countryCode = options[@"countryCode"];
        NSString* currencyCode = options[@"currencyCode"];
        NSString* merchantName = options[@"merchantName"];
        NSDecimalNumber* orderTotal = [NSDecimalNumber decimalNumberWithDecimal:[options[@"orderTotal"] decimalValue]];
        if(!merchantIdentifier || !countryCode || !currencyCode || !merchantName || !orderTotal){
            reject(@"MISSING_OPTIONS", @"Not all required Apple Pay options were provided", nil);
            return;
        }
        self.braintreeClient = [[BTAPIClient alloc] initWithAuthorization:clientToken];

        self.paymentRequest = [[PKPaymentRequest alloc] init];
        self.paymentRequest.merchantIdentifier = merchantIdentifier;
        self.paymentRequest.merchantCapabilities = PKMerchantCapability3DS;
        self.paymentRequest.countryCode = countryCode;
        self.paymentRequest.currencyCode = currencyCode;
        self.paymentRequest.supportedNetworks = @[PKPaymentNetworkAmex, PKPaymentNetworkVisa, PKPaymentNetworkMasterCard, PKPaymentNetworkDiscover, PKPaymentNetworkChinaUnionPay];
        self.paymentRequest.paymentSummaryItems =
            @[
                [PKPaymentSummaryItem summaryItemWithLabel:merchantName amount:orderTotal]
            ];

        self.viewController = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest: self.paymentRequest];
        self.viewController.delegate = self;
    }else{
        request.applePayDisabled = YES;
    }
    
    if(![options[@"payPal"] boolValue]){ //disable paypal
        request.paypalDisabled = YES;
    }

    BTDropInController *dropIn = [[BTDropInController alloc] initWithAuthorization:clientToken request:request handler:^(BTDropInController * _Nonnull controller, BTDropInResult * _Nullable result, NSError * _Nullable error) {
            [self.reactRoot dismissViewControllerAnimated:YES completion:nil];

            //result.paymentOptionType == .ApplePay
            //NSLog(@"paymentOptionType = %ld", result.paymentOptionType);

            if (error != nil) {
                reject(error.localizedDescription, error.localizedDescription, error);
            } else if (result.cancelled) {
                reject(@"USER_CANCELLATION", @"The process was cancelled by the user", nil);
            } else {
                if (threeDSecureOptions && [result.paymentMethod isKindOfClass:[BTCardNonce class]]) {
                    BTCardNonce *cardNonce = (BTCardNonce *)result.paymentMethod;
                    if (!cardNonce.threeDSecureInfo.liabilityShiftPossible && cardNonce.threeDSecureInfo.wasVerified) {
                        reject(@"3DSECURE_NOT_ABLE_TO_SHIFT_LIABILITY", @"3D Secure liability cannot be shifted", nil);
                    } else if (!cardNonce.threeDSecureInfo.liabilityShifted && cardNonce.threeDSecureInfo.wasVerified) {
                        reject(@"3DSECURE_LIABILITY_NOT_SHIFTED", @"3D Secure liability was not shifted", nil);
                    } else{
                        [[self class] resolvePayment:result deviceData:self.deviceDataCollector resolver:resolve];
                    }
                } else if(result.paymentMethod == nil && (result.paymentOptionType == 16 || result.paymentOptionType == 18)){ //Apple Pay
                    // UIViewController *ctrl = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
                    // [ctrl presentViewController:self.viewController animated:YES completion:nil];
                    UIViewController *rootViewController = RCTPresentedViewController();
                    [rootViewController presentViewController:self.viewController animated:YES completion:nil];
                } else{
                    [[self class] resolvePayment:result deviceData:self.deviceDataCollector resolver:resolve];
                }
            }
        }];

    if (dropIn != nil) {
        [self.reactRoot presentViewController:dropIn animated:YES completion:nil];
    } else {
        reject(@"INVALID_CLIENT_TOKEN", @"The client token seems invalid", nil);
    }
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                       didAuthorizePayment:(PKPayment *)payment
                                completion:(void (^)(PKPaymentAuthorizationStatus))completion
{

    // Example: Tokenize the Apple Pay payment
    BTApplePayClient *applePayClient = [[BTApplePayClient alloc]
                                        initWithAPIClient:self.braintreeClient];
    [applePayClient tokenizeApplePayPayment:payment
                                 completion:^(BTApplePayCardNonce *tokenizedApplePayPayment,
                                              NSError *error) {
        if (tokenizedApplePayPayment) {
            // On success, send nonce to your server for processing.
            // If applicable, address information is accessible in `payment`.
            // NSLog(@"description = %@", tokenizedApplePayPayment.localizedDescription);

            completion(PKPaymentAuthorizationStatusSuccess);
            self.applePayAuthorized = YES;


            NSMutableDictionary* result = [NSMutableDictionary new];
            [result setObject:tokenizedApplePayPayment.nonce forKey:@"nonce"];
            [result setObject:@"Apple Pay" forKey:@"type"];
            [result setObject:[NSString stringWithFormat: @"%@ %@", @"", tokenizedApplePayPayment.type] forKey:@"description"];
            [result setObject:[NSNumber numberWithBool:false] forKey:@"isDefault"];
            [result setObject:self.deviceDataCollector forKey:@"deviceData"];

            self.resolve(result);

        } else {
            // Tokenization failed. Check `error` for the cause of the failure.

            // Indicate failure via the completion callback:
            completion(PKPaymentAuthorizationStatusFailure);
        }
    }];
}

// Be sure to implement -paymentAuthorizationViewControllerDidFinish:
- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller{
    [self.reactRoot dismissViewControllerAnimated:YES completion:nil];
    if(self.applePayAuthorized == NO){
        self.reject(@"USER_CANCELLATION", @"The process was cancelled by the user", nil);
    }
}

+ (void)resolvePayment:(BTDropInResult* _Nullable)result deviceData:(NSString * _Nonnull)deviceDataCollector resolver:(RCTPromiseResolveBlock _Nonnull)resolve {
    //NSLog(@"result = %@", result);

    NSMutableDictionary* jsResult = [NSMutableDictionary new];

    //NSLog(@"paymentMethod = %@", result.paymentMethod);
    //NSLog(@"paymentIcon = %@", result.paymentIcon);

    [jsResult setObject:result.paymentMethod.nonce forKey:@"nonce"];
    [jsResult setObject:result.paymentMethod.type forKey:@"type"];
    [jsResult setObject:result.paymentDescription forKey:@"description"];
    [jsResult setObject:[NSNumber numberWithBool:result.paymentMethod.isDefault] forKey:@"isDefault"];
    [jsResult setObject:deviceDataCollector forKey:@"deviceData"];

    resolve(jsResult);
}

- (UIViewController*)reactRoot {
    UIViewController *root  = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *maybeModal = root.presentedViewController;

    UIViewController *modalRoot = root;

    if (maybeModal != nil) {
        modalRoot = maybeModal;
    }

    return modalRoot;
}


RCT_EXPORT_METHOD(tokenize:(NSString *)authorization options:(NSDictionary*)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    BTAPIClient *braintreeClient = [[BTAPIClient alloc] initWithAuthorization:authorization];
    BTCardClient *cardClient = [[BTCardClient alloc] initWithAPIClient:braintreeClient];
    BTCard *card = [[BTCard alloc] initWithNumber:options[@"number"] expirationMonth:options[@"expirationMonth"] expirationYear:options[@"expirationYear"] cvv:options[@"cvv"]];
    
    if (options[@"cardholderName"])
        card.cardholderName = options[@"cardholderName"];

    if (options[@"firstName"])
        card.firstName = options[@"firstName"];

    if (options[@"lastName"])
        card.lastName = options[@"lastName"];

    if (options[@"company"])
        card.company = options[@"company"];
    
    if (options[@"locality"])
        card.locality = options[@"locality"];

    if (options[@"postalCode"])
        card.postalCode = options[@"postalCode"];

    if (options[@"region"])
        card.region = options[@"region"];

    if (options[@"streetAddress"])
        card.streetAddress = options[@"streetAddress"];

    if (options[@"extendedAddress"])
        card.extendedAddress = options[@"extendedAddress"];

    if (options[@"shouldValidate"])
        card.shouldValidate = options[@"shouldValidate"];
    
    if (options[@"merchantAccountId"])
        card.merchantAccountId = options[@"merchantAccountId"];
    
    if (options[@"countryName"])
        card.countryName = options[@"countryName"];
    
    if (options[@"countryCodeAlpha2"])
        card.countryCodeAlpha2 = options[@"countryCodeAlpha2"];
    
    if (options[@"countryCodeAlpha3"])
        card.countryCodeAlpha3 = options[@"countryCodeAlpha3"];
    
    if (options[@"countryCode"])
        card.countryCodeAlpha3 = options[@"countryCode"];
    
    if (authorization == nil || braintreeClient == nil || cardClient == nil || card == nil) {
        NSError * err = [NSError errorWithDomain:@"BraintreeAuth" code:01 userInfo:@{@"message": @"Auth not valid"}];
        reject(@"01", @"Auth not valid", err);
    } else {
        [cardClient tokenizeCard:card
                      completion:^(BTCardNonce *tokenizedCard, NSError *error) {
            if (!error) {
                NSMutableDictionary* result = [NSMutableDictionary new];
                [result setObject:tokenizedCard.nonce forKey:@"nonce"];
                [result setObject:[NSString stringWithFormat: @"%@ %@", @"", tokenizedCard.type] forKey:@"description"];
                [result setObject:[NSNumber numberWithBool:false] forKey:@"isDefault"];
                if (self.deviceDataCollector) {
                    [result setObject:self.deviceDataCollector forKey:@"deviceData"];
                }
                resolve(result);
            } else {
                reject(@"0", @"Card details not valid", error);
            }
        }];
    }
}

@end
