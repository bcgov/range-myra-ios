//
//  ViewController.swift
//  Myra
//
//  Created by Amir Shayegh on 2018-02-13.
//  Copyright © 2018 Government of British Columbia. All rights reserved.
//

import UIKit
import Reachability
import SingleSignOn
import Lottie
import RealmSwift
import Realm
import MaterialShowcase

class HomeViewController: BaseViewController {

    // MARK: Constants
    let reachability = Reachability()!
    var syncButtonAnimationTag = 120
    var syncButtonActionTag = 121

    // MARK: Variables
    var realmNotificationToken: NotificationToken?
    var parentReference: MainViewController?
    var rups: [RUP] = [RUP]()
    var expandIndexPath: IndexPath?

    var unstableConnection: Bool = false

    var online: Bool = false {
        didSet {
            updateAccordingToNetworkStatus()
        }
    }

    var syncing: Bool = false

    var tours: [TourTip] = [TourTip]()

    // MARK: Outlets
    @IBOutlet weak var containerView: UIView!

    // Top
    @IBOutlet weak var userBoxView: UIView!
    @IBOutlet weak var userBoxLabel: UILabel!
    @IBOutlet weak var statusBar: UIView!
    @IBOutlet weak var navBar: UIView!
    @IBOutlet weak var navBarImage: UIImageView!
    @IBOutlet weak var syncButtonLabel: UILabel!
    @IBOutlet weak var syncLabel: UILabel!
    @IBOutlet weak var connectivityLabel: UILabel!
    @IBOutlet weak var lastSyncLabel: UILabel!
    @IBOutlet weak var viewTitle: UILabel!
    @IBOutlet weak var connectivityLight: UIView!

    // sync
    @IBOutlet weak var syncButton: UIButton!
    @IBOutlet weak var syncContainer: UIView!

    // Create button and filters
    @IBOutlet weak var topContainer: UIView!
    @IBOutlet weak var createButton: UIButton!
    @IBOutlet weak var allFilter: UIButton!
    @IBOutlet weak var draftsFilter: UIButton!
    @IBOutlet weak var pendingFilter: UIButton!
    @IBOutlet weak var completedFilter: UIButton!
    @IBOutlet weak var filtersStack: UIStackView!

    // table
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableHeaderSeparator: UIView!

    // headers
    @IBOutlet weak var rangeNumberHeader: UILabel!
    @IBOutlet weak var agreementHolderHeader: UILabel!
    @IBOutlet weak var rangeNameHeader: UILabel!
    @IBOutlet weak var statusHeader: UILabel!


    // MARK: ViewController functions
    override func viewDidLoad() {
        super.viewDidLoad()
        syncing = false
        loadHome()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupReachabilityNotification()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.endChangeListener()
    }

    // MARK: Outlet actions

    @IBAction func tourAction(_ sender: UIButton) {
        loadTourTips()
        if let first = tours.popLast() {
            show(tourTip: first)
        }
    }

    @IBAction func createRUPAction(_ sender: UIButton) {
        let vm = ViewManager()
        let vc = vm.selectAgreement
        vc.setup(callBack: { closed in
            self.loadHome()
        })
        self.present(vc, animated: true, completion: nil)
    }

