//
//  VertexModel.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 23/6/21.
//

import Foundation
import RealityKit
import ARKit

class VertexEntity: Entity, HasModel {
    
    var hasText = false
    
    // Default constructor is required
    required init() {
        super.init()
    }
    
    required init(vertex: Vertex, index: Int) {
        super.init()
        
        let nodeMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let nodeMesh = MeshResource.generateBox(size: ARConstants.NavGraph.VERTEX_SIZE)
        
        let nodeTranslation = simd_float3([vertex.x, vertex.y, ARConstants.NavGraph.Z_OFFSET])
        
        self.components[ModelComponent] = ModelComponent(mesh: nodeMesh, materials: [nodeMaterial])
        self.components[Transform] = Transform(scale: [1,1,1], rotation: simd_quatf(), translation: nodeTranslation)
        
        self.name = "vertex\(index)"
            
        // If the vertex has a name add the text ModelEntity as a child
        if vertex.name != "" {
            self.hasText = true
            
            let textMaterial = UnlitMaterial(color: .white)
            let textMesh = MeshResource.generateText(vertex.name, extrusionDepth: 0.01, font: .init(name: "Helvetica", size: CGFloat(ARConstants.NavGraph.TEXT_FONT_SIZE))!)
            let textTranslation = simd_float3([0, 0, ARConstants.NavGraph.TEXT_Z_OFFSET]) // Translation is relative to parent
            
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])	
            textEntity.transform = Transform(scale: [1,1,1], rotation: simd_quatf(), translation: textTranslation)
            textEntity.name = "\(vertex.name)Text"
            self.addChild(textEntity)
        }
    }
    
    func faceTextAt(at: simd_float3) {
        guard let textEntity = self.children.first else {return}
        
        // Calculate the positions of the x,y,z axis so that the text faces "at"
        let up = simd_float3([0,0,1])
        var z = textEntity.position(relativeTo: nil) - at
        
        if length_squared(z) == 0 {
            z.z = 1
        }
        
        z = normalize(z)
        
        var x = cross(up, z)
        
        if length_squared(x) == 0 {
            z.x += 0.0001
            
            
            z = normalize(z)
            x = cross(up, z)
        }
        
        x = normalize(x)
        let y = cross(z, x)
        
        // Invert the x and z axis so that the text is oriented in a readable direction
        let rotMat = float3x3([-x, y, -z])
        
        textEntity.setOrientation(simd_quatf(rotMat), relativeTo: nil)
    }
}


