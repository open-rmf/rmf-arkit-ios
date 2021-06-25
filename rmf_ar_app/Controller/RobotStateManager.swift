//
//  RobotStateManager.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 21/6/21.
//

import Foundation
import RealityKit
import ARKit

class RobotStateManager {
    
    let ROBOT_STATES_URL = "http://192.168.1.201:8080/robot_list"

    var arView: ARView
    
    var robotStates: [String:RobotState] = [:]
    var trackedTags: [String] = []
    
    var robotUIAsset: Entity
    
    var networkManager = NetworkManager()
    
    init(arView: ARView, networkManager: NetworkManager) {
        self.arView = arView
        self.networkManager = networkManager
        
        self.robotUIAsset = try! Entity.load(named: "robotUI")
    }
    
    func handleARAnchor(anchor: ARAnchor) {
        // Only process if the anchor is an image anchor
        guard let imageAnchor = anchor as? ARImageAnchor else {return}
        
        self.downloadAndUpdateRobotStates()
        self.manageImageAnchor(imageAnchor: imageAnchor)
    }
    
    func manageImageAnchor(imageAnchor: ARImageAnchor) {
        
        let tagName = imageAnchor.name!
        
        // Only do something if we have not seen this tag before
        if !trackedTags.contains(tagName) {

            // Create a copy of the UI for robots
            let uiEntity = self.robotUIAsset.clone(recursive: true)

            // Update UI with latest robotState data
            if let state = self.robotStates[tagName] {
                self.updateTextInRobotUI(uiEntity: uiEntity, state: state)
            }

            
            // TODO: Add an occlusion material so we dont see the panel from behind
            let sceneAnchor = AnchorEntity.init(anchor: imageAnchor)
            sceneAnchor.name = tagName

            sceneAnchor.addChild(uiEntity)
            self.arView.scene.addAnchor(sceneAnchor)
            self.trackedTags.append(tagName)
        }
    }
    
    func downloadAndUpdateRobotStates() {
        self.networkManager.getJSONfromURLasync(urlString: ROBOT_STATES_URL, modelType: [RobotState].self) {
            model in
            
            for state in model {
                self.robotStates[state.robotName] = state
            }
            
            // Something is wrong with updateTextInUI (mainly the generateText).
            // For some reason wrapping in a DispatchQueue makes it work...
            DispatchQueue.main.async {
                self.updateUIForAllRobots()
            }

        }
    }
    
    func updateUIForAllRobots() {

        // Update all UIs linked to robot states
        for (name, state) in self.robotStates {
            guard let anchorEntity = self.arView.scene.findEntity(named: name) else {
                continue
            }
            self.updateTextInRobotUI(uiEntity: anchorEntity.children[0], state: state)
        }
        
        // Check that we are tracking tags and send a notification that the robot states were updated along with the updated tracked states
        if trackedTags.count != 0 {
            let trackedRobotStates = robotStates.filter {trackedTags.contains($0.key)}
            NotificationCenter.default.post(name: Notification.Name("robotStatesUpdated"), object: nil, userInfo: trackedRobotStates)
        }

    }
    
    func updateTextInRobotUI(uiEntity: Entity, state: RobotState) {
        
        // Allows us to iterate over all the fields in the RobotState struct
        let mirror = Mirror(reflecting: state)
        
        for field in mirror.children {
            var fontSize = CGFloat(0.1)
            
            if field.label! == "fleetName" {
                fontSize = CGFloat(0.08)
            }
            
            guard let namedEntity = uiEntity.findEntity(named: field.label!) else {continue}
            guard let textModelEntity = namedEntity.findEntity(named: "Text")?.children.first as? ModelEntity else {continue}
            textModelEntity.model?.mesh = .generateText("\(field.value)", extrusionDepth: 0.01, font: .init(name: "Helvetica", size: fontSize)!)
        }
    }
    
    
    
}
