//
//  BuildingMapManager.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 21/6/21.
//

import Foundation
import ARKit
import RealityKit
import Combine

class BuildingMapManager {
    
    let BUILDING_MAP_URL = "http://192.168.1.201:8080/building_map"
    
    var arView: ARView
    
    var buildingMap: BuildingMap?
    
    var networkManager: NetworkManager
    
    var cancellables: Set<AnyCancellable> = []
    
    init(arView: ARView, networkManager: NetworkManager) {
        self.arView = arView
        self.networkManager = networkManager
        
        self.downloadBuildingMap()
        
        NotificationCenter.default.addObserver(self, selector: #selector(visualizeMap), name: Notification.Name("setWorldOrigin"), object: nil)
    }
    
    func downloadBuildingMap() {
        self.networkManager.getJSONfromURLasync(urlString: BUILDING_MAP_URL, modelType: BuildingMap.self) {
            model in
            
            self.buildingMap = model
        }
    }
    
    @objc func visualizeMap(_ notification: Notification) {        
        guard let localizationData = notification.userInfo as? [String: String] else {
            print("ERROR: Notification \(notification.name)'s user info did not match expected value")
            return
        }
        
        guard let levelName = localizationData["levelName"] else {
            print("ERROR: No level name in dict: \(localizationData)")
            return
        }
        
        // Create an anchor for the building map
        let buildingMapAnchor = AnchorEntity(world: [0,0,0])
        buildingMapAnchor.name = "buildingMap"
        
        let navGraphEntities = createNavGraphEntities(levelName: levelName)
        
        for navGraphEntity in navGraphEntities {
            buildingMapAnchor.addChild(navGraphEntity)
        }
        
        // Finally add the building map to the scene
        arView.scene.addAnchor(buildingMapAnchor)
    }
    
    func createNavGraphEntities(levelName: String) -> [Entity] {
        guard self.buildingMap != nil else {
            print("ERROR: No building map available - no visualization possible")
            return []
        }
        guard let level = self.buildingMap?.levels.first(where: {$0.name == levelName}) else {
            print("ERROR: No level with name \(levelName) found")
            return []
        }
        
        var navGraphEntities: [Entity] = []
        
        for navGraph in level.navGraphs {
            // Name the nav graph
            let navGraphEntity = Entity()
            navGraphEntity.name = levelName + "NavGraph" + navGraph.name
            
            
            addVertices(navGraph: navGraph, parentEntity: navGraphEntity)
            addEdges(navGraph: navGraph, parentEntity: navGraphEntity)
            
            navGraphEntities.append(navGraphEntity)
        }
        
        return navGraphEntities
        
    }
    
    func addVertices(navGraph: NavGraph, parentEntity: Entity) {
        var verticesWithText: [VertexEntity] = []
        
        for (idx, vertex) in navGraph.vertices.enumerated() {
            let vertexEntity = VertexEntity(vertex: vertex, index: idx)
            
            if vertexEntity.hasText {
                verticesWithText.append(vertexEntity)
            }
            
            parentEntity.addChild(vertexEntity)
        }
        
        // Create a subscriber so that the text always faces the camera
        arView.scene.subscribe(to: SceneEvents.Update.self) { [self] _ in
            for entity in verticesWithText {
                entity.faceTextAt(at: arView.cameraTransform.translation)
            }
        }.store(in: &cancellables)
    }
    
    func addEdges(navGraph: NavGraph, parentEntity: Entity) {
               
        for edge in navGraph.edges {
            let v1 = navGraph.vertices[edge.v1Idx]
            let v2 = navGraph.vertices[edge.v2Idx]
            
            let directionVec = simd_float2(Float(v2.x), Float(v2.y)) - simd_float2(Float(v1.x), Float(v1.y))
            
            let edgeLength = length(directionVec)
            let midpoint = simd_float2(Float(v1.x), Float(v1.y)) + directionVec/2
            let zAxisRotation = atan2(directionVec.y, directionVec.x)
            let pathRotation = simd_quatf(angle: zAxisRotation, axis: [0,0,1])
            
            let pathEntity = EdgeEntity(color: .green, pathLength: edgeLength, pathWidth: 0.1)
            pathEntity.setPose(position: [midpoint.x, midpoint.y, 0.5], rotation: pathRotation)
            
            parentEntity.addChild(pathEntity)
        }
    }
}
