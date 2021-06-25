//
//  ViewController.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 16/6/21.
//

import UIKit
import ARKit
import RealityKit
import Combine

class ViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet var arView: ARView!
    
    var robotStateManager: RobotStateManager!
    var buildingMapManager: BuildingMapManager!
    var localizer: RobotTagLocalizer!
    var networkManager = NetworkManager()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        robotStateManager = RobotStateManager(arView: arView, networkManager: networkManager)
        buildingMapManager = BuildingMapManager(arView: arView, networkManager: networkManager)
        localizer = RobotTagLocalizer(arView: arView)
        
        // Assign delegate
        arView.session.delegate = self
        
        // Debugging options
//        arView.debugOptions = ARView.DebugOptions([.showStatistics, .showWorldOrigin, .showAnchorGeometry, .showAnchorOrigins])
    
        // Setup AR configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Setup image tracking
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Tracking Images", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
    
        configuration.detectionImages = referenceImages
        configuration.maximumNumberOfTrackedImages = 1
        
        configuration.environmentTexturing = .automatic
        
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {

        for arAnchor in anchors {

            // Pass the anchor to the robot state manager
            robotStateManager.handleARAnchor(anchor: arAnchor)
        }
    }
}