    @IBAction func syncAction(_ sender: UIButton) {
        sender.isUserInteractionEnabled = false
        syncButtonLabel.alpha = 1
        syncButtonLabel.text = "Connecting..."
        animateIt()
        showSyncMessage(text: "Connection taking longer than expected...", after: 5)
        showSyncMessage(text: "Your connection is very unstable...", after: 10)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: {
            if self.syncButtonLabel.alpha == 1 {
                self.unstableConnection = true
            }
        })
        authenticateIfRequred()
    }

    @IBAction func filterAction(_ sender: UIButton) {
        switch sender {
        case allFilter:
            filterByAll()
        case draftsFilter:
            filterByDrafts()
        case pendingFilter:
            filterByPending()
        case completedFilter:
            filterByCompleted()
        default:
            print("not possible.. why would you link anything else to this?")
        }
    }

    @IBAction func userAction(_ sender: UIButton) {
        showLogoutOption(on: sender)
    }

    // MARK: Filter
    func filterByAll() {
        if syncing {return}
        filterButtonOn(button: allFilter)
        sortByRangeNumber()
        self.tableView.reloadData()
    }

    func filterByDrafts() {
        if syncing {return}
        loadRUPs()
        filterButtonOn(button: draftsFilter)
        let staffDraft = RUPManager.shared.getStaffDraftRups()
        self.rups = RUPManager.shared.getDraftRups()
        self.rups.append(contentsOf: staffDraft)
        self.tableView.reloadData()
    }

    func filterByPending() {
        if syncing {return}
        loadRUPs()
        filterButtonOn(button: pendingFilter)
        self.rups = RUPManager.shared.getPendingRups()
        self.tableView.reloadData()
    }

    func filterByCompleted() {
        if syncing {return}
        loadRUPs()
        filterButtonOn(button: completedFilter)
        self.rups = RUPManager.shared.getCompletedRups()
        self.tableView.reloadData()
    }

    func sortByAgreementHolder() {
        if syncing {return}
        loadRUPs()
        self.rups = self.rups.sorted(by: {$0.primaryAgreementHolderLastName < $1.primaryAgreementHolderLastName})
    }

    func sortByRangeName() {
        if syncing {return}
        loadRUPs()
        self.rups = self.rups.sorted(by: {$0.rangeName < $1.rangeName})
    }

    func sortByStatus() {
        if syncing {return}
        loadRUPs()
        self.rups = self.rups.sorted(by: {$0.getStatus().rawValue < $1.getStatus().rawValue})
    }

    func sortByRangeNumber() {
        if syncing {return}
        loadRUPs()
        self.rups = self.rups.sorted(by: {$0.ranNumber < $1.ranNumber})
    }

    // MARK: setup
    /*
     When loading home page,

     1) check if a last sync date exists.
     if not, show login page
     else, set last sync date label
     2) setup table view
     3) get rups that dont have status: Agreeemnt
     4) reload table to load the rups from step 3
     */

    func loadHome() {
        style()
        if let query = RealmRequests.getObject(SyncDate.self), let last = query.last {
            lastSyncLabel.text = last.timeSince()
        } else {
            authenticateIfRequred()
        }
        setUpTable()
        filterByAll()
        beginChangeListener()
    }

    func beginChangeListener() {
        // Listener used for autosync:
        // If db has changed in this view, there probably was an autosync.
        print("Listening to db changes in HomeVC!")
        do {
            let realm = try Realm()
            self.realmNotificationToken = realm.observe { notification, realm in
                print("change observed in homeVC")
                self.loadRUPs()
                self.tableView.reloadData()
            }
        } catch _ {
            fatalError()
        }
    }

    func endChangeListener() {
        if let token = self.realmNotificationToken {
            token.invalidate()
            print("Stopped Listening in homeVC:(")
        }
    }

    func loadRUPs() {
        if syncing {return}
        RUPManager.shared.fixUnlinkedPlans()
        self.rups = [RUP]()
        self.tableView.reloadData()
        /*
         Clean up the local DB by removing plans that were created
         from agreements but cancelled.
         */
        RUPManager.shared.cleanPlans()
        let rups = RUPManager.shared.getRUPs()
        print(rups.count)
        let agreements = RUPManager.shared.getAgreements()
        for agreement in agreements where agreement.rups.count > 0 {
            if let p = agreement.getLatestPlan() {
                self.rups.append(p)
            }
        }
        self.expandIndexPath = nil
        self.tableView.reloadData()
        AutoSync.shared.autoSync()
    }

    // MARK: Styles
    func style() {
        setStatusBarAppearanceLight()
        styleNavBar()
        styleFillButton(button: createButton)
        styleFilterContainer()
        styleUserBox()
        makeCircle(view: connectivityLight)
        setFilterButtonFonts()
        tableHeaderSeparator.backgroundColor = Colors.secondary
        styleSyncBox()
        styleHeaders()
    }

    func styleHeaders() {
        styleTableColumnHeader(label: rangeNumberHeader)
        styleTableColumnHeader(label: agreementHolderHeader)
        styleTableColumnHeader(label: rangeNameHeader)
        styleTableColumnHeader(label: statusHeader)
    }

    func styleNavBar() {
        // lower alpha to show image behind
        statusBar.alpha = 0.8
        navBar.alpha = 0.8

        navBarImage.image = #imageLiteral(resourceName: "homeNavBarImage")

        // background color
        statusBar.backgroundColor = Colors.primary
        navBar.backgroundColor = Colors.primary

        // text colors
        syncLabel.textColor = UIColor.white
        connectivityLabel.textColor = UIColor.white
        lastSyncLabel.textColor = UIColor.white
        viewTitle.textColor = UIColor.white

        // fonts
        syncLabel.font = Fonts.getPrimary(size: 15)
        connectivityLabel.font = Fonts.getPrimary(size: 15)
        lastSyncLabel.font = Fonts.getPrimary(size: 15)
        viewTitle.font = Fonts.getPrimaryBold(size: 40)
        viewTitle.change(kernValue: -0.32)
    }

    func styleFilterContainer() {
        topContainer.backgroundColor = UIColor.white
        addShadow(to: topContainer.layer, opacity: 0.5, height: 1)
    }

    func styleUserBox() {
        makeCircle(view: userBoxView)
        userBoxView.backgroundColor = UIColor.white
        userBoxLabel.textColor = Colors.mainText
    }

    func styleSyncBox() {
        makeCircle(view: syncContainer)
        syncContainer.backgroundColor = UIColor.white

        // if animation exists, play.
        if let animation = self.view.viewWithTag(syncButtonAnimationTag) as? LOTAnimationView {
            animation.loopAnimation = false
            animation.play()
        } else {
            // add animated image
            let animatedSync = LOTAnimationView(name: "sync_icon")
            animatedSync.frame = syncContainer.frame
            animatedSync.center.y = syncButton.center.y
            animatedSync.center.x = syncButton.center.x
            animatedSync.contentMode = .scaleAspectFit
            animatedSync.loopAnimation = false
            animatedSync.tag = syncButtonAnimationTag
            self.syncContainer.addSubview(animatedSync)
            animatedSync.play()
        }

        // Note: now animation overlaps button.. so move the button to top
        if let button = self.view.viewWithTag(syncButtonActionTag) {
            self.syncContainer.addSubview(button)
        }
    }

    func playSyncButtonAnimation() {
        if let animation = self.view.viewWithTag(syncButtonAnimationTag) as? LOTAnimationView {
            animation.loopAnimation = true
            animation.play()
        }
    }

    func stopSyncButtonAnimation() {
        if let animation = self.view.viewWithTag(syncButtonAnimationTag) as? LOTAnimationView {
            animation.stop()
        }
    }

    func filterButtonOn(button: UIButton) {
        swtichFilterButtonsOff()
        button.setTitleColor(Colors.secondary, for: .normal)
    }

    func filterButtonOff(button: UIButton) {
        button.setTitleColor(Colors.bodyText, for: .normal)
        button.titleLabel?.font = Fonts.getPrimaryMedium(size: 17)
    }

    func swtichFilterButtonsOff() {
        filterButtonOff(button: allFilter)
        filterButtonOff(button: draftsFilter)
        filterButtonOff(button: pendingFilter)
        filterButtonOff(button: completedFilter)
    }

    func setFilterButtonFonts() {
        styleFilter(label: allFilter.titleLabel!)
        styleFilter(label: draftsFilter.titleLabel!)
        styleFilter(label: pendingFilter.titleLabel!)
        styleFilter(label: completedFilter.titleLabel!)
    }

    // MARK: Sync
    func showSyncMessage(text: String, after: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + after, execute: {
            self.syncButtonLabel.text = text
            self.animateIt()
        })
    }

    override func onAuthenticationSuccess() {
        //        print(APIManager.headers())
        if unstableConnection {
            syncButtonLabel.text = "Connections is not stable for enough for a full sync"
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
                self.syncButtonLabel.alpha = 0
                self.syncButton.isUserInteractionEnabled = true
                self.unstableConnection = false
                self.animateIt()
            })
            return
        }
        self.syncButtonLabel.alpha = 0
        synchronize()
    }

    override func onAuthenticationFail() {
        self.syncButtonLabel.alpha = 0
        self.syncButton.isUserInteractionEnabled = true
    }

    func synchronize() {
        self.rups = [RUP]()
        self.tableView.reloadData()
        self.endChangeListener()
        self.syncing = true
        self.createButton.isUserInteractionEnabled = false
        self.tableView.isUserInteractionEnabled = false
        self.syncButton.isUserInteractionEnabled = false
        sync { (done) in
            self.syncing = false
            self.loadHome()
            self.createButton.isUserInteractionEnabled = true
            self.tableView.isUserInteractionEnabled = true
            self.syncButton.isUserInteractionEnabled = true
        }
    }

}

