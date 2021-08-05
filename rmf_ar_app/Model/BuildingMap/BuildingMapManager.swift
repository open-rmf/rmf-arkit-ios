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
import os

class BuildingMapManager {
    
    var arView: ARView
    var buildingMapAnchor: AnchorEntity
    
    var buildingMap: BuildingMap?
    var isVisualized: Bool = false
    
    var networkManager: NetworkManager
    
    var cancellables: Set<AnyCancellable> = []
    
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "BuildingMapManager")
    
    init(arView: ARView, networkManager: NetworkManager) {
        self.networkManager = networkManager
        
        self.arView = arView
        buildingMapAnchor = AnchorEntity(world: [0,0,0])
        arView.scene.addAnchor(buildingMapAnchor)
        
        self.downloadBuildingMap()
        
        NotificationCenter.default.addObserver(self, selector: #selector(visualizeMap), name: Notification.Name("setWorldOrigin"), object: nil)
        
        Settings.shared.$isWallsVisible.sink {
            [weak self] isVisible in
            self?.changeWallVisibility(isVisible: isVisible)
        }.store(in: &cancellables)
    }
    
    func downloadBuildingMap() {
        self.networkManager.sendGetRequest(urlString: URLConstants.BUILDING_MAP, responseBodyType: BuildingMap.self) {
            responseResult in
            
            // Check network was succesful
            switch responseResult {
            case .success(let buildingMap):
                self.buildingMap = buildingMap
            case .failure(let e):
                self.logger.error("\(e.localizedDescription)")
                
                // Retry download in 2 seconds if failed
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(2)) {
                    [weak self] in
                    
                    guard let self = self else { return }
                    
                    self.downloadBuildingMap()
                }
            }
        }
    }
    
    @objc func visualizeMap(_ notification: Notification) {
        
        if isVisualized {
            logger.debug("Map already visualized. Skipping")
            return
        }
        
        guard let localizationData = notification.userInfo as? [String: String] else {
            logger.error("Notification \(notification.name.rawValue)'s user info did not match expected value")
            return
        }
        
        guard let levelName = localizationData["levelName"] else {
            logger.error("No level name in dict: \(localizationData)")
            return
        }
        
        guard self.buildingMap != nil else {
            logger.error("No building map available - no visualization possible")
            return
        }
        
        guard let currentLevel = self.buildingMap?.levels.first(where: {$0.name == levelName}) else {
            logger.error("No level with name \(levelName) found")
            return
        }
        
        // Any drawing must be done on the main thread
        DispatchQueue.main.async {
            [weak self] in
            
            guard let self = self else { return }
            
            self.addNavGraphs(fromLevel: currentLevel)
            self.addWallGraph(fromLevel: currentLevel)
        }
        
        isVisualized = true
    }

    func addNavGraphs(fromLevel level: Level){
        
        for navGraph in level.navGraphs {
            // Name the nav graph
            let navGraphEntity = Entity()
            navGraphEntity.name = level.name + "NavGraph" + navGraph.name
            
            addNavVertices(fromNavGraph: navGraph, toEntity: navGraphEntity)
            addNavEdges(fromNavGraph: navGraph, toEntity: navGraphEntity)
            
            buildingMapAnchor.addChild(navGraphEntity)
        }
        
    }
    
    func addNavVertices(fromNavGraph navGraph: NavGraph, toEntity parentEntity: Entity) {
        var verticesWithText: [VertexEntity] = []
        
        for (idx, vertex) in navGraph.vertices.enumerated() {
            let vertexEntity = VertexEntity(vertex: vertex, index: idx)
            
            // Keep track of vertices with text
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
                       
            let edge = EdgeEntity(vertex1: v1, vertex2: v2)
            
            parentEntity.addChild(edge)
        }
    }
    
    func addWallGraph(fromLevel level: Level) {
        
        let wallGraphEntity = Entity()
        wallGraphEntity.name = "wall_graph"
        
        for edge in level.wallGraph.edges {
            let v1 = level.wallGraph.vertices[edge.v1Idx]
            let v2 = level.wallGraph.vertices[edge.v2Idx]
                       
            let wall = WallEntity(vertex1: v1, vertex2: v2)
            
            wallGraphEntity.addChild(wall)
        }
        
        wallGraphEntity.isEnabled = Settings.shared.isWallsVisible
        
        buildingMapAnchor.addChild(wallGraphEntity)
    }
    
    func changeWallVisibility(isVisible: Bool) {
        guard let wallGraphEntity = arView.scene.findEntity(named: "wall_graph") else {
            logger.debug("No wall graph entity found. Cannot change visibility")
            return
        }
        
        wallGraphEntity.isEnabled = isVisible
    }
}
