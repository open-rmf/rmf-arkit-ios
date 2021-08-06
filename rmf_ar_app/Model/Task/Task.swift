//
//  Task.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 6/7/21.
//

import Foundation

// MARK: - Task Data
struct TaskSummary : Codable {
    
    let taskType: String
    let startTime: Int
    let priority: Int
    
    let description: String?
    let done: Bool
    let endTime: Int
    let fleetName: String
    let progress: String
    let robotName: String
    let state: String
    let submitedStartTime: Int
    let taskId: String
    
}

// MARK: Task Creation
protocol CreateTaskRequest: Encodable {
    var taskType: String { get }
    var startTime: Int { get }
    var priority: Int { get }
}

struct CreateDeliveryTaskRequest: CreateTaskRequest {
    let taskType = "Delivery"
    let startTime: Int
    let priority: Int
    let description: DeliveryDescription
    
    struct DeliveryDescription: Encodable {
        let pickupPlaceName: String
        let pickupDispenser: String
        let dropoffPlaceName: String
        let dropoffIngestor: String
    }
    
    init(startTime: Int, priority: Int, pickupPlaceName: String, pickupDispenser: String, dropoffPlaceName: String, dropoffIngestor: String) {
        self.startTime = startTime
        self.priority = priority
        
        self.description = DeliveryDescription(pickupPlaceName: pickupPlaceName, pickupDispenser: pickupDispenser, dropoffPlaceName: dropoffPlaceName, dropoffIngestor: dropoffIngestor)
    }
}

struct CreateCleanTaskRequest: CreateTaskRequest {
    let taskType = "Clean"
    let startTime: Int
    let priority: Int
    let description: CleanDescription
    
    struct CleanDescription: Encodable {
        let startWaypoint: String
    }
    
    init(startTime: Int, priority: Int, startWaypoint: String) {
        self.startTime = startTime
        self.priority = priority
        
        self.description = CleanDescription(startWaypoint: startWaypoint)
    }
}

struct CreateLoopTaskRequest: CreateTaskRequest {
    let taskType = "Loop"
    let startTime: Int
    let priority: Int
    let description: LoopDescription
    
    struct LoopDescription: Encodable {
        let numLoops: Int
        let startName: String
        let finishName: String
    }
    
    init(startTime: Int, priority: Int, numLoops: Int, startName: String, finishName: String) {
        self.startTime = startTime
        self.priority = priority
        
        self.description = LoopDescription(numLoops: numLoops, startName: startName, finishName: finishName)
    }
}

struct CreateTaskResponse: Codable {
    let errorMsg: String
    let taskId: String
}

// MARK: Task Cancellation
struct CancelTaskRequest: Encodable {
    let taskId: String
}

struct CancelTaskResponse: Decodable {
    let success: Bool
}


