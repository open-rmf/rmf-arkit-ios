//
//  RobotStateManager.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 21/6/21.
//

import Foundation
import os
import RealityKit
import ARKit

class RobotStateManager {
    
    var arView: ARView
    
    var robots: [String: TrackedRobot] = [:]
    
    var robotUIAsset: Entity
    
    var networkManager: NetworkManager
    
    var downloadTimer: Timer!
    
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "RobotStateManager")
    
    init(arView: ARView, networkManager: NetworkManager) {
        self.arView = arView
        
        self.networkManager = networkManager

        do {
            self.robotUIAsset = try Entity.load(named: "robotUI.usdz")
        } catch {
            logger.error("\(error.localizedDescription)")
            self.robotUIAsset = Entity()
        }

        
        self.downloadTimer = Timer(timeInterval: 1.0, target: self, selector: #selector(updateRobotStates), userInfo: nil, repeats: true)
        
        // Add some tolerance to reduce computational load
        self.downloadTimer.tolerance = 0.2
        
        RunLoop.current.add(self.downloadTimer, forMode: .common)
    }
    
    func handleARAnchor(anchor: ARAnchor) {
        // Only process if the anchor is an image anchor
        guard let imageAnchor = anchor as? ARImageAnchor else {return}
        
        let tagName = imageAnchor.name!
        
        guard let robot = robots[tagName] else {
            logger.error("Robot with name: \(tagName) not found")
            return
        }
        
        if !robot.isVisualized {
            // Robot not seen before so create the necessary UI for it
            
            // Create a copy of the UI for robots
            let uiEntity = self.robotUIAsset.clone(recursive: true)
            
            let sceneAnchor = AnchorEntity.init(anchor: imageAnchor)
            sceneAnchor.name = tagName
            
            // TODO: Add an occlusion material so we dont see the panel from behind

            sceneAnchor.addChild(uiEntity)
            self.arView.scene.addAnchor(sceneAnchor)
            
            robots[tagName]!.isVisualized = true
        }
        
        // Check if ARKit is actively tracking the associated marker
        if imageAnchor.isTracked {
            robots[tagName]!.lastSeen = NSDate().timeIntervalSince1970
            robots[tagName]!.isTracked = true
        } else {
            robots[tagName]!.isTracked = false
        }
    }
    
    @objc func updateRobotStates() {
        self.networkManager.sendGetRequest(urlString: URLConstants.ROBOT_STATES, responseBodyType: [RobotState].self) {
            responseResult in
            
            var robotStatesList: [RobotState]
            
            // Check network was succesful
            switch responseResult {
            case .success(let data):
                robotStatesList = data
            case .failure(let e):
                self.logger.error("\(e.localizedDescription)")
                return
            }
            
            for state in robotStatesList {
                
                // Update robot state if its in our list, otherwise create a new entry
                if self.robots.contains(where: {key, _ in key == state.robotName}) {
                    self.robots[state.robotName]!.robotState = state
                } else {
                    self.robots[state.robotName] = TrackedRobot(robotState: state, isTracked: false, lastSeen: nil, isVisualized: false)
                }
            }
            
            // Publish robot data
            NotificationCenter.default.post(name: Notification.Name("robotStatesUpdated"), object: nil, userInfo: self.robots)
            
            // Drawing must be done on the main thread
            DispatchQueue.main.async {
                self.updateUIForAllRobots()
            }

        }
    }
    
    func updateUIForAllRobots() {

        // Update all UIs linked to robot states
        for (name, trackingData) in self.robots {
            guard let anchorEntity = self.arView.scene.findEntity(named: name) else {
                continue
            }
            self.updateTextInRobotUI(uiEntity: anchorEntity.children[0], state: trackingData.robotState)
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
    
    deinit {
        downloadTimer.invalidate()
    }
}
