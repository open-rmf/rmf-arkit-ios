//
//  RobotStatusData.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 17/6/21.
//

import Foundation

struct TrackedRobot {
    var robotState: RobotState
    var isTracked: Bool
    var lastSeen = Date.distantPast
}

struct RobotState: Decodable {
    
    let robotName: String
    let fleetName: String
    let batteryPercent: Double
    let locationX: Double
    let locationY: Double
    let locationYaw: Double
    let levelName: String
    let mode: String
    let assignments: [String]
    
}


