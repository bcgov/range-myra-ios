//
//  PlantCommunityViewController.swift
//  Myra
//
//  Created by Amir Shayegh on 2018-07-04.
//  Copyright © 2018 Government of British Columbia. All rights reserved.
//

import UIKit
import Realm
import RealmSwift

enum PlantCommunityFromSection: Int {
    case BasicInfo = 0
    case Actions
    case MonitoringAreas
    case Criteria
}

enum PlantCommunityCriteriaFromSection: Int {
    case RangeReadiness = 0
    case StubbleHeight
    case ShrubUse
}

class PlantCommunityViewController: BaseViewController {

    // MARK: Variables
    var completion: ((_ done: Bool) -> Void)?
    var plantCommunity: PlantCommunity?
    var pasture: Pasture?
    var mode: FormMode = .View
    var plan: RUP?

    let numberOfSections = 4
    let numberOfCriteriaSections = 3

    // MARK: Outlets
    @IBOutlet weak var pageTitle: UILabel!
    @IBOutlet weak var subtitle: UILabel!
    @IBOutlet weak var tableView: UITableView!

    @IBOutlet weak var divider: UIView!
    @IBOutlet weak var navbar: UIView!
    @IBOutlet weak var statusbar: UIView!
    @IBOutlet weak var backbutton: UIButton!
    @IBOutlet weak var navbarTitle: UILabel!

    @IBOutlet weak var bannerLabel: UILabel!
    @IBOutlet weak var bannerHeight: NSLayoutConstraint!
    @IBOutlet weak var banner: UIView!

    @IBOutlet weak var saveButton: UIButton!
    
    // MARK: ViewController functions
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpTable()
        setTitle()
        setSubtitle()
        style()
    }

    // MARK: Outlet Actions
    @IBAction func backAction(_ sender: UIButton) {
        self.dismiss(animated: true, completion: {
            if let callback = self.completion {
                return callback(true)
            }
        })
    }

//    @IBAction func deleteAction(_ sender: Any) {
//        guard let pc = self.plantCommunity else{ return }
//        showAlert(title: "Would you like to delete this Plant Community?", description: "All monioring areas and pasture actions will also be removed", yesButtonTapped: {
//            RealmManager.shared.deletePlantCommunity(object: pc)
//            self.dismiss(animated: true, completion: {
//                if let callback = self.completion {
//                    return callback(true)
//                }
//            })
//        }, noButtonTapped: {})
//    }


    // MARK: Setup
    func setup(mode: FormMode, plan: RUP ,pasture: Pasture, plantCommunity: PlantCommunity, completion: @escaping (_ done: Bool) -> Void) {
        self.pasture = pasture
        self.mode = mode
        self.plantCommunity = plantCommunity
        self.completion = completion
        self.plan = plan
        setUpTable()
        autofill()
    }

    func autofill() {
        setTitle()
        setSubtitle()
    }

    func setTitle() {
        if self.pageTitle == nil {return}
        guard let community = self.plantCommunity else {return}
        self.pageTitle.text = "Plant Community: \(community.name)"
    }

    func setSubtitle() {
        if self.subtitle == nil { return }
        guard let p = self.pasture else {return}
        self.subtitle.text = "Pasture: \(p.name)"
    }

    func refreshPlantCommunityObject() {
        guard let p = self.plantCommunity else {return}

        do {
            let realm = try Realm()
            let temp = realm.objects(PlantCommunity.self).filter("localId = %@", p.localId).first!
            self.plantCommunity = temp
        } catch _ {
            fatalError()
        }
    }

    func reload(reloadData: Bool? = false, then: @escaping() -> Void) {
        refreshPlantCommunityObject()
        if #available(iOS 11.0, *) {
            self.tableView.performBatchUpdates({
                self.tableView.beginUpdates()
                self.tableView.endUpdates()
                if let r = reloadData, r {
                    self.tableView.reloadData()
                }
            }, completion: { done in
                self.tableView.layoutIfNeeded()
                if !done {
                    print (done)
                }
                return then()
            })
        } else {
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
            self.view.layoutIfNeeded()
            return then()
        }
    }

    // MARK: Styles
    func style() {
        styleNavBar(title: navbarTitle, navBar: navbar, statusBar: statusbar, primaryButton: backbutton, secondaryButton: nil, textLabel: nil)
        styleHeader(label: pageTitle)
        styleFooter(label: subtitle)
        styleDivider(divider: divider)
        styleHollowButton(button: saveButton)
    }

    // MARK: Banner
    func openBanner(message: String) {
        UIView.animate(withDuration: shortAnimationDuration, animations: {
            self.bannerLabel.textColor = Colors.primary
            self.banner.backgroundColor = Colors.secondaryBg.withAlphaComponent(1)
            self.bannerHeight.constant = 50
            self.bannerLabel.text = message
            self.view.layoutIfNeeded()
        }) { (done) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                UIView.animate(withDuration: self.mediumAnimationDuration, animations: {
                    self.bannerLabel.textColor = Colors.primaryConstrast
                    self.view.layoutIfNeeded()
                })
            })
        }
    }

    func closeBanner() {
        self.bannerHeight.constant = 0
        animateIt()
    }

    func closeBannerAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
            self.closeBanner()
        })
    }

    func showTempBanner(message: String) {
        openBanner(message: message)
        closeBannerAfterDelay()
    }

    func showMonitoringAreaDetailsPage(monitoringArea: MonitoringArea) {
        guard let p = self.plan, let pc = self.plantCommunity else {return}
        let vm = ViewManager()
        let monitoringAreaVC = vm.monitoringArea
        monitoringAreaVC.setup(mode: self.mode, plan: p, plantCommunity: pc, monitoringArea: monitoringArea) { (done) in
            self.reload(then: {})
        }
        self.present(monitoringAreaVC, animated: true, completion: nil)
    }

    // MARK: Utilities
    func hasPurposeOfActions() -> Bool {
        guard let pc = self.plantCommunity else {return false}

        if pc.purposeOfAction != "" || pc.purposeOfAction.lowercased() != "clear"{
            return true
        }
        return false
    }
}