// MARK: TableView functions
extension HomeViewController: UITableViewDelegate, UITableViewDataSource {
    func setUpTable() {
        tableView.delegate = self
        tableView.dataSource = self
        registerCell(name: "AssignedRUPTableViewCell")
    }

    func registerCell(name: String) {
        let nib = UINib(nibName: name, bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: name)
    }

    func getAssignedRupCell(indexPath: IndexPath) -> AssignedRUPTableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "AssignedRUPTableViewCell", for: indexPath) as! AssignedRUPTableViewCell
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let index = indexPath.row
        let cell = getAssignedRupCell(indexPath: indexPath)
        var expandFlag: Bool? = nil
        if let selectedIndex = self.expandIndexPath {
            if selectedIndex == indexPath {
                expandFlag = true
            } else {
                expandFlag = false
            }
        }
        if index % 2 == 0 {
            cell.setup(rup: rups[index], color: Colors.evenCell, expand: expandFlag)
        } else {
            cell.setup(rup: rups[index], color: Colors.oddCell, expand: expandFlag)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rups.count
    }

    func rupsAreValid() -> Bool {
        for element in self.rups {
            if element.isInvalidated {
                return false
            }
        }
        return true
    }

    func reloadRupsIfInvalid() {
        if !rupsAreValid() {
            loadRUPs()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        reloadRupsIfInvalid()
        if expandIndexPath == nil {
            self.expandIndexPath = indexPath
            self.tableView.isScrollEnabled = false
            if #available(iOS 11.0, *) {
                self.tableView.performBatchUpdates({
                    self.tableView.reloadRows(at: [indexPath], with: .fade)
                }) { (done) in
                    self.tableView.reloadData()
                    // if indexpath is the last visible, scroll to bottom of it
                    if let visible = tableView.indexPathsForVisibleRows, visible.last == indexPath {
                        self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
                    }
                }
            } else {
                // PRE ios 11
                self.tableView.reloadData()
                // if indexpath is the last visible, scroll to bottom of it
                if let visible = tableView.indexPathsForVisibleRows, visible.last == indexPath {
                    self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
                }
            }
        } else {
            if #available(iOS 11.0, *) {
                self.tableView.performBatchUpdates({
                    if let i = expandIndexPath {
                        let cell = self.tableView.cellForRow(at: i) as! AssignedRUPTableViewCell
                        cell.styleDefault()
                        self.expandIndexPath = nil
                        self.tableView.reloadRows(at: [indexPath], with: .fade)
                    }
                }) { (done) in
                    self.tableView.reloadData()
                }
            } else {
                self.expandIndexPath = nil
                self.tableView.reloadData()
            }
            self.tableView.isScrollEnabled = true
        }
    }
}

