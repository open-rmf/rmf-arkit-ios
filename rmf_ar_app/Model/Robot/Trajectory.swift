//
//  Trajectory.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 13/7/21.
//

import Foundation

// MARK: - Server Requests
protocol TrajectoryServerRequest: Encodable {
    associatedtype paramType
    
    var request: String { get }
    var param: paramType { get }
}

struct TrajectoryRequest: TrajectoryServerRequest {
    typealias paramType = TrajectoryParam
    
    let request = "trajectory"
    let param: TrajectoryParam
    
    struct TrajectoryParam: Encodable {
        let mapName: String
        let duration: Int
        let trim: Bool
    }
    
    init(mapName: String, duration: Int, trim: Bool) {
        self.param = TrajectoryParam(mapName: mapName, duration: duration, trim: trim)
    }
}

struct TimeRequest: TrajectoryServerRequest {
    typealias paramType = [String]
    
    let request = "time"
    let param: [String] = []
}


// MARK: - Server Responses
protocol TrajectoryServerResponse: Decodable {
    associatedtype valueType
    
    var response: String { get }
    var values: [valueType] { get }
    
}

struct TrajectoryResponse: TrajectoryServerResponse {
    typealias valueType = RobotTrajectory
    
    let response: String
    let values: [valueType]
    let conflicts: [[Int]]
    
    struct RobotTrajectory: Decodable {
        let robotName: String
        let fleetName: String
        let shape: String
        let dimensions: Float
        let id: Int
        let segments: [SplineKnot]
        
        struct SplineKnot: Decodable {
            let t: Int
            let v: [Float]
            let x: [Float]
        }
    }
}

struct TimeResponse: TrajectoryServerResponse {
    typealias valueType = Int
    
    let response: String
    let values: [valueType]
}
