//
//  BuilldingMap.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 18/6/21.
//

import Foundation

struct BuildingMap: Codable {
    let name: String
    let levels: [Level]
}

struct Level: Codable {
    let name: String
    let elevation: Double
    let navGraphs: [NavGraph]
    let wallGraph: NavGraph
}

struct NavGraph: Codable {
    let name: String
    let vertices: [Vertex]
    let edges: [Edge]
    
}

struct Vertex: Codable {
    let x: Double
    let y: Double
    let name: String
    let params: [Param?]
}

struct Edge: Codable {
    let v1Idx: Int
    let v2Idx: Int
    let edgeType: Int
    let params: [Param?]
}

struct Param: Codable {
    let name: String
    let type: String
    let value: String
}

