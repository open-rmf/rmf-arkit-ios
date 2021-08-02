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
    var robotsSemaphore = DispatchSemaphore(value: 1)
    
    var robotUIAsset: Entity
    
    var networkManager: NetworkManager
    
    var downloadTimer: Timer!
    
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "RobotStateManager")
    
    var isLocalized = false
    var uiLastUpdate = Date.distantPast
    
    init(arView: ARView, networkManager: NetworkManager) {
        self.arView = arView
        
        self.networkManager = networkManager

        do {
            self.robotUIAsset = try Entity.load(named: "robotUI.usdz")
        } catch {
            logger.error("\(error.localizedDescription)")
            self.robotUIAsset = Entity()
        }
        
        DispatchQueue.global().async {
            [weak self] in
            
            guard let self = self else { return }
            
            self.downloadTimer = Timer(timeInterval: (1 / ARConstants.RobotStates.DOWNLOAD_RATE), target: self, selector: #selector(self.updateRobotStates), userInfo: nil, repeats: true)
            
            let runLoop = RunLoop.current
            runLoop.add(self.downloadTimer, forMode: .default)
            runLoop.run()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(setIsLocalized), name: Notification.Name("setWorldOrigin"), object: nil)
    }
    
    func handleARAnchor(anchor: ARAnchor) {
        // Only process if the anchor is an image anchor
        guard let imageAnchor = anchor as? ARImageAnchor else {return}
        
        let tagName = imageAnchor.name!
        
        robotsSemaphore.wait()
    
        guard let robot = robots[tagName] else {
            logger.error("Robot with name: \(tagName) not found")
            robotsSemaphore.signal()
            return
        }
        
        // If no last seen time then we havent seen it before
        if robot.lastSeen == Date.distantPast {
            // Robot not seen before so create the necessary UI for it
            
            // Create a copy of the UI for robots
            let uiEntity = self.robotUIAsset.clone(recursive: true)
            
            let sceneAnchor = AnchorEntity.init(anchor: imageAnchor)
            sceneAnchor.name = tagName + "UI"
            
            // TODO: Add an occlusion material so we dont see the panel from behind

            sceneAnchor.addChild(uiEntity)
            self.arView.scene.addAnchor(sceneAnchor)
        }
        
        // Check if ARKit is actively tracking the associated marker
        if imageAnchor.isTracked {
            robots[tagName]!.lastSeen = Date()
            robots[tagName]!.isTracked = true
        } else {
            robots[tagName]!.isTracked = false
        }
        
        robotsSemaphore.signal()
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
        
            self.robotsSemaphore.wait()
            for state in robotStatesList {
                
                // Update robot state if its in our list, otherwise create a new entry
                if self.robots.contains(where: {key, _ in key == state.robotName}) {
                    self.robots[state.robotName]!.robotState = state
                } else {
                    self.robots[state.robotName] = TrackedRobot(robotState: state, isTracked: false)
                }
            }
            self.robotsSemaphore.signal()
                
            DispatchQueue.main.async {
                self.robotsSemaphore.wait()
                if self.isLocalized {
                    self.updateRobotMarkers()
                }
                
                self.updateTextInRobotUI()
                self.robotsSemaphore.signal()
            }
            
            // Publish robot data
            NotificationCenter.default.post(name: Notification.Name("robotStatesUpdated"), object: nil, userInfo: self.robots)
        }
    }
    
    @objc func setIsLocalized(_ notification: Notification) {
        isLocalized = true
    }
    
    func updateRobotMarkers() {
        
        var markersAnchor: AnchorEntity? = arView.scene.findEntity(named: "RobotMarkers") as? AnchorEntity
        
        // Create the marker anchor if not created. Otherwise remove all children
        if markersAnchor == nil {
            markersAnchor = AnchorEntity(world: .zero)
            markersAnchor!.name = "RobotMarkers"
            arView.scene.addAnchor(markersAnchor!)
        }
        
        for (name, trackingData) in self.robots {
            var robotMarker = arView.scene.findEntity(named: name + "Marker")
            
            if robotMarker == nil {
                let robotMesh = MeshResource.generateSphere(radius: 0.2)
                let robotMaterial = SimpleMaterial(color: .purple, isMetallic: false)
                robotMarker = ModelEntity(mesh: robotMesh, materials: [robotMaterial])
                robotMarker!.name = name + "Marker"
                markersAnchor?.addChild(robotMarker!)
            }

            let x = Float(trackingData.robotState.locationX)
            let y = Float(trackingData.robotState.locationY)
            
            // Only show the marker if it has not been seen recently (5 seconds)
            if Date().timeIntervalSince(trackingData.lastSeen) > 5 {
                robotMarker?.isEnabled = true
            } else {
                robotMarker?.isEnabled = false
            }
            

            robotMarker!.setPosition([x, y, ARConstants.RobotStates.Z_OFFSET], relativeTo: nil)
        }
    }
    
    func updateTextInRobotUI() {
        let currentTime = Date()
        
        // Updating the UI is very expensive. Throttle to update only every second to ensure FPS remains high
        if currentTime.timeIntervalSince(uiLastUpdate) < 1 {
            return
        } else {
            uiLastUpdate = currentTime
        }
        
        // Update all UIs linked to robot states
        for (name, trackingData) in self.robots {
            
            // Skip when not seen
            if !trackingData.isTracked {
                continue
            }
            
            guard let uiEntity = self.arView.scene.findEntity(named: name + "UI") else {
                logger.error("Cant find UI for robot: \(name)")
                continue
            }
            
            // Allows us to iterate over all the fields in the RobotState struct
            let mirror = Mirror(reflecting: trackingData.robotState)
            
            for field in mirror.children {
                var fontSize = CGFloat(0.1)
                
                if field.label! == "fleetName" {
                    fontSize = CGFloat(0.08)
                }
                
                guard let namedEntity = uiEntity.findEntity(named: field.label!) else {continue}
                guard let textModelEntity = namedEntity.findEntity(named: "Text")?.children.first as? ModelEntity else {
                    continue}
                
                textModelEntity.model?.mesh = .generateText("\(field.value)", extrusionDepth: 0.01, font: .init(name: "Helvetica", size: fontSize)!)
            }
            
        }
    }
    
    deinit {
        downloadTimer.invalidate()
    }
}
