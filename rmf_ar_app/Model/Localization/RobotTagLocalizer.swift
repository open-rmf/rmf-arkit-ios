//
//  RobotTagLocalizer.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 22/6/21.
//

import Foundation
import os
import Combine
import ARKit
import RealityKit

class RobotTagLocalizer {
    
    var arView: ARView
    
    private var lastUpdateTime: Date
    
    private var isLocalized = false
    private var unalignedCounter = 0
    
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "TrajectoryManager")
    
    init(arView: ARView) {
        self.arView = arView
        
        lastUpdateTime = Date.distantPast
        
        NotificationCenter.default.addObserver(self, selector: #selector(run), name: Notification.Name("robotStatesUpdated"), object: nil)
    }
    
    @objc func run(_ notification: Notification) {
        
        // Check to make sure we only localize at UPDATE_RATE or slower
        let currentTime = Date()
        
        if currentTime.timeIntervalSince(lastUpdateTime) < (1 / ARConstants.Localization.UPDATE_RATE) {
            logger.debug("Skipping received robot states. Received message too soon after previous")
            return
        } else {
            lastUpdateTime = currentTime
        }
        
        guard let robotsDict = notification.userInfo as? [String: TrackedRobot] else {
            logger.error("Notification \(notification.name.rawValue)'s user info did not match expected value")
            return
        }
        
        // Only localize if tracking state is good
        switch arView.session.currentFrame?.camera.trackingState {
        case .normal:
            // Only consider robots that are tracked and not moving
            let trackedRobots = robotsDict.filter { $0.value.isTracked && !$0.value.robotState.mode.contains("Moving") }
            
            // Check if we are currently tracking any robots
            if trackedRobots.count == 0 {
                logger.info("No tracked robots")
                return
            }
            
            // Sort robots according to most recently seen (i.e. last seen should be as big as possible)
            let sortedRobots = trackedRobots.values.sorted(by: {first, second in
                return first.lastSeen > second.lastSeen
            })
            
            // Retrieve the most recently seen robot's state and its corresponding anchor
            let robot = sortedRobots.first!.robotState
            guard let anchor = arView.session.currentFrame?.anchors.first(where: {$0.name == robot.robotName}) else {
                logger.error("Could not retrieve anchor associated with robot: \(robot.robotName)")
                return
            }
            
            // Check whether to fully localize or just relocalize (steps are slightly different)
            if !isLocalized {
                runLocalization(robot: robot, anchor: anchor)
                isLocalized = true
            } else {
                runRelocalization(robot: robot, anchor: anchor)
            }
            
        default:
            logger.info("Tracking state not good enough for localization - Aborting")
            return
        }
    }
    
    // Sets the ARView world origin to be the world origin as used within the RMF system
    func runLocalization(robot: RobotState, anchor: ARAnchor) {
        logger.info("Beginning localization")
        
        // Get vector pointing into marker and remove any vertical motion from it
        let yVec = -simd_float3(anchor.transform[1,0], 0, anchor.transform[1,2])

        // Calculate the rotations required to align the ARKit frame and RMF frame
        let rotationToAlignXYPlane = pointXAxisAt(at: yVec)
        let rotationToAlignXAxis = Transform(pitch: 0, yaw: Float(robot.locationYaw), roll: 0).matrix.transpose
        let alignmentRotation = rotationToAlignXAxis * rotationToAlignXYPlane
        
        // Rotate the anchor to align its frame and then calculate the required translation so
        // that it is in the same position as the robot
        let rotatedAnchor = alignmentRotation.transpose * anchor.transform[3]
        let dx = rotatedAnchor[0] - Float(robot.locationX)
        let dy = rotatedAnchor[1] - Float(robot.locationY)
        let dz = rotatedAnchor[2] - ARConstants.Localization.MARKER_HEIGHT

        // Need to apply the rotation to the translation vector
        let alignmentTranslation = alignmentRotation * simd_float4([dx, dy, dz, 1])

        var alignmentTransform = alignmentRotation
        alignmentTransform[3] = alignmentTranslation
        
        arView.session.setWorldOrigin(relativeTransform: alignmentTransform)
        
        // Send a notification that the world origin was updated
        let localizationData = ["levelName": robot.levelName]
        NotificationCenter.default.post(name: Notification.Name("setWorldOrigin"), object: nil, userInfo: localizationData)
    }
    
    func runRelocalization(robot: RobotState, anchor: ARAnchor) {

        // Check that the robot state and anchor agree with positioning
        let dx = anchor.transform[3].x - Float(robot.locationX)
        let dy = anchor.transform[3].y - Float(robot.locationY)
        let positionError = sqrt(dx * dx + dy * dy)
        
        // The anchors y-axis points out of the marker so we invert it and find the angle it creates to get the yaw
        let anchorYaw = atan2(-anchor.transform[1,1], -anchor.transform[1,0])
        
        let rotationError = anchorYaw - Float(robot.locationYaw)
        
        logger.debug("Relocalization: Position error = \(positionError) | Rotation error = \(rotationError)")
        
        if abs(rotationError) > (ARConstants.Localization.ANGULAR_THRESHOLD * Float.pi / 180) || positionError > ARConstants.Localization.DISTANCE_THRESHOLD {
            logger.debug("Positional/Rotation errors over threshold. Count: \(self.unalignedCounter) out of \(ARConstants.Localization.RELOCALIZATION_THRESHOLD)")
            unalignedCounter += 1
        } else {
            unalignedCounter = 0
            return
        }
        
        if unalignedCounter >= ARConstants.Localization.RELOCALIZATION_THRESHOLD {
            logger.info("Beginning relocalization")
            
            let alignmentRotation = Transform(pitch: 0, yaw: 0, roll: Float(rotationError)).matrix
            
            let rotatedAnchor = alignmentRotation.transpose * anchor.transform[3]
            let dx = rotatedAnchor[0] - Float(robot.locationX)
            let dy = rotatedAnchor[1] - Float(robot.locationY)
            let dz = rotatedAnchor[2] - ARConstants.Localization.MARKER_HEIGHT
            
            let alignmentTranslation = alignmentRotation * simd_float4([dx, dy, dz, 1])

            var alignmentTransform = alignmentRotation
            alignmentTransform[3] = alignmentTranslation
            
            var transformation = alignmentRotation
            transformation[3] = alignmentTranslation
            
            arView.session.setWorldOrigin(relativeTransform: transformation)
            unalignedCounter = 0
            return
        }
    }
    
    private func pointXAxisAt(at: SIMD3<Float>) -> float4x4 {
        
        let upVector = SIMD3<Float>([0,1,0])
        
        var x = at
        
        // If length of x is 0 just default to [1,0,0]
        if length_squared(x) == 0 {
            x[0] = 1
        }
        
        x = normalize(x)
        
        var y = cross(upVector, x)
        
        if length_squared(y) == 0 {
            // Up vector and x vector are parallel
            
            // Perturb the x vector and recalculate cross product
            x.z += 0.0001
            
            x = normalize(x)
            y = cross(upVector, x)
        }
        
        y = normalize(y)
        
        let z = cross(x, y)
        
        var transformMatrix = float4x4(1)
        transformMatrix[0,0] = x[0]
        transformMatrix[0,1] = x[1]
        transformMatrix[0,2] = x[2]
        
        transformMatrix[1,0] = y[0]
        transformMatrix[1,1] = y[1]
        transformMatrix[1,2] = y[2]
        
        transformMatrix[2,0] = z[0]
        transformMatrix[2,1] = z[1]
        transformMatrix[2,2] = z[2]
        
        return transformMatrix
    }

}
