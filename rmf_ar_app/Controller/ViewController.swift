//
//  ViewController.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 16/6/21.
//

import UIKit
import ARKit
import RealityKit
import SideMenu

class ViewController: UIViewController {
    
    // MARK: - UI Elements
    let coachingOverlay = ARCoachingOverlayView()
    @IBOutlet var arView: ARView!
    var taskViewController: TaskViewController!
    var settingsViewController: SettingsViewController!
    
    // MARK: - Data Managers
    var networkManager: NetworkManager!
    var robotStateManager: RobotStateManager!
    var buildingMapManager: BuildingMapManager!
    var trajectoryManager: TrajectoryManager!
    var localizer: RobotTagLocalizer!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        setupCoachingOverlay()
        
        // Setup all the managers and controllers
        networkManager = NetworkManager()
        robotStateManager = RobotStateManager(arView: arView, networkManager: networkManager)
        buildingMapManager = BuildingMapManager(arView: arView, networkManager: networkManager)
        trajectoryManager = TrajectoryManager(arView: arView, networkManager: networkManager, robotStateManager: robotStateManager)
        localizer = RobotTagLocalizer(arView: arView, robotStateManager: robotStateManager)
        
        taskViewController = self.storyboard?.instantiateViewController(identifier: "Task View Controller")
        taskViewController.taskManager = TaskManager(networkManager: networkManager)
        
        settingsViewController = SettingsViewController()
        
        // Assign delegate
        arView.session.delegate = self
        
        // Debugging options
//        arView.debugOptions = ARView.DebugOptions([.showStatistics, .showWorldOrigin, .showAnchorOrigins])
        
        // Setup AR configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Setup image tracking
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Tracking Images", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        
        configuration.detectionImages = referenceImages
        configuration.maximumNumberOfTrackedImages = 5
    
        
        configuration.environmentTexturing = .automatic
        
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])        
    }
    
    // MARK: - Menu Buttons
    @IBAction func taskMenuButtonTapped(_ sender: Any) {
        taskViewController.modalPresentationStyle = .custom
        taskViewController.transitioningDelegate = self
        self.present(taskViewController, animated: true, completion: nil)
    }
    
    @IBAction func settingsMenuButtonTapped(_ sender: Any) {
        let settingsMenu = SideMenuNavigationController(rootViewController: settingsViewController)
        settingsMenu.leftSide = true
        settingsMenu.presentationStyle = .menuSlideIn
        
        self.present(settingsMenu, animated: true, completion: nil)
    }
}

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {

        for arAnchor in anchors {

            // Pass the anchor to the robot state manager
            robotStateManager.handleARAnchor(anchor: arAnchor)
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {

        for arAnchor in anchors {

            // Pass the anchor to the robot state manager
            robotStateManager.handleARAnchor(anchor: arAnchor)
        }
    }
}

extension ViewController: ARCoachingOverlayViewDelegate {
    func setupCoachingOverlay() {
        // Set up coaching view
        coachingOverlay.session = arView.session
        coachingOverlay.delegate = self
        
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coachingOverlay)
        
        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: view.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: view.heightAnchor)
            ])
        
        coachingOverlay.activatesAutomatically = true
        
        coachingOverlay.goal = .tracking
    }
}

extension ViewController: UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        PresentationController(presentedViewController: presented, presenting: presenting)
    }
}
