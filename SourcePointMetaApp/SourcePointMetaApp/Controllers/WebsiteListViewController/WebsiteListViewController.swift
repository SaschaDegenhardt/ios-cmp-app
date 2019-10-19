//
//  WebsiteListViewController.swift
//  SourcepointMetaApp
//
//  Created by Vilas on 23/03/19.
//  Copyright © 2019 Cybage. All rights reserved.
//

import UIKit
import CoreData
import ConsentViewController
import WebKit

class WebsiteListViewController: BaseViewController, WKNavigationDelegate, UITextViewDelegate {
    
    //// MARK: - IBOutlet
    @IBOutlet weak var websiteTableView: SourcePointUITableView!
    
    @IBOutlet weak var noSiteDataLabel: UILabel!
    
    //// MARK: - Instance properties
    var websiteListViewModel : WebsiteListViewModel = WebsiteListViewModel()
    
    private let cellIdentifier = "websiteCell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        websiteTableView.tableFooterView = UIView(frame: .zero)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: animated)
        fetchAllSitesData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        let backItem = UIBarButtonItem()
        backItem.title = ""
        navigationItem.backBarButtonItem = backItem
    }
    
    // This method will fetch all the sites data
    func fetchAllSitesData() {
        showIndicator()
        websiteListViewModel.importAllWebsites(executionCompletionHandler: { (_) in
            self.websiteTableView.reloadData()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: { [weak self] in
                self?.websiteTableView.reloadData()
                self?.hideIndicator()
            })
        })
    }
    
    func setTableViewHidden() {
        websiteTableView.isHidden = !(websiteListViewModel.numberOfWebsites() > 0)
        noSiteDataLabel.isHidden = websiteListViewModel.numberOfWebsites() > 0
    }
    
    func clearCookies() {
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in records.forEach { record in
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
            }
        }
    }
    
    func loadConsentDetailsViewController(atIndex index: Int) {
        if let consentDetailsViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ConsentViewDetailsViewController") as? ConsentViewDetailsViewController {
            consentDetailsViewController.websiteManagedObjectID = self.websiteListViewModel.websiteManagedObjectID(atIndex: index)
            self.navigationController!.pushViewController(consentDetailsViewController, animated: true)
        }
    }
}

//// MARK: UITableViewDataSource
extension WebsiteListViewController : UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        setTableViewHidden()
        return websiteListViewModel.numberOfWebsites()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? WebsiteCell {
            cell.accountIDLabel.text = "Vilas"

//            if let websiteDetails = websiteListViewModel.websiteDetails(atIndex: indexPath.row).0 {
//                cell.websiteNameLabel.text = websiteDetails.websiteName
//                cell.accountIDLabel.text = "\(SPLiteral.accountID): \(websiteDetails.accountID)"
//                cell.campaignLabel.text = websiteDetails.isStaging ? SPLiteral.stagingCampaign : SPLiteral.publicCampaign
//            }
//            if let targetingDetails = websiteListViewModel.websiteDetails(atIndex: indexPath.row).1 {
//                cell.targetingParamTextView.text = targetingDetails
//            }
            return cell
        }
        return UITableViewCell()
    }
}