// Functions to handle retrival of rups
extension HomeViewController {

    func getRUPs()  {
        loadRUPs()
        // sort by last name
        self.rups = rups.sorted(by: { $0.primaryAgreementHolderLastName < $1.primaryAgreementHolderLastName })
        filterByAll()
    }
}

// Functions to handle displaying views
extension HomeViewController {

    func editRUP(rup: RUP) {
        let vc = getCreateNewVC()
        vc.setup(rup: rup, mode: .Edit) { closed, cancel  in
            self.getRUPs()
        }
        self.present(vc, animated: true, completion: nil)
    }

    func viewRUP(rup: RUP) {
        let vc = getCreateNewVC()
        vc.setup(rup: rup, mode: .View) { closed, cancel in
            self.tableView.reloadData()
        }
        self.present(vc, animated: true, completion: nil)
    }

    func getCreateNewVC() -> CreateNewRUPViewController {
        let vm = ViewManager()
        return vm.createRUP
    }

    func showCreate() {
        let vc = getCreateNewVC()
        self.present(vc, animated: true, completion: nil)
    }
}

// Connectivity
extension HomeViewController {
    func setupReachabilityNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged), name: .reachabilityChanged, object: reachability)
        do{
            try reachability.startNotifier()
        }catch{
            print("could not start reachability notifier")
        }
    }

    @objc func reachabilityChanged(note: Notification) {
        let reachability = note.object as! Reachability
        switch reachability.connection {
        case .wifi:
            online = true
        case .cellular:
            online = true
        case .none:
            online = false
        }
    }

    func updateAccordingToNetworkStatus() {
        if online {
            self.syncContainer.alpha = 1
            syncButton.isEnabled = true
            self.connectivityLabel.text = "Online Mode"
            self.connectivityLight.backgroundColor = UIColor.green
            AutoSync.shared.autoSync()
        } else {
            self.syncContainer.alpha = 0
            syncButton.isEnabled = false
            self.connectivityLabel.text = "Offline Mode"
            self.connectivityLight.backgroundColor = UIColor.red
            self.syncing = false
        }
    }
}


