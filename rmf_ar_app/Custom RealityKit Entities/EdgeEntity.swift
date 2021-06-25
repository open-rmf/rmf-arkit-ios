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
    
    required init() {
        super.init()
        
        self.components[ModelComponent] = ModelComponent(mesh: .generatePlane(width: 2, depth: 0.1), materials: [SimpleMaterial(color: .black, isMetallic: false)])
        
        self.components[Transform] = Transform(pitch: .pi/2, yaw: 0, roll: 0)
    }
    
    required init(color: UIColor, pathLength: Float, pathWidth: Float) {
        super.init()
        
        self.components[ModelComponent] = ModelComponent(mesh: .generatePlane(width: pathLength, height: pathWidth), materials: [UnlitMaterial(color: .green)])
        
        self.components[Transform] = Transform(pitch: .pi/2, yaw: 0, roll: 0)
    }
    
    func setPose(position: SIMD3<Float>, rotation: simd_quatf) {
        self.components[Transform] = Transform(scale: [1,1,1], rotation: rotation, translation: position)
    }
}
