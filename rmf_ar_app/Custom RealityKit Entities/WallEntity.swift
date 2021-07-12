//
//  WallEntity.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 25/6/21.
//

import Foundation
import RealityKit

class WallEntity: Entity, HasModel {
    
    let WALL_HEIGHT: Float = 3
    
    // Default constructor is required
    required init() {
        super.init()
    }
    
    required init(vertex1: Vertex, vertex2: Vertex) {
        super.init()
        
        let directionVec = simd_float2(Float(vertex2.x), Float(vertex2.y)) - simd_float2(Float(vertex1.x), Float(vertex1.y))
        
        let edgeLength = length(directionVec)
        let midpoint = simd_float2(Float(vertex1.x), Float(vertex1.y)) + directionVec/2
        let zAxisRotation = atan2(directionVec.y, directionVec.x)
        let edgeRotation = simd_quatf(angle: zAxisRotation, axis: [0,0,1])
        
        self.components[ModelComponent] = ModelComponent(mesh: .generatePlane(width: edgeLength, depth: WALL_HEIGHT), materials: [OcclusionMaterial()])
        
        self.components[Transform] = Transform(scale: [1,1,1], rotation: edgeRotation, translation: [midpoint.x, midpoint.y, 0.5])
    }
}
