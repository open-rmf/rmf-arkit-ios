//
//  ViewController.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 16/6/21.
//

import UIKit
import ARKit
import RealityKit

class ViewController: UIViewController {
        
    @IBOutlet var arView: ARView!
    @IBOutlet weak var trackingStateIndicator: UIButton!
    
    var networkManager: NetworkManager!
    var robotStateManager: RobotStateManager!
    var buildingMapManager: BuildingMapManager!
    var trajectoryManager: TrajectoryManager!
    var localizer: RobotTagLocalizer!
    
    var taskViewController: TaskViewController!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        
        // Setup the tracking state indicator
        trackingStateIndicator.layer.cornerRadius = 10
        trackingStateIndicator.layer.cornerCurve = .continuous
        trackingStateIndicator.layer.backgroundColor = UIColor.red.cgColor
        
        // Setup all the managers and controllers
        networkManager = NetworkManager()
        robotStateManager = RobotStateManager(arView: arView, networkManager: networkManager)
        buildingMapManager = BuildingMapManager(arView: arView, networkManager: networkManager)
        trajectoryManager = TrajectoryManager(arView: arView, networkManager: networkManager)
        localizer = RobotTagLocalizer(arView: arView)
        
        taskViewController = self.storyboard?.instantiateViewController(identifier: "Task View Controller")
        taskViewController.taskManager = TaskManager(networkManager: networkManager)
        
        // Assign delegate
        arView.session.delegate = self
        
        // Debugging options
        arView.debugOptions = ARView.DebugOptions([.showStatistics, .showWorldOrigin])
        
        // Setup AR configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Setup image tracking
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Tracking Images", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        
        configuration.detectionImages = referenceImages
        configuration.maximumNumberOfTrackedImages = 1
    
        
        configuration.environmentTexturing = .automatic
        
        arView.session.run(configuration, options: [])        
    }
    
    @IBAction func taskMenuButtonTapped(_ sender: Any) {
        taskViewController.modalPresentationStyle = .custom
        taskViewController.transitioningDelegate = self
        self.present(taskViewController, animated: true, completion: nil)
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

extension ViewController: ARSessionObserver {
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            trackingStateIndicator.layer.backgroundColor = UIColor.green.cgColor
        case .notAvailable:
            trackingStateIndicator.layer.backgroundColor = UIColor.green.cgColor
        default:
            trackingStateIndicator.layer.backgroundColor = UIColor.yellow.cgColor
        }
    }
}

extension ViewController: UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        PresentationController(presentedViewController: presented, presenting: presenting)
    }
}
