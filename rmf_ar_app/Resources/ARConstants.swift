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
        static let TEXT_Z_OFFSET: Float = 0.5
        static let EDGE_WIDTH: Float = 0.1
        static let VERTEX_SIZE: Float = 0.1
        static let TEXT_FONT_SIZE: Float = 0.1
    }
    
    struct Trajectory {
        static let Z_OFFSET: Float = 0.8
        static let PATH_SIZE: Float = 0.05
        static let HEIGHT_LEVEL_STEP: Float = 0.1
    }
}
