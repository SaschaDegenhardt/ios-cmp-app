//
//  ConsentViewController.swift
//  cmp-app-test-app
//
//  Created by Dmitri Rabinowitz on 8/13/18.
//  Copyright © 2018 Sourcepoint. All rights reserved.
//

/// :nodoc:
public typealias Callback = (ConsentViewController) -> Void

import UIKit
import WebKit
import JavaScriptCore

/**
 SourcePoint's Consent SDK is a WebView that loads SourcePoint's web consent managment tool
 and offers ways to inspect the consents and purposes the user has chosen.
 
 ```
 var consentViewController: ConsentViewController!
 override func viewDidLoad() {
     super.viewDidLoad()
     consentViewController = ConsentViewController(accountId: <ACCOUNT_ID>, siteName: "SITE_NAME")
     consentViewController.onMessageChoiceSelect = {
        (cbw: ConsentViewController) in print("Choice selected by user", cbw.choiceType as Any)
     }
     consentViewController.onInteractionComplete = { (cbw: ConsentViewController) in
         print(
             cbw.euconsent as Any,
             cbw.consentUUID as Any,
             cbw.getIABVendorConsents(["VENDOR_ID"]),
             cbw.getIABPurposeConsents([PURPOSE_ID]),
             cbw.getCustomVendorConsents(forIds: ["VENDOR_ID"]),
             cbw.getPurposeConsents()
         )
     }
 view.addSubview(consentViewController.view)
 ```
*/
@objcMembers open class ConsentViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {

    /// :nodoc:
    public enum DebugLevel: String {
        case DEBUG
        case INFO
        case TIME
        case WARN
        case ERROR
        case OFF
    }

    /// :nodoc:
    static public let EU_CONSENT_KEY: String = "euconsent"
    /// :nodoc:
    static public let CONSENT_UUID_KEY: String = "consentUUID"
    
    /// If the user has consent data stored, reading for this key in the `UserDefaults` will return "1"
    static public let IAB_CONSENT_CMP_PRESENT: String = "IABConsent_CMPPresent"
    
    /// If the user is subject to GDPR, reading for this key in the `UserDefaults` will return "1" otherwise "0"
    static public let IAB_CONSENT_SUBJECT_TO_GDPR: String = "IABConsent_SubjectToGDPR"
    
    /// They key used to store the IAB Consent string for the user in the `UserDefaults`
    static public let IAB_CONSENT_CONSENT_STRING: String = "IABConsent_ConsentString"
    
    /// They key used to read and write the parsed IAB Purposes consented by the user in the `UserDefaults`
    static public let IAB_CONSENT_PARSED_PURPOSE_CONSENTS: String = "IABConsent_ParsedPurposeConsents"
    
    /// The key used to read and write the parsed IAB Vendor consented by the user in the `UserDefaults`
    static public let IAB_CONSENT_PARSED_VENDOR_CONSENTS: String = "IABConsent_ParsedVendorConsents"

    /// The id of your account can be found in the Publisher's portal -> Account menu
    public let accountId: Int
    
    /// The site name which the campaign and scenarios will be loaded from
    public let siteName: String

    static private let SP_PREFIX: String = "_sp_"
    static private let SP_SITE_ID: String = SP_PREFIX + "site_id"
    static private let CUSTOM_VENDOR_PREFIX = SP_PREFIX + "custom_vendor_consent_"
    static private let SP_CUSTOM_PURPOSE_CONSENT_PREFIX = SP_PREFIX + "custom_purpose_consent_"
    static private let SP_CUSTOM_PURPOSE_CONSENTS_JSON: String = SP_PREFIX + "custom_purpose_consents_json"

    static private let MAX_VENDOR_ID: Int = 500
    static private let MAX_PURPOSE_ID: Int = 24

    static private let PM_MESSAGING_HOST = "pm.sourcepoint.mgr.consensu.org"