// Tourtip

class TourTip {
    var title: String = ""
    var desc: String = ""
    var target: UIView

    init(title: String, desc: String, target: UIView) {
        self.title = title
        self.desc = desc
        self.target = target
    }
}

extension HomeViewController: MaterialShowcaseDelegate {

    func show(tourTip: TourTip) {
        let showcase = MaterialShowcase()
        showcase.setTargetView(view: tourTip.target)
        showcase.primaryText = tourTip.title
        showcase.secondaryText = tourTip.desc
        // Background
        showcase.backgroundPromptColor = Colors.active.blue
        showcase.backgroundPromptColorAlpha = 0.9
        showcase.targetHolderColor = Colors.active.lightBlue
        // Text
        showcase.primaryTextColor = UIColor.white
        showcase.secondaryTextColor = UIColor.white
        showcase.primaryTextFont = Fonts.getPrimaryMedium(size: 23)
        showcase.secondaryTextFont = Fonts.getPrimary(size: 17)
        showcase.delegate = self
        showcase.show(completion: {})
    }

    func loadTourTips() {
        let createNewTour = TourTip(title: tourCreateNewRupTitle, desc: tourCreateNewRupDesc, target: createButton)
        let syncTour = TourTip(title: tourSyncTitle, desc: tourSyncDesc, target: syncContainer)
        let logoutTour = TourTip(title: tourLogoutTitle, desc: tourLogoutDesc, target: userBoxView)
        let filtersTour = TourTip(title: tourFiltersTitle, desc: tourFiltersDesc, target: allFilter)
        let lastSyncTour = TourTip(title: tourlastSyncTitle, desc: tourlastSyncDesc, target: lastSyncLabel)
        self.tours.removeAll()
        self.tours.append(createNewTour)
        self.tours.append(syncTour)
        self.tours.append(lastSyncTour)
        self.tours.append(filtersTour)
        self.tours.append(logoutTour)
    }

    func showCaseWillDismiss(showcase: MaterialShowcase, didTapTarget: Bool) {
    }

    func showCaseDidDismiss(showcase: MaterialShowcase, didTapTarget: Bool) {
        if let next = self.tours.popLast() {
            show(tourTip: next)
        }
    }
}


