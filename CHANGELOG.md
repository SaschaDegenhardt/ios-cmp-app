## 2.0.1 (March 21, 2019)
* We now call `done()` always **after** `onErrorOccurred`

## 2.0.0 (March 15, 2019)
Look at that, we barely released version 1.x and we're already launching v2.0 🎉

This is a major release that includes several bug fixes and improved stability.
* Much better error handling.
* Major internal refactoring and code simplification.
* Dramatically reduce forced optional unwrapping.

Having all those great advantages does come with a price. However, it's a rather small one. I promise.

The Migration Guide below will tell you all you need to know about using v2.0 coming from
v1.x

### Migration Guide

* Constructors:
  * New convenience constructor has changed from `init(accountId: , siteName: )` to `init(accountId: , siteName: , stagingCampaign: Bool)`.
  * If you need full control of the endpoints' urls, there're still [other constructors](https://github.com/SourcePointUSA/ios-cmp-app/blob/master/ConsentViewController/Classes/ConsentViewController.swift#L147) that can be used.
  * It now `throws` an error implementing the [`ConsentViewControllerError`](https://github.com/SourcePointUSA/ios-cmp-app/blob/master/ConsentViewController/Classes/ConsentViewControllerError.swift#L10) protocol.
* Custom Consents:
  * The getters for singular custom consent (`getPurposeConsent` and `getCustomVendorConsent`) were removed.
  * `getPurposeConsents` was renamed to `getCustomPurposeConsents`
  * Both `getCustomPurposeConsents` and `getCustomVendorConsents` no longer receive any params and will return `[PurposeConsent]` and `[VendorConsent]` respectively.
  * [`PurposeConsent` and `VendorConsent`](https://github.com/SourcePointUSA/ios-cmp-app/blob/master/ConsentViewController/Classes/Consent.swift) classes introduced.
* Error Handling:
  * Several Errors subclasses were introduced in order to make debugging easier and the framework more robust.
  * When instantiating `ConsentViewController` or when calling one of the custom consent _getters_ you need to catch on `ConsentViewControllerError`
  * Since we have to conform to `WKUIDelegate`, we can't just throw an exception when something goes bad in the WebView. We introduced  `ConsentViewController#onErrorOccurred` callback for that matter. Faulty internet connection or a bad setup campaign will no longer crash your app.
* Gone for good:
* The properties `page`, `isInternalStage`, `isStage` and `msgJSON` were either removed or became private.
* The callback function `onReceiveMessageData` has been removed.

For more information make sure to check [Usage section of our README](https://github.com/SourcePointUSA/ios-cmp-app/#usage).