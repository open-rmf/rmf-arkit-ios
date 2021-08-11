//
//  ARVisualsConstants.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 28/7/21.
//

import Foundation

struct ARConstants {
    struct NavGraph {
        static let Z_OFFSET: Float = 0 // metres
        static let TEXT_Z_OFFSET: Float = 0.8 // metres
        static let EDGE_WIDTH: Float = 0.1 // metres
        static let VERTEX_SIZE: Float = 0.1 // metres (edges of a cube)
        static let TEXT_FONT_SIZE: Float = 0.1
    }
    
    struct RobotStates {
        static let DOWNLOAD_RATE: Double = 10 // Hz
        
        static let Z_OFFSET: Float = 0.3 // metres
        static let TRACKING_TIMEOUT: Double = 5.0 // seconds before being considered untracked
    }
    
    struct Trajectory {
        static let DOWNLOAD_RATE: Double = 10 // Hz
        
        static let Z_OFFSET: Float = 0.3 // metres
        static let PATH_SIZE: Float = 0.05 // metres (width and height of a cuboid)
        static let HEIGHT_LEVEL_STEP: Float = 0.1 // metres (difference in height of overlapping trajectories)
    }
    
    struct Localization {
        static let UPDATE_RATE: Double = 1 // Hz

        static let RELOCALIZATION_THRESHOLD: Int = 5 // max error count before relocalization occurs
        static let DISTANCE_THRESHOLD: Float = 0.2 // metres
        static let ANGULAR_THRESHOLD: Float = 10.0 // radians

        static let MARKER_HEIGHT: Float = 0.3 // metres
    }
}
