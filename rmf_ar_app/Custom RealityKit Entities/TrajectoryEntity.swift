//
//  TrajectoryEntity.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 19/7/21.
//

import Foundation
import RealityKit
import UIKit

class TrajectoryEntity: Entity {
    
    static let HIGHLIGHTED_COLLISION_MATERIAL = SimpleMaterial(color: .red, roughness: 1.0, isMetallic: false)
    static let HIGHLIGHTED_NONCOLLISION_MATERIAL = SimpleMaterial(color: .green, roughness: 1.0, isMetallic: false)
    static let NONHIGHLIGHTED_COLLISION_MATERIAL = SimpleMaterial(color: .red.withAlphaComponent(0.6), roughness: 1.0, isMetallic: false)
    static let NONHIGHLIGHTED_NONCOLLISION_MATERIAL = SimpleMaterial(color: .green.withAlphaComponent(0.6), roughness: 1.0, isMetallic: false)
    
    
    var segments: [ModelEntity] = []
    private var isCollision = false
    private var isHighlighted = false
    private var heightLevel = 1
    
    required init() {
        super.init()
    }
    
    required init(trajectory: RobotTrajectory, isCollision: Bool, isHighlighted: Bool, heightLevel: Int) {
        super.init()
        
        self.isCollision = isCollision
        self.isHighlighted = isHighlighted
        
        self.name = "trajectory\(trajectory.id)"
        
        for i in 0..<trajectory.segments.count - 1 {
            let startKnot = trajectory.segments[i]
            let endKnot = trajectory.segments[i + 1]
            
            addFullSegment(startKnot: startKnot, endKnot: endKnot)
        }
    }
    
    private func addFullSegment(startKnot: SplineKnot, endKnot: SplineKnot) {
        
        let directionVec = simd_float2(endKnot.x[0], endKnot.x[1]) - simd_float2(startKnot.x[0], startKnot.x[1])
        
        let edgeLength = length(directionVec)
        let midpoint = simd_float2(startKnot.x[0], startKnot.x[1]) + directionVec/2
        
        let theta = atan2(directionVec.y, directionVec.x)
        let edgeRotation = simd_quatf(angle: theta, axis: [0,0,1])
        
        var material: SimpleMaterial
        
        if isHighlighted {
            material = isCollision ? TrajectoryEntity.HIGHLIGHTED_COLLISION_MATERIAL : TrajectoryEntity.HIGHLIGHTED_NONCOLLISION_MATERIAL
        } else {
            material = isCollision ? TrajectoryEntity.NONHIGHLIGHTED_COLLISION_MATERIAL : TrajectoryEntity.NONHIGHLIGHTED_NONCOLLISION_MATERIAL
        }
        
        let pathModel = ModelEntity(mesh: .generateBox(width: edgeLength, height: ARConstants.Trajectory.PATH_SIZE, depth: ARConstants.Trajectory.PATH_SIZE), materials: [material])
        
        let z = ARConstants.Trajectory.Z_OFFSET + Float(heightLevel) * ARConstants.Trajectory.HEIGHT_LEVEL_STEP
        
        pathModel.components[Transform] = Transform(scale: [1,1,1], rotation: edgeRotation, translation: [midpoint.x, midpoint.y, z])
        
        self.addChild(pathModel, preservingWorldTransform: false)
    }
}
