//
//  TaskManager.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 6/7/21.
//

import Foundation
import os

class TaskManager {
    
    // MARK: - Instance Variables
    var networkManager: NetworkManager
    var taskList: [TaskSummary] = []
    
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "TaskManager")
    
    // MARK: - Public Methods
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    func downloadTaskList() {
        networkManager.sendGetRequest(urlString: URLConstants.TASK_LIST, responseBodyType: [TaskSummary].self) {
            responseResult in
            
            switch responseResult {
            case .success(let data):
                self.taskList = data
            case .failure(let e):
                self.logger.error("\(e.localizedDescription)")
                return
            }
            
        }
    }
    
    func createDeliveryTask(startTime: Int, priority: Int, pickupPlaceName: String, pickupDispenser: String, dropoffPlaceName: String, dropoffIngestor: String, completionHandler: @escaping (Bool, String, String) -> Void) {
        let taskRequest = CreateDeliveryTaskRequest(startTime: startTime, priority: priority, pickupPlaceName: pickupPlaceName, pickupDispenser: pickupDispenser, dropoffPlaceName: dropoffPlaceName, dropoffIngestor: dropoffIngestor)
        
        sendTask(request: taskRequest, completionHandler: completionHandler)
    }
    
    func createLoopTask(startTime: Int, priority: Int, startName: String, finishName: String, numLoops: Int, completionHandler: @escaping (Bool, String, String) -> Void) {
        let taskRequest = CreateLoopTaskRequest(startTime: startTime, priority: priority, numLoops: numLoops, startName: startName, finishName: finishName)
        
        sendTask(request: taskRequest, completionHandler: completionHandler)
    }
    
    func createCleanTask(startTime: Int, priority: Int, startWaypoint: String, completionHandler: @escaping (Bool, String, String) -> Void) {
        let taskRequest = CreateCleanTaskRequest(startTime: startTime, priority: priority, startWaypoint: startWaypoint)
        
        sendTask(request: taskRequest, completionHandler: completionHandler)
        
    }
    
    func cancelTask(taskId: String, completionHandler: @escaping (Result<CancelTaskResponse, NetworkManagerError>) -> Void) {
        let cancelTaskRequest = CancelTaskRequest(taskId: taskId)
        
        networkManager.sendPostRequest(urlString: URLConstants.CANCEL_TASK, requestBody: cancelTaskRequest, responseBodyType: CancelTaskResponse.self, completionHandler: completionHandler)
    }
    
    // MARK: - Private Methods
    private func sendTask<T: CreateTaskRequest>(request: T, completionHandler: @escaping (Bool, String, String) -> Void) {
        networkManager.sendPostRequest(urlString: URLConstants.SUBMIT_TASK, requestBody: request, responseBodyType: CreateTaskResponse.self) {
            responseResult in
            
            var responseBody: CreateTaskResponse
            
            // Check network was succesful
            switch responseResult {
            case .success(let data):
                responseBody = data
            case .failure(let e):
                self.logger.error("\(e.localizedDescription)")
                completionHandler(false, "", "\(e.localizedDescription)")
                return
            }
            
            if responseBody.errorMsg == "" {
                completionHandler(true, responseBody.taskId, "")
            } else {
                completionHandler(false, responseBody.taskId, responseBody.errorMsg)
            }
        }
    }
    
}