//// MARK: - UITableViewDelegate
//extension WebsiteListViewController : UITableViewDelegate {
//    
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        websiteTableView.deselectRow(at: indexPath, animated: false)
//        loadConsentDetailsViewController(atIndex: indexPath.row)
//    }
//    
//    // iOS 11 and above for right swipe gesture
//    @available(iOS 11.0, *)
//    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?
//    {
//        let editAction = UIContextualAction(style: .destructive, title: nil) { (action, view, handler) in
//            if let editWebsiteViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "AddWebsiteViewController") as? AddWebsiteViewController {
//                editWebsiteViewController.siteManagedObjectID = self.websiteListViewModel.websiteManagedObjectID(atIndex: indexPath.row)
//                
//                self.navigationController!.pushViewController(editWebsiteViewController, animated: true)
//            }
//        }
//        let resetAction = UIContextualAction(style: .destructive, title: nil) { (action, view, handler) in
//           
//            self.hideIndicator()
//            let alertController = UIAlertController(title: "", message: "", preferredStyle: UIAlertController.Style.alert)
//            
//            alertController.setValue(SPLiteral.attributedString(), forKey: "attributedTitle")
//            let noAction = UIAlertAction(title: "NO", style: UIAlertAction.Style.default, handler: {(alert: UIAlertAction!) in
//                self.websiteTableView.reloadData()
//            })
//            let yesAction = UIAlertAction(title: "YES", style: UIAlertAction.Style.default, handler: {(alert: UIAlertAction!) in
//                self.showIndicator()
//                self.websiteListViewModel.clearUserDefaultsData()
//                self.clearCookies()
//                self.loadConsentDetailsViewController(atIndex: indexPath.row)
//                self.hideIndicator()
//            })
//            alertController.addAction(noAction)
//            alertController.addAction(yesAction)
//            self.present(alertController, animated: true, completion: nil)
//            
//        }
//        let deleteAction = UIContextualAction(style: .destructive, title: nil) { (action, view, handler) in
//            let yesHandler = { [weak self]() -> Void in
//                self?.showIndicator()
//                self?.websiteListViewModel.delete(atIndex: indexPath.row, completionHandler: {[weak self] (_, error) in
//                    self?.hideIndicator()
//                    if let _error = error {
//                        let okHandler = {}
//                        AlertView.sharedInstance.showAlertView(title: Alert.message, message: _error.message, actions: [okHandler], titles: [Alert.ok], actionStyle: UIAlertController.Style.alert)
//                    } else {
//                        self?.hideIndicator()
//                        self?.fetchAllSitesData()
//                    }
//                })
//            }
//            let noHandler = {
//                self.websiteTableView.reloadData()
//            }
//            self.hideIndicator()
//            AlertView.sharedInstance.showAlertView(title: Alert.alert, message: Alert.messageForDeletingSiteData, actions: [yesHandler, noHandler], titles: [Alert.yes, Alert.no], actionStyle: UIAlertController.Style.alert)
//        }
//        deleteAction.backgroundColor = #colorLiteral(red: 0.2841853499, green: 0.822665453, blue: 0.653732717, alpha: 1)
//        deleteAction.image = UIImage(named: "Trash")
//        editAction.backgroundColor = #colorLiteral(red: 0.2841853499, green: 0.822665453, blue: 0.653732717, alpha: 1)
//        editAction.image = UIImage(named: "Edit")
//        resetAction.backgroundColor = #colorLiteral(red: 0.2841853499, green: 0.822665453, blue: 0.653732717, alpha: 1)
//        resetAction.image = UIImage(named: "Reset")
//        let configuration = UISwipeActionsConfiguration(actions: [deleteAction,editAction,resetAction])
//        configuration.performsFirstActionWithFullSwipe = false
//        return configuration
//    }
//    
//    // iOS 10 and below for right swipe gesture
//    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]?
//    {
//        let editAction = UITableViewRowAction(style: .destructive, title: "Edit") { (action, indexpath) in
//            if let editWebsiteViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "AddWebsiteViewController") as? AddWebsiteViewController {
//                editWebsiteViewController.siteManagedObjectID = self.websiteListViewModel.websiteManagedObjectID(atIndex: indexPath.row)
//                
//                self.navigationController!.pushViewController(editWebsiteViewController, animated: true)
//            }
//        }
//        
//        let resetAction = UITableViewRowAction(style: .destructive, title: "Reset") { (action, indexpath) in
//            self.hideIndicator()
//            let alertController = UIAlertController(title: "", message: "", preferredStyle: UIAlertController.Style.alert)
//            
//            alertController.setValue(SPLiteral.attributedString(), forKey: "attributedTitle")
//            let noAction = UIAlertAction(title: "NO", style: UIAlertAction.Style.default, handler: {(alert: UIAlertAction!) in
//                self.websiteTableView.reloadData()
//            })
//            let yesAction = UIAlertAction(title: "YES", style: UIAlertAction.Style.default, handler: {(alert: UIAlertAction!) in
//                self.showIndicator()
//                self.websiteListViewModel.clearUserDefaultsData()
//                self.clearCookies()
//                self.loadConsentDetailsViewController(atIndex: indexPath.row)
//                self.hideIndicator()
//            })
//            alertController.addAction(noAction)
//            alertController.addAction(yesAction)
//            self.present(alertController, animated: true, completion: nil)
//        }
//        
//        let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { (action, indexpath) in
//            let yesHandler = { [weak self]() -> Void in
//                self?.showIndicator()
//                self?.websiteListViewModel.delete(atIndex: indexPath.row, completionHandler: {[weak self] (_, error) in
//                    self?.hideIndicator()
//                    if let _error = error {
//                        let okHandler = {}
//                        AlertView.sharedInstance.showAlertView(title: Alert.message, message: _error.message, actions: [okHandler], titles: [Alert.ok], actionStyle: UIAlertController.Style.alert)
//                    } else {
//                        self?.hideIndicator()
//                        self?.fetchAllSitesData()
//                    }
//                })
//            }
//            let noHandler = {
//                self.websiteTableView.reloadData()
//            }
//            self.hideIndicator()
//            AlertView.sharedInstance.showAlertView(title: Alert.alert, message: Alert.messageForDeletingSiteData, actions: [yesHandler, noHandler], titles: [Alert.yes, Alert.no], actionStyle: UIAlertController.Style.alert)
//        }
//        deleteAction.backgroundColor = #colorLiteral(red: 0.822665453, green: 0.07812128419, blue: 0.1612752695, alpha: 0.9916923415)
//        editAction.backgroundColor = #colorLiteral(red: 0.2841853499, green: 0.822665453, blue: 0.653732717, alpha: 1)
//        resetAction.backgroundColor = .lightGray
//        return [deleteAction,editAction, resetAction]
//    }
//}
