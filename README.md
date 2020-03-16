
# iOS Setup guide

## How to install

### CocoaPods
:heavy_exclamation_mark: **IMPORTANT** if you're not yet using the new message builder, make sure to use pod version < 3.
```
pod 'ConsentViewController', '< 3.0.0'
```
The README for the older version can be found [here](https://github.com/SourcePointUSA/ios-cmp-app/blob/d3c999a2245d2e5660806321c3979eaa32838642/README.md).


We strongly recommend the use of [CocoaPods](https://cocoapods.org) in order to install our SDK.
In your `Podfile` add the following line to your app target:

```
pod 'ConsentViewController', '4.1.3'
```
### Carthage
We also support [Carthage](https://github.com/Carthage/Carthage). It requires a couple more steps to install so we dedicated a whole [wiki page](https://github.com/SourcePointUSA/ios-cmp-app/wiki/Carthage-SDK-integration-guide) for it.
Let us know if we missed any step.

## How to use it

It's pretty simple, here are 5 easy steps for you:

1. implement the `GDPRConsentDelegate` protocol
2. instantiate the `GDPRConsentViewController` with your Account ID, property id, property, privacy manager id, campaign environment, a flag to show the privacy manager directly or not and the consent delegate
3. call `.loadMessage()`
4. present the controller when the message is ready to be displayed
5. profit!

### Swift
```swift
import UIKit
import ConsentViewController

class ViewController: UIViewController, GDPRConsentDelegate {
    lazy var consentViewController: GDPRConsentViewController = { return GDPRConsentViewController(
        accountId: 22,
        propertyId: 2372,
        propertyName: try! GDPRPropertyName("mobile.demo"),
        PMId: "5c0e81b7d74b3c30c6852301",
        campaignEnv: .Stage,
        consentDelegate: self
    )}()
    
    func gdprConsentUIWillShow() {
        present(consentViewController, animated: true, completion: nil)
    }

    func consentUIDidDisappear() {
        dismiss(animated: true, completion: nil)
    }
    
    func onConsentReady(gdprUUID: GDPRUUID, userConsent: GDPRUserConsent) {
        print("ConsentUUID: \(gdprUUID)")
        userConsent.acceptedVendors.forEach({ vendorId in print("Vendor: \(vendorId)") })
        userConsent.acceptedCategories.forEach({ purposeId in print("Purpose: \(purposeId)") })
        print("Consent String: \(UserDefaults.standard.string(forKey: GDPRConsentViewController.IAB_CONSENT_CONSENT_STRING) ?? "<empty>")")
    }

    func onError(error: GDPRConsentViewControllerError?) {
        print("Error: \(error.debugDescription)")
    }

    @IBAction func onPrivacySettingsTap(_ sender: Any) {
        consentViewController.loadPrivacyManager()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        consentViewController.loadMessage()
    }
}
```

### Objective-C
```obj-c

#import "ViewController.h"
@import ConsentViewController;

@interface ViewController ()<GDPRConsentDelegate> {
    GDPRConsentViewController *cvc;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    GDPRPropertyName *propertyName = [[GDPRPropertyName alloc] init:@"mobile.demo" error:NULL];

    cvc = [[GDPRConsentViewController alloc]
           initWithAccountId:22
           propertyId:2372
           propertyName:propertyName
           PMId:@"5c0e81b7d74b3c30c6852301"
           campaignEnv:GDPRCampaignEnvStage
           consentDelegate:self];

    [cvc loadMessage];
}

- (void)onConsentReadyWithGdprUUID:(NSString *)gdprUUID userConsent:(GDPRUserConsent *)userConsent {
    NSLog(@"ConsentUUID: %@", gdprUUID);
    NSLog(@"ConsentString: %@", userConsent.euconsent.consentString);
    for (id vendorId in userConsent.acceptedVendors) {
        NSLog(@"Consented to Vendor(id: %@)", vendorId);
    }
    for (id purposeId in userConsent.acceptedCategories) {
        NSLog(@"Consented to Purpose(id: %@)", purposeId);
    }
}
                                  
- (void)gdprConsentUIWillShow {
    [self presentViewController:cvc animated:true completion:NULL];
}

- (void)consentUIDidDisappear {
    [self dismissViewControllerAnimated:true completion:nil];
}
@end
```

### Authenticated Consent

In order to use the authenticated consent all you need to do is replace `.loadMessage()` with `.loadMessage(forAuthId: String)`. Example:

```swift
  consentViewController.loadMessage(forAuthId: "JohnDoe")
```

In Obj-C that'd be: 
```objc
  [consentViewController loadMessage forAuthId: @"JohnDoe"]
```

This way, if we already have consent for that token (`"JohDoe"`) we'll bring the consent profile from the server, overwriting whatever was stored in the device.

### Rendering the message natively

Have a look at this neat [wiki](https://github.com/SourcePointUSA/ios-cmp-app/wiki/Rendering-consent-message-natively) we put together. 