// MARK: Tableview
extension PlantCommunityViewController:  UITableViewDelegate, UITableViewDataSource {
    func setUpTable() {
        if self.tableView == nil { return }
        tableView.delegate = self
        tableView.dataSource = self
        
        registerCell(name: "PlanCommunityBasicInfoTableViewCell")
        registerCell(name: "PlantCommunityMonitoringAreasTableViewCell")
        registerCell(name: "PlantCommunityPastureActionsTableViewCell")
        registerCell(name: "MonitoringAreaCustomDetailsTableViewCell")
        registerCell(name: "EmptyTableViewCell")

        let nib = UINib(nibName: "CustomSectionHeader", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "CustomSectionHeader")
    }

    func registerCell(name: String) {
        let nib = UINib(nibName: name, bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: name)
    }

    func getBasicInfoCell(indexPath: IndexPath) -> PlanCommunityBasicInfoTableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "PlanCommunityBasicInfoTableViewCell", for: indexPath) as! PlanCommunityBasicInfoTableViewCell
    }

    func getMonitoringAreasCell(indexPath: IndexPath) -> PlantCommunityMonitoringAreasTableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "PlantCommunityMonitoringAreasTableViewCell", for: indexPath) as! PlantCommunityMonitoringAreasTableViewCell
    }

    func getPastureActionsCell(indexPath: IndexPath) -> PlantCommunityPastureActionsTableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "PlantCommunityPastureActionsTableViewCell", for: indexPath) as! PlantCommunityPastureActionsTableViewCell
    }

    func getPlantIndicatorsCell(indexPath: IndexPath) -> MonitoringAreaCustomDetailsTableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "MonitoringAreaCustomDetailsTableViewCell", for: indexPath) as! MonitoringAreaCustomDetailsTableViewCell
    }

    func getEmptyCell(indexPath: IndexPath) -> EmptyTableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "EmptyTableViewCell", for: indexPath) as! EmptyTableViewCell
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let community = self.plantCommunity, let pl = self.plan else {return getBasicInfoCell(indexPath: indexPath)}
        switch indexPath.section {
        case 0:
            let cell = getBasicInfoCell(indexPath: indexPath)
            cell.setup(plantCommunity: community, mode: mode, parentReference: self)
            return cell
        case 1:
            if hasPurposeOfActions() {
                let cell = getPastureActionsCell(indexPath: indexPath)
                cell.setup(plantCommunity: community, mode: mode, parentReference: self)
                return cell
            } else {
                let cell = getEmptyCell(indexPath: indexPath)
                cell.setup(placeHolder: "", height: 1)
                return cell
            }
        case 2:
            let cell = getPlantIndicatorsCell(indexPath: indexPath)
            cell.setup(section: .RangeReadiness, mode: mode, plantCommunity: community, parentReference: self)
            return cell
        case 3:
            let cell = getPlantIndicatorsCell(indexPath: indexPath)
            cell.setup(section: .StubbleHeight, mode: mode, plantCommunity: community, parentReference: self)
            return cell
        case 4:
            let cell = getPlantIndicatorsCell(indexPath: indexPath)
            cell.setup(section: .ShrubUse, mode: mode, plantCommunity: community, parentReference: self)
            return cell
        case 5:
            let cell = getMonitoringAreasCell(indexPath: indexPath)
            cell.setup(plantCommunity: community, mode: mode, rup: pl, parentReference: self)
            return cell
        default:
            return getBasicInfoCell(indexPath: indexPath)
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        var sectionTitle = ""
        var icon: UIImage? = UIImage(named: "icon_MinistersIssues")!
        switch section {
        case 0:
            sectionTitle =  "Basic Plant Community Information"
        case 1:
           sectionTitle =  "Plant Community Actions"
        case 2:
            sectionTitle =  "Range Readiness"
        case 3:
            sectionTitle =  "Stubble Height"
        case 4:
            sectionTitle =  "Shrub Use"
        case 5:
            sectionTitle =  "Monitoring Areas"
        default:
            sectionTitle =  ""
        }
        
        // Dequeue with the reuse identifier
        let cell = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: "CustomSectionHeader")
        let header = cell as! CustomSectionHeader
        header.setup(title: sectionTitle, iconImage: icon)

        return cell
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60.0
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 6
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

}