    static private let DEFAULT_STAGING_MMS_DOMAIN = "mms.sp-stage.net"
    static private let DEFAULT_MMS_DOMAIN = "mms.sp-prod.net"

    static private let DEFAULT_INTERNAL_CMP_DOMAIN = "cmp.sp-stage.net"
    static private let DEFAULT_CMP_DOMAIN = "sourcepoint.mgr.consensu.org"

    static private let DEFAULT_INTERNAL_IN_APP_MESSAGING_PAGE_DOMAIN = "in-app-messaging.pm.cmp.sp-stage.net"
    static private let DEFAULT_IN_APP_MESSAGING_PAGE_DOMAIN = "in-app-messaging.pm.sourcepoint.mgr.consensu.org"

    /// Page is merely for logging purposes, eg. https://mysitename.example/page
    public var page: String?
    
    /// Indicates if the campaign is a stage campaign
    public var isStage: Bool = false
    
    /// indicates if the data should come from SourcePoint's staging environment. Most of the times that's not what you want.
    public var isInternalStage: Bool = false
    
    /// :nodoc:
    private var inAppMessagingPageUrl: String?
    /// :nodoc:
    public var mmsDomain: String?
    /// :nodoc:
    public var cmpDomain: String?
    /// :nodoc:
    private var targetingParams: [String: Any] = [:]
    /// :nodoc:
    public var debugLevel: DebugLevel = .OFF

    // TODO: remove it, as in Android's SDK
    /// :nodoc:
    public var onReceiveMessageData: Callback?

    /**
     A `Callback` that will be called the message is about to be shown. Notice that,
     sometimes, depending on how the scenario was set up, the message might not show
     at all, thus this call back won't be called.
     */
    public var willShowMessage: Callback?
    
    /**
      A `Callback` that will be called when the user selects an option on the WebView.
      The selected choice will be available in the instance variable `choiceType`
     */
    public var onMessageChoiceSelect: Callback?
    
    /**
     A `Callback` to be called when the user finishes interacting with the WebView
     either by closing it, canceling or accepting the terms.
     At this point, the following keys will available populated in the `UserDefaults`:
     * `EU_CONSENT_KEY`
     * `CONSENT_UUID_KEY`
     * `IAB_CONSENT_SUBJECT_TO_GDPR`
     * `IAB_CONSENT_CONSENT_STRING`
     * `IAB_CONSENT_PARSED_PURPOSE_CONSENTS`
     * `IAB_CONSENT_PARSED_VENDOR_CONSENTS`
     
     Also at this point, the methods `getCustomVendorConsents()`,
     `getPurposeConsents(forIds:)` and `getPurposeConsent(forId:)`
     will also be able to be called from inside the callback
     */
    public var onInteractionComplete: Callback?

    var webView: WKWebView!
    
    // TODO: remove it
    /// :nodoc:
    public var msgJSON: String? = nil
    
    /// Holds the choice type the user has chosen after interacting with the ConsentViewController
    public var choiceType: Int? = nil
    
    /// The IAB consent string, set after the user has chosen after interacting with the ConsentViewController
    public var euconsent: String? = nil
    
    /// The UUID assigned to the user, set after the user has chosen after interacting with the ConsentViewController
    public var consentUUID: String? = nil

    /// Holds a collection of strings representing the non-IAB consents
    public var customConsent: [[String: Any]] = []

    private var mmsDomainToLoad: String?
    private var cmpDomainToLoad: String?
    private var cmpUrl: String

