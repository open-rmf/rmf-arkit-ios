//
//  Trajectory.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 13/7/21.
//

import Foundation

struct TrajectoryRequest: Encodable {
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

struct TrajectoryResponse: Decodable {
    let response: String
    let values: [TrajectoryValue]
    let conflicts: [[Int]]
    
    struct TrajectoryValue: Decodable {
        let robotName: String
        let fleetName: String
        let shape: String
        let dimensions: Float
        let id: Int
        let segments: [TrajectorySegment]
        
        struct TrajectorySegment: Decodable {
            let t: Int
            let v: [Float]
            let x: [Float]
        }
    }
}
