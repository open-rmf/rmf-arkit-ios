//
//  TrajectoryManager.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 13/7/21.
//

import Foundation
import os
import UIKit
import RealityKit

class TrajectoryManager {
    
    let NO_COLLISION_COLOR = UIColor.green
    let COLLISION_COLOR = UIColor.red
    
    var networkManager: NetworkManager
    var webSocketConnection: URLSessionWebSocketTask?
    
    var arView: ARView
    var trajectoryAnchor: AnchorEntity
    
    var downloadTimer: Timer!
    
    var levelName: String?
    var heightLevelMap: [Int:[RobotTrajectory]] = [:]
    
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "TrajectoryManager")
    
    init(arView: ARView, networkManager: NetworkManager) {
        self.networkManager = networkManager
        
        webSocketConnection = self.networkManager.openWebSocketConnection(urlString: URLConstants.TRAJ_SERVER)
        
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
            trajectoryResponseResult in
            
            var trajectoryResponse: TrajectoryResponse
            
            // Check network was succesful
            switch trajectoryResponseResult {
            case .success(let data):
                trajectoryResponse = data
            case .failure(let e):
                self.logger.error("\(e.localizedDescription)")
                return
            }
            
            self.networkManager.sendWebSocketRequest(webSocketConnection: connection, requestBody: TimeRequest(), responseBodyType: TimeResponse.self) {
                timeResponseResult in
                
                var timeResponse: TimeResponse
                
                // Check network was succesful
                switch timeResponseResult {
                case .success(let data):
                    timeResponse = data
                case .failure(let e):
                    self.logger.error("\(e.localizedDescription)")
                    return
                }
                
                guard let currentTimeInNanoseconds = timeResponse.values.first else {
                    self.logger.error("No time received in response from server")
                    return
                }
                
                // Convert to milliseconds
                let currentTime: Int = Int(round(Double(currentTimeInNanoseconds) / 1000000))
                
                // Any drawing must be done on main thread
                DispatchQueue.main.async {
                    self.visualizeTrajectories(trajectoryResponse: trajectoryResponse, currentTime: currentTime)
                }
                
            }
        }
    }
    
    func visualizeTrajectories(trajectoryResponse trajectories: TrajectoryResponse, currentTime: Int) {
        self.clearPreviousTrajectories()
        
        // Sort trajectories by id
        let trajectoryList = trajectories.values.sorted {
            return $0.id < $1.id
        }
        
        for trajectory in trajectoryList {

            // Only two knots means no trajectory
            if trajectory.segments.count <= 2 {
                continue
            }
            
            let trajectoryColor = isConflicting(trajectory: trajectory, conflicts: trajectories.conflicts) ?  COLLISION_COLOR : NO_COLLISION_COLOR
            
            let heightLevel = getHeightLevel(trajectory: trajectory)
            
            // Add Trajectory
            let trajEntity = TrajectoryEntity(trajectory: trajectory, currentTime: currentTime, color: trajectoryColor, heightLevel: heightLevel)
            trajectoryAnchor.addChild(trajEntity)
        }
    }
    
    func getHeightLevel(trajectory: RobotTrajectory) -> Int {
        // Height level is determined by how many other trajectories the current trajectory intersects
        return recursiveIntersectingCheck(trajectory: trajectory, currentHeightLevel: 0)
    }
    
    func recursiveIntersectingCheck(trajectory: RobotTrajectory, currentHeightLevel: Int) -> Int {
        
        // If the list of trajectories at currentHeightLevel is empty simply add the trajectory in and return the height
        guard let currentHeightTrajectories = heightLevelMap[currentHeightLevel] else {
            heightLevelMap[currentHeightLevel] = [trajectory]
            return currentHeightLevel
        }
        
        // Iterate over all previously seen trajectories and if it overlaps go to the next level
        for seenTrajectory in currentHeightTrajectories {
            if isIntersecting(trajectory1: seenTrajectory, trajectory2: trajectory) {
                return recursiveIntersectingCheck(trajectory: trajectory, currentHeightLevel: currentHeightLevel + 1)
            }
        }
        
        heightLevelMap[currentHeightLevel]?.append(trajectory)
        return currentHeightLevel
    }
    
    func isIntersecting(trajectory1: RobotTrajectory, trajectory2: RobotTrajectory) -> Bool {
        
        for i in 0..<trajectory1.segments.count - 1 {
            let curKnotTraj1 = trajectory1.segments[i]
            let nextKnotTraj1 = trajectory1.segments[i + 1]
            
            let p1 = CGPoint(x: CGFloat(curKnotTraj1.x[0]), y: CGFloat(curKnotTraj1.x[1]))
            let q1 = CGPoint(x: CGFloat(nextKnotTraj1.x[0]), y: CGFloat(nextKnotTraj1.x[1]))
            
            for j in 0..<trajectory2.segments.count - 1 {
                let curKnotTraj2 = trajectory2.segments[j]
                let nextKnotTraj2 = trajectory2.segments[j + 1]
                
                let p2 = CGPoint(x: CGFloat(curKnotTraj2.x[0]), y: CGFloat(curKnotTraj2.x[1]))
                let q2 = CGPoint(x: CGFloat(nextKnotTraj2.x[0]), y: CGFloat(nextKnotTraj2.x[1]))
                
                if intersects(p1: p1, q1: q1, p2: p2, q2: q2) {
                    return true
                }
            }
        }
        
        return false
    }
    
    func intersects(p1: CGPoint, q1: CGPoint, p2: CGPoint, q2: CGPoint) -> Bool {
        
        // Check the orientation between each line and the start/end point of the other line
        // e.g. line p1q1 and start point p2
        let orientation1 = getOrientation(p: p1, q: q1, r: p2)
        let orientation2 = getOrientation(p: p1, q: q1, r: q2)
        let orientation3 = getOrientation(p: p2, q: q2, r: p1)
        let orientation4 = getOrientation(p: p2, q: q2, r: q1)
        
        // If both lines have a mismatch in orientation then the lines intersect
        if (orientation1 != orientation2) && (orientation3 != orientation4) {
            return true
        }
        
        // Special case occurs when the lines are colinear - need to check if third point lies on line
        
        // p1q1 and p2 are colinear
        if orientation1 == 0 && onSegment(p: p1, q: p2, r: q1) {
            return true
        }
        
        // p1q1 and q2 are colinear
        if orientation2 == 0 && onSegment(p: p1, q: q2, r: q1) {
            return true
        }
        
        // p2q2 and p1 are colinear
        if orientation3 == 0 && onSegment(p: p2, q: p1, r: q2) {
            return true
        }
        
        // p2q2 and q1 are colinear
        if orientation4 == 0 && onSegment(p: p2, q: q1, r: q2) {
            return true
        }
        
        return false
        
    }
    
    func getOrientation(p: CGPoint, q: CGPoint, r: CGPoint) -> Float{
        let det = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y)
        
        if det > 0 {
            // Points turn clockwise
            return 1
        }
        else if det > 0 {
            // Points turn counter-clockwise
            return -1
        }
        else {
            // Points colinear
            return 0
        }
    }
    
    func onSegment(p: CGPoint, q: CGPoint, r: CGPoint) -> Bool {
        if q.x <= max(p.x, r.x) && q.x >= min(p.x, r.x) && q.y <= max(p.y, r.y) && q.y >= min(p.y, r.y) {
            return true
        }
        
        return false
    }
    
    func isConflicting(trajectory: RobotTrajectory, conflicts: [[Int]]) -> Bool {
        for pair in conflicts {
            
            if pair.contains(trajectory.id) {
                return true
            }
        }
        
        return false
    }
    
    func clearPreviousTrajectories() {
        self.heightLevelMap = [:]
        trajectoryAnchor.children.removeAll()
    }
    
    deinit {
        downloadTimer.invalidate()
    }
}