    private func startLoad(_ urlString: String) -> Data? {
        let url = URL(string: urlString)!
        let semaphore = DispatchSemaphore( value: 0 )
        var responseData: Data?
        let task = URLSession.shared.dataTask(with: url) { data, reponse, error in
            responseData = data
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        return responseData
    }

    private let sourcePoint: SourcePointClient

    /**
     Initialises the library with `accountId` and `siteName`.
     */
    public init(
        accountId: Int,
        siteName: String,
        stagingCampaign: Bool,
        mmsDomain: String,
        cmpDomain: String,
        messageDomain: String
    ) throws {
        self.accountId = accountId
        self.siteName = siteName

        guard
            let mmsUrl = URL(string: mmsDomain),
            let cmpUrl = URL(string: cmpDomain),
            let messageUrl = URL(string: messageDomain)
        else {
            throw ConsentViewControllerError.APIError(message: "Invalid URL.")
        }

        self.sourcePoint = try SourcePointClient(
            accountId: accountId,
            siteName: siteName,
            stagingCampaign: stagingCampaign,
            mmsUrl: mmsUrl,
            cmpUrl: cmpUrl,
            messageUrl: messageUrl
        )

        self.cmpUrl = cmpUrl.absoluteString

        // read consent from/write consent data to UserDefaults.standard storage
        // per gdpr framework: https://github.com/InteractiveAdvertisingBureau/GDPR-Transparency-and-Consent-Framework/blob/852cf086fdac6d89097fdec7c948e14a2121ca0e/In-App%20Reference/iOS/CMPConsentTool/Storage/CMPDataStorageUserDefaults.m
        self.euconsent = UserDefaults.standard.string(forKey: ConsentViewController.EU_CONSENT_KEY)
        self.consentUUID = UserDefaults.standard.string(forKey: ConsentViewController.CONSENT_UUID_KEY)

        super.init(nibName: nil, bundle: nil)
    }

    public convenience init(accountId: Int, siteName: String, stagingCampaign: Bool) throws {
        try self.init(
            accountId: accountId,
            siteName: siteName,
            stagingCampaign: stagingCampaign,
            staging: false
        )
    }

    public convenience init(accountId: Int, siteName: String, stagingCampaign: Bool, staging: Bool) throws {
        try self.init(
            accountId: accountId,
            siteName: siteName,
            stagingCampaign: stagingCampaign,
            mmsDomain: "https://" + (staging ? ConsentViewController.DEFAULT_STAGING_MMS_DOMAIN : ConsentViewController.DEFAULT_MMS_DOMAIN),
            cmpDomain: "https://" + (staging ? ConsentViewController.DEFAULT_INTERNAL_CMP_DOMAIN : ConsentViewController.DEFAULT_CMP_DOMAIN),
            messageDomain: "https://" + (staging ? ConsentViewController.DEFAULT_INTERNAL_IN_APP_MESSAGING_PAGE_DOMAIN : ConsentViewController.DEFAULT_IN_APP_MESSAGING_PAGE_DOMAIN)
        )
    }

    // TODO: may need to implement this eventually
    /// :nodoc:
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// :nodoc:
    @objc(setTargetingParamString:value:)
    public func setTargetingParam(key: String, value: String) {
        targetingParams[key] = value
    }

    /// :nodoc:
    @objc(setTargetingParamInt:value:)
    public func setTargetingParam(key: String, value: Int) {
        targetingParams[key] = value
    }

    public func setInAppMessagingUrl(urlString: String) {
        inAppMessagingPageUrl = urlString
    }

    public func getInAppMessagingUrl() -> String {
        return "https://" + (isInternalStage ?
            ConsentViewController.DEFAULT_INTERNAL_IN_APP_MESSAGING_PAGE_DOMAIN :
            ConsentViewController.DEFAULT_IN_APP_MESSAGING_PAGE_DOMAIN
        )
    }

    /// :nodoc:
    override open func loadView() {
        euconsent = UserDefaults.standard.string(forKey: ConsentViewController.EU_CONSENT_KEY)
        consentUUID = UserDefaults.standard.string(forKey: ConsentViewController.CONSENT_UUID_KEY)

        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        // inject js so we have a consistent interface to messaging page as in android
        let scriptSource = "(function () {\n"
            + "function postToWebView (name, body) {\n"
            + "  window.webkit.messageHandlers.JSReceiver.postMessage({ name: name, body: body });\n"
            + "}\n"
            + "window.JSReceiver = {\n"
            + "  onReceiveMessageData: function (willShowMessage, msgJSON) { postToWebView('onReceiveMessageData', { willShowMessage: willShowMessage, msgJSON: msgJSON }); },\n"
            + "  onMessageChoiceSelect: function (choiceType) { postToWebView('onMessageChoiceSelect', { choiceType: choiceType }); },\n"
            + "  sendConsentData: function (euconsent, consentUUID) { postToWebView('interactionComplete', { euconsent: euconsent, consentUUID: consentUUID }); }\n"
            + "};\n"
            + "})();"
        let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(script)

        userContentController.add(self, name: "JSReceiver")

        config.userContentController = userContentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.allowsBackForwardNavigationGestures = true

        view = webView
    }

    private func openInBrowswerHelper(_ url:URL) -> Void {
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
        } else {
            UIApplication.shared.openURL(url)
        }
    }

