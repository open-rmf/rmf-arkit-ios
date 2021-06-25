//
//  RobotTagLocalizer.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 22/6/21.
//

import Foundation
import Combine
import RealityKit

class RobotTagLocalizer {
    
    var arView: ARView
    
    private var isLocalized = false
    
    init(arView: ARView) {
        self.arView = arView
        
        NotificationCenter.default.addObserver(self, selector: #selector(runLocalization), name: Notification.Name("robotStatesUpdated"), object: nil)
    }
    
    // Sets the ARView world origin to be the world origin as used within the RMF system
    @objc func runLocalization(_ notification: Notification) -> Void {
        
        // Only run if we have not localized
        if isLocalized {
            return
        }
        
        guard let robotStates = notification.userInfo as? [String: RobotState] else {
            print("ERROR: Notification \(notification.name)'s user info did not match expected value")
            return
        }
        
        // Retrieve the robot state and its corresponding anchor
        guard let robot = robotStates.first?.value else {return} // TODO: Select best robot state (use most recent?)
        guard let anchor = arView.session.currentFrame?.anchors.first(where: {$0.name == robot.robotName}) else {return}
        
        
        // Get vector pointing into marker and remove any vertical motion from it
        var yVec = -simd_float3(anchor.transform[1,0], 0, anchor.transform[1,2])
        yVec[1] = 0

        let rotationToAlignXYPlane = pointXAxisAt(at: yVec)
        let rotationToAlignXAxis = Transform(pitch: 0, yaw: Float(robot.locationYaw), roll: 0).matrix.transpose
        let finalRotation = rotationToAlignXAxis * rotationToAlignXYPlane
        
        let rotatedAnchor = finalRotation.transpose * anchor.transform[3]
        let dx = rotatedAnchor[0] - Float(robot.locationX)
        let dy = rotatedAnchor[1] - Float(robot.locationY)
        let dz = rotatedAnchor[2] - 1

        // Need to apply the rotation to the translation vector
        let translation = finalRotation * simd_float4([dx, dy, dz, 1])

        var finalTransform = finalRotation
        finalTransform[3] = translation
        
        arView.session.setWorldOrigin(relativeTransform: finalTransform)
        isLocalized = true
        
        // Send a notification that the world origin was updated
        let localizationData = ["levelName": robot.levelName]
        NotificationCenter.default.post(name: Notification.Name("setWorldOrigin"), object: nil, userInfo: localizationData)
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
