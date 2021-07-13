//
//  DashboardConfig.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 9/7/21.
//

import Foundation

struct DashboardConfig: Decodable {
    let worldName: String
    let validTask: [String]
    let task: ValidTasks
    
    struct ValidTasks: Decodable {
        let Delivery: ValidDeliveryTasks
        let Loop: ValidLoopTasks
        let Clean: ValidCleanTasks
    }
}

struct ValidDeliveryTasks: Decodable {
    let option: [String: DeliveryTaskDetails]?
    
    struct DeliveryTaskDetails: Decodable {
        let pickupPlaceName: String
        let pickupDispenser: String
        let dropoffPlaceName: String
        let dropoffIngestor: String
    }
}

struct ValidLoopTasks: Decodable {
    let places: [String]?
}

struct ValidCleanTasks: Decodable {
    let option: [String]?
}