    private func urlDoesNotBelongToDialog(_ url: URL) -> Bool {
        let allowedHosts : Set<String> = [
            URL(string: getInAppMessagingUrl())!.host!,
            siteName,
            mmsDomainToLoad!,
            cmpDomainToLoad!,
            ConsentViewController.PM_MESSAGING_HOST,
            "about:blank"
        ]
        return !allowedHosts.contains(url.host ?? "about:blank")
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, urlDoesNotBelongToDialog(url) {
            openInBrowswerHelper(url)
            decisionHandler(WKNavigationActionPolicy.cancel)
        } else {
            decisionHandler(WKNavigationActionPolicy.allow)
        }
    }

    /// :nodoc:
    // handles links with "target=_blank", forcing them to open in Safari
    public func webView(_ webView: WKWebView,
                        createWebViewWith configuration: WKWebViewConfiguration,
                        for navigationAction: WKNavigationAction,
                        windowFeatures: WKWindowFeatures) -> WKWebView? {
        openInBrowswerHelper(navigationAction.request.url!)
        return nil
    }

    /// :nodoc:
    override open func viewDidLoad() {
        super.viewDidLoad()
        // initially hide web view while loading
        webView.frame = CGRect(x: 0, y: 0, width: 0, height: 0)

        let pageToLoad = getInAppMessagingUrl()

        let path = page == nil ? "" : page!
        let siteHref = "https://" + siteName + "/" + path + "?"

        mmsDomainToLoad = mmsDomain ?? (isInternalStage ?
            "mms.sp-stage.net" :
            "mms.sp-prod.net"
        )

        cmpDomainToLoad = cmpDomain ?? (isInternalStage ?
            "cmp.sp-stage.net" :
            "sourcepoint.mgr.consensu.org"
        )
        cmpUrl = "https://" + cmpDomainToLoad!

        var params = [
            "_sp_cmp_inApp=true",
            "_sp_writeFirstPartyCookies=true",
            "_sp_siteHref=" + encodeURIComponent(siteHref)!,
            "_sp_accountId=" + String(accountId),
            "_sp_msg_domain=" + encodeURIComponent(mmsDomainToLoad!)!,
            "_sp_cmp_origin=" + encodeURIComponent("//" + cmpDomainToLoad!)!,
            "_sp_debug_level=" + debugLevel.rawValue,
            "_sp_msg_stageCampaign=" + isStage.description
        ]

        var targetingParamStr: String?
        do {
            let targetingParamData = try JSONSerialization.data(withJSONObject: self.targetingParams, options: [])
            targetingParamStr = String(data: targetingParamData, encoding: String.Encoding.utf8)
        } catch let error as NSError {
            print("error serializing targeting params: " + error.localizedDescription)
        }

        if targetingParamStr != nil {
            params.append("_sp_msg_targetingParams=" + encodeURIComponent(targetingParamStr!)!)
        }

        let myURL = URL(string: pageToLoad + "?" + params.joined(separator: "&"))
        let myRequest = URLRequest(url: myURL!)

        print ("url: \((myURL?.absoluteString)!)")

        UserDefaults.standard.setValue(true, forKey: "IABConsent_CMPPresent")
        setSubjectToGDPR()

        webView.load(myRequest)
    }

