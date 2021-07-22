//
//  TrajectoryManager.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 13/7/21.
//

import Foundation
import os
import RealityKit

class TrajectoryManager {
    let TRAJ_SERVER_URL = "ws://192.168.1.201:8006"
    
    var networkManager: NetworkManager
    var webSocketConnection: URLSessionWebSocketTask?
    
    var arView: ARView
    var trajectoryAnchor: AnchorEntity
    
    var downloadTimer: Timer!
    
    var levelName: String?
    
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "TrajectoryManager")
    
    init(arView: ARView, networkManager: NetworkManager) {
        self.networkManager = networkManager
        
        webSocketConnection = self.networkManager.openWebSocketConnection(urlString: TRAJ_SERVER_URL)
        
        self.arView = arView
        trajectoryAnchor = AnchorEntity(world: [0,0,0])
        arView.scene.addAnchor(trajectoryAnchor)
        
        // Setup the timer
        self.downloadTimer = Timer(timeInterval: 1.0, target: self, selector: #selector(updateTrajectories), userInfo: nil, repeats: true)
        
        // Add some tolerance to reduce computational load
        self.downloadTimer.tolerance = 0.2
        
        // Start timer
        RunLoop.current.add(self.downloadTimer, forMode: .common)
        
        NotificationCenter.default.addObserver(self, selector: #selector(setLevelName), name: Notification.Name("setWorldOrigin"), object: nil)
    }
    
    @objc func setLevelName(_ notification: Notification) -> Void {
        guard let localizationData = notification.userInfo as? [String: String] else {
            logger.error("Notification's data did not match expected value")
            return
        }
        
        guard let levelName = localizationData["levelName"] else {
            logger.error("No level name in dict: \(localizationData)")
            return
        }
        
        self.levelName = levelName
    }
    
    @objc func updateTrajectories() {
        guard let connection = webSocketConnection else {
            logger.error("Web Socket connection was not opened")
            return
        }
        
        // Return if the level name has not been set yet -> only set when world origin is set
        guard let levelName = levelName else {
            logger.debug("Level name not set")
            return
        }
        
        let trajectoryReq = TrajectoryRequest(mapName: levelName, duration: 500, trim: false)
        
        networkManager.sendWebSocketRequest(webSocketConnection: connection, requestBody: trajectoryReq, responseBodyType: TrajectoryResponse.self) {
            trajectoryRes in
            
            self.networkManager.sendWebSocketRequest(webSocketConnection: connection, requestBody: TimeRequest(), responseBodyType: TimeResponse.self) {
                timeRes in
                
                guard let currentTimeInNanoseconds = timeRes.values.first else {
                    self.logger.error("No time received in response from server")
                    return
                }
                
                // Convert to milliseconds
                let currentTime: Int = Int(round(Double(currentTimeInNanoseconds) / 1000000))
                
                // Any drawing must be done on main thread
                DispatchQueue.main.async {
                    self.clearPreviousTrajectories()
                    
                    for robotTrajectory in trajectoryRes.values {

                        // Only two knots means no trajectory
                        if robotTrajectory.segments.count <= 2 {
                            continue
                        }
                        
                        self.addTrajectory(trajectory: robotTrajectory, currentTime: currentTime)
                    }
                }
                
            }
        }
    }
    
    func addTrajectory(trajectory: RobotTrajectory, currentTime: Int) {
        let trajEntity = TrajectoryEntity(trajectory: trajectory, currentTime: currentTime, color: .green)
        trajectoryAnchor.addChild(trajEntity)
    }
    
    func clearPreviousTrajectories() {
        trajectoryAnchor.children.removeAll()
    }
    
    deinit {
        downloadTimer.invalidate()
    }
}
