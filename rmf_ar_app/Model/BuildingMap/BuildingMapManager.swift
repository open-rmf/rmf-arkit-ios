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
        self.networkManager.sendGetRequest(urlString: BUILDING_MAP_URL, responseBodyType: BuildingMap.self) {
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
        
        guard self.buildingMap != nil else {
            print("ERROR: No building map available - no visualization possible")
            return
        }
        guard let currentLevel = self.buildingMap?.levels.first(where: {$0.name == levelName}) else {
            print("ERROR: No level with name \(levelName) found")
            return
        }
        
        

        // Any drawing must be done on the main thread
        DispatchQueue.main.async {
            // Create an anchor for the building map
            let buildingMapAnchor = AnchorEntity(world: [0,0,0])
            buildingMapAnchor.name = "buildingMap"
            
            self.addNavGraphs(fromLevel: currentLevel, toEntity: buildingMapAnchor)
            self.addWallGraph(fromLevel: currentLevel, toEntity: buildingMapAnchor)
            
            // Finally add the building map to the scene
            self.arView.scene.addAnchor(buildingMapAnchor)
        }
    }

    func addNavGraphs(fromLevel level: Level, toEntity parentEntity: Entity){
        
        for navGraph in level.navGraphs {
            // Name the nav graph
            let navGraphEntity = Entity()
            navGraphEntity.name = level.name + "NavGraph" + navGraph.name
            
            addNavVertices(fromNavGraph: navGraph, toEntity: navGraphEntity)
            addNavEdges(fromNavGraph: navGraph, toEntity: navGraphEntity)
            
            parentEntity.addChild(navGraphEntity)
        }
        
    }
    
    func addNavVertices(fromNavGraph navGraph: NavGraph, toEntity parentEntity: Entity) {
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
    
    func addNavEdges(fromNavGraph navGraph: NavGraph, toEntity parentEntity: Entity) {
        
        // TODO: Visualize directed/undirected edges
        
        for edge in navGraph.edges {
            let v1 = navGraph.vertices[edge.v1Idx]
            let v2 = navGraph.vertices[edge.v2Idx]
                       
            let edge = EdgeEntity(vertex1: v1, vertex2: v2, color: .cyan)
            
            parentEntity.addChild(edge)
        }
    }
    
    func addWallGraph(fromLevel level: Level, toEntity parentEntity: Entity) {
        
        return
        
        let wallGraphEntity = Entity()
        wallGraphEntity.name = "wall_graph"
        
        for edge in level.wallGraph.edges {
            let v1 = level.wallGraph.vertices[edge.v1Idx]
            let v2 = level.wallGraph.vertices[edge.v2Idx]
                       
            let wall = WallEntity(vertex1: v1, vertex2: v2)
            
            wallGraphEntity.addChild(wall)
        }
        
        parentEntity.addChild(wallGraphEntity)
    }
}