    private func setSubjectToGDPR() {
        if(UserDefaults.standard.string(forKey: ConsentViewController.IAB_CONSENT_SUBJECT_TO_GDPR) != nil) { return }

        do {
            let gdprStatus = try sourcePoint.getGdprStatus()
            UserDefaults.standard.setValue(gdprStatus, forKey: ConsentViewController.IAB_CONSENT_SUBJECT_TO_GDPR)
        } catch {
            print(error)
        }
    }

    /**
     Get the IAB consents given to each vendor id in the array passed as parameter
     
     - Precondition: this function should be called either during the `Callback` `onInteractionComplete` or after it has returned.
     - Parameter _: an `Array` of vendor ids
     - Returns: an `Array` of `Bool` indicating if the user has given consent to the corresponding vendor.
    */
    public func getIABVendorConsents(_ forIds: [Int]) -> [Bool]{
        var results = Array(repeating: false, count: forIds.count)
        let storedConsentString = UserDefaults.standard.string(forKey: ConsentViewController.IAB_CONSENT_CONSENT_STRING) ?? ""
        let consentString:ConsentString = buildConsentString(storedConsentString)
        
        for i in 0..<forIds.count {
            results[i] = consentString.isVendorAllowed(vendorId: forIds[i])
        }
        return results
    }
 
    /**
     Checks if the IAB purposes passed as parameter were given consent or not.
     
     - Precondition: this function should be called either during the `Callback` `onInteractionComplete` or after it has returned.
     - Parameter _: an `Array` of purpose ids
     - Returns: an `Array` of `Bool` indicating if the user has given consent to the corresponding purpose.
     */
    public func getIABPurposeConsents(_ forIds: [Int8]) -> [Bool]{
        var results = Array(repeating: false, count: forIds.count)
        let storedConsentString = UserDefaults.standard.string(forKey: ConsentViewController.IAB_CONSENT_CONSENT_STRING) ?? ""
        let consentString:ConsentString = buildConsentString(storedConsentString)
        
        for i in 0..<forIds.count {
            results[i] = consentString.purposeAllowed(forPurposeId: forIds[i])
        }
        return results
    }
    
    private func getSiteId() throws -> String {
        let siteIdKey = ConsentViewController.SP_SITE_ID + "_" + String(accountId) + "_" + siteName

        guard let storedSiteId = UserDefaults.standard.string(forKey: siteIdKey) else {
            let siteId = try sourcePoint.getSiteId()
            UserDefaults.standard.setValue(siteId, forKey: siteIdKey)
            UserDefaults.standard.synchronize()
            return siteId
        }

        return storedSiteId
    }

    /**
     Checks if the non-IAB purposes passed as parameter were given consent or not.
     Same as `getIabVendorConsents(forIds: )` but for non-IAB vendors.
     
     - Precondition: this function should be called either during the `Callback` `onInteractionComplete` or after it has returned.
     - Parameter forIds: an `Array` of vendor ids
     - Returns: an `Array` of `Bool` indicating if the user has given consent to the corresponding vendor.
     */
        var result = Array(repeating: false, count: customVendorIds.count)

        try loadAndStoreConsents(customVendorIds)

        for index in 0..<customVendorIds.count {
            let customVendorId = customVendorIds[index]
            let storedConsentData = UserDefaults.standard.string(
                forKey: ConsentViewController.CUSTOM_VENDOR_PREFIX + customVendorId
            )

            if storedConsentData != nil {
                result[index] = storedConsentData == "true"
            }
        }

