//
//  Path.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 23/6/21.
//

import Foundation
import RealityKit
import ARKit

class EdgeEntity: Entity, HasModel {
    
    let EDGE_WIDTH: Float = 0.1
    let Z_OFFSET: Float = 0.5
    
    // Default constructor is required
    required init() {
        super.init()
    }
    
    required init(vertex1: Vertex, vertex2: Vertex, color: UIColor) {
        super.init()
        
        let directionVec = simd_float2(vertex2.x, vertex2.y) - simd_float2(vertex1.x, vertex1.y)
        
        let edgeLength = length(directionVec)
        let midpoint = simd_float2(vertex1.x, vertex1.y) + directionVec/2
        let zAxisRotation = atan2(directionVec.y, directionVec.x)
        let edgeRotation = simd_quatf(angle: zAxisRotation, axis: [0,0,1])
        
        self.components[ModelComponent] = ModelComponent(mesh: .generatePlane(width: edgeLength, height: self.EDGE_WIDTH), materials: [UnlitMaterial(color: color)])
        
        self.components[Transform] = Transform(scale: [1,1,1], rotation: edgeRotation, translation: [midpoint.x, midpoint.y, self.Z_OFFSET])
    }
}
