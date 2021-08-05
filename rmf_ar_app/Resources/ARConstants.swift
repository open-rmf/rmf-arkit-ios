//
//  ARVisualsConstants.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 28/7/21.
//

import Foundation

struct ARConstants {
    struct NavGraph {
        static let Z_OFFSET: Float = 0
        static let TEXT_Z_OFFSET: Float = 0.8
        static let EDGE_WIDTH: Float = 0.1
        static let VERTEX_SIZE: Float = 0.1
        static let TEXT_FONT_SIZE: Float = 0.1
    }
    
    struct RobotStates {
        static let DOWNLOAD_RATE: Double = 10
        static let Z_OFFSET: Float = 0.3
        static let TRACKING_TIMEOUT: Double = 5
    }
    
    struct Trajectory {
        static let DOWNLOAD_RATE: Double = 10
        
        static let Z_OFFSET: Float = 0.3
        static let PATH_SIZE: Float = 0.05
        static let HEIGHT_LEVEL_STEP: Float = 0.1
    }
    
    struct Localization {
        static let UPDATE_RATE: Double = 1 // Hz

        static let RELOCALIZATION_THRESHOLD: Int = 5
        static let DISTANCE_THRESHOLD: Float = 0.2
        static let ANGULAR_THRESHOLD: Float = 10.0

        static let MARKER_HEIGHT: Float = 0.3
    }
}