        return result
    }

    /**
     Checks if a non-IAB purpose was given consent.
     Same as `getIabPurposeConsents(_) but for a single non-IAB purpose.
     
     - Precondition: this function should be called either during the `Callback` `onInteractionComplete` or after it has returned.
     - Parameter forId: the purpose id
     - Returns: a `Bool` indicating if the user has given consent to that purpose.
     */
    public func getCustomVendorConsents() throws -> Array<VendorConsent> {
        }
        return consents.consentedVendors
    }

    /**
     Checks if a non-IAB purpose was given consent.
     Same as `getIabPurposeConsents(_) but for non-IAB purposes.
     
     - Precondition: this function should be called either during the `Callback` `onInteractionComplete` or after it has returned.
     - Parameter forIds: the purpose id
     - Returns: a `Bool` indicating if the user has given consent to that purpose.
     */
    public func getPurposeConsents(forIds purposeIds: [String] = []) throws -> [[String:String]?] {
        try loadAndStoreConsents([])

        guard let storedPurposeConsentsJson = UserDefaults.standard.string(
            forKey: ConsentViewController.SP_CUSTOM_PURPOSE_CONSENTS_JSON
        )
        else {
            return []
        }

        let purposeConsents = try! JSONSerialization.jsonObject(
            with: storedPurposeConsentsJson.data(using: String.Encoding.utf8)!, options: []
        ) as? [[String: String]]

        if purposeIds.count == 0 { return purposeConsents! }

        var results = [[String: String]?](repeating: nil, count: purposeIds.count)
        for consentedPurpose in purposeConsents! {
            if let i = purposeIds.index(of: consentedPurpose["_id"]!) {
                results[i] = consentedPurpose
            }
        }
        return results
    }
    
    
    /**
     * When we receive data from the server, if a given custom vendor is no longer given consent
     * to, its information won't be present in the payload. Therefore we have to first clear the
     * preferences then set each vendor to true based on the response.
     */
    private func clearStoredVendorConsents(forIds vendorIds: [String]) {
        for id in vendorIds {
            UserDefaults.standard.removeObject(forKey: ConsentViewController.CUSTOM_VENDOR_PREFIX + id)
        }
    }

    private func loadAndStoreConsents(_ customVendorIdsToRequest: [String]) throws {
        let consentParam = consentUUID ?? "[CONSENT_UUID]"
        let euconsentParam = euconsent ?? "[EUCONSENT]"

        let siteId = try getSiteId()
        let path = "/consent/v2/" + siteId + "/custom-vendors"
        let customVendorIdString = encodeURIComponent(customVendorIdsToRequest.joined(separator: ",")) ?? ""
        let search = "?customVendorIds=" + customVendorIdString +
            "&consentUUID=" + consentParam +
            "&euconsent=" + euconsentParam
        let url = cmpUrl + path + search

        guard
            let data = self.startLoad(url),
            let consentsJSON = try? JSONSerialization.jsonObject(with: data, options: []),
            let consents = consentsJSON as? [String:[[String: String]]],
            let consentedCustomVendors = consents["consentedVendors"],
            let consentedPurposes = consents["consentedPurposes"]
        else {
            print("Could not get consents from the API.")
            return
        }

        // Store consented vendors in UserDefaults one by one
        clearStoredVendorConsents(forIds: customVendorIdsToRequest)
        for consentedCustomVendor in consentedCustomVendors {
            guard let id = consentedCustomVendor["_id"] else { return }
            UserDefaults.standard.setValue(
                "true",
                forKey: ConsentViewController.CUSTOM_VENDOR_PREFIX + id
            )
            UserDefaults.standard.setValue(
                "true",
                forKey: ConsentViewController.SP_CUSTOM_PURPOSE_CONSENT_PREFIX + id
            )
        }

        // Store consented purposes in UserDefaults as a JSON

        // Serialize consented purposes again
        guard let consentedPurposesJson = try? JSONSerialization.data(withJSONObject: consentedPurposes as Any, options: []) else {
            return
        }
        UserDefaults.standard.setValue(
            String(data: consentedPurposesJson, encoding: String.Encoding.utf8),
            forKey: ConsentViewController.SP_CUSTOM_PURPOSE_CONSENTS_JSON
        )

        UserDefaults.standard.synchronize()
    }

    private func encodeURIComponent(_ val: String) -> String? {
        var characterSet = CharacterSet.alphanumerics
        characterSet.insert(charactersIn: "-_.!~*'()")
        return val.addingPercentEncoding(withAllowedCharacters: characterSet)
    }

    let maxPurposes:Int64 = 24

    private func buildConsentString(_ euconsentBase64Url: String) -> ConsentString {
        //Convert base46URL to regular base64 encoding for Consent String SDK Swift

        let euconsent = euconsentBase64Url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        return try! ConsentString(
            consentString: euconsent
        )
    }
    
    private func storeIABVars(_ euconsentBase64Url: String) {
        let userDefaults = UserDefaults.standard
        // Set the standard IABConsent_ConsentString var in userDefaults
        userDefaults.setValue(euconsentBase64Url, forKey: ConsentViewController.IAB_CONSENT_CONSENT_STRING)

        let cstring = buildConsentString(euconsentBase64Url)

        // Generate parsed vendor consents string
        var parsedVendorConsents = [Character](repeating: "0", count: ConsentViewController.MAX_VENDOR_ID)
        for i in 1...ConsentViewController.MAX_VENDOR_ID {
            if cstring.isVendorAllowed(vendorId: i) {
                parsedVendorConsents[i - 1] = "1"
            }
        }
        userDefaults.setValue(String(parsedVendorConsents), forKey: ConsentViewController.IAB_CONSENT_PARSED_VENDOR_CONSENTS)

        // Generate parsed purpose consents string
        var parsedPurposeConsents = [Character](repeating: "0", count: ConsentViewController.MAX_PURPOSE_ID)
        for pId in cstring.purposesAllowed {
            parsedPurposeConsents[Int(pId) - 1] = "1"
        }
        userDefaults.setValue(String(parsedPurposeConsents), forKey: ConsentViewController.IAB_CONSENT_PARSED_PURPOSE_CONSENTS)
    }

    /// :nodoc:
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let messageBody = message.body as? [String: Any], let name = messageBody["name"] as? String {
            switch name {
            case "onReceiveMessageData": // when the message is first loaded
                let body = messageBody["body"] as? [String: Any?]

                if let msgJSON = body?["msgJSON"] as? String {
                    self.msgJSON = msgJSON
                    onReceiveMessageData?(self)
                }

                if let shouldShowMessage = body?["willShowMessage"] as? Bool, shouldShowMessage {
                    // display web view once the message is ready to display
                    if webView.superview != nil {
                        webView.frame = webView.superview!.bounds
                        willShowMessage?(self)
                    }
                } else {
                    onInteractionComplete?(self)
                    webView.removeFromSuperview()
                }
            case "onMessageChoiceSelect": // when a choice is selected
                let body = messageBody["body"] as? [String: Int?]

                if let choiceType = body?["choiceType"] as? Int {
                    self.choiceType = choiceType
                    onMessageChoiceSelect?(self)
                }
            case "interactionComplete": // when interaction with message is complete
                if let body = messageBody["body"] as? [String: String?], let euconsent = body["euconsent"], let consentUUID = body["consentUUID"] {
                    let userDefaults = UserDefaults.standard
                    if (euconsent != nil) {
                        self.euconsent = euconsent
                        userDefaults.setValue(euconsent, forKey: ConsentViewController.EU_CONSENT_KEY)
                        storeIABVars(euconsent!)
                    }

                    if (consentUUID != nil) {
                        self.consentUUID = consentUUID
                        userDefaults.setValue(consentUUID, forKey: ConsentViewController.CONSENT_UUID_KEY)
                    }

                    if (euconsent != nil || consentUUID != nil) {
                        userDefaults.synchronize()
                    }
                }
                onInteractionComplete?(self)
                webView.removeFromSuperview()
            default:
                print("userContentController was called but the message body: \(name) is unknown.")
            }
        }
    }
}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
