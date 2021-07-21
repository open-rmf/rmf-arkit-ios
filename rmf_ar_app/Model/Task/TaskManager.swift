//
//  TaskManager.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 6/7/21.
//

import Foundation

class TaskManager {
    
    // MARK: - URL Constants
    let TASK_LIST_URL = "http://192.168.1.201:8080/task_list"
    let SUBMIT_TASK_URL = "http://192.168.1.201:8080/submit_task"
    let CANCEL_TASK_URL = "http://192.168.1.201:8080/cancel_task"
    
    // MARK: - Instance Variables
    var networkManager: NetworkManager
    var taskList: [TaskSummary] = []
    
    
    // MARK: - Public Methods
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    func downloadTaskList() {
        networkManager.sendGetRequest(urlString: TASK_LIST_URL, responseBodyType: [TaskSummary].self) {
            model in
            
            self.taskList = model
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
    
    func cancelTask(taskId: String, completionHandler: @escaping (Bool) -> Void) {
        let cancelTaskRequest = CancelTaskRequest(taskId: taskId)
        
        networkManager.sendPostRequest(urlString: CANCEL_TASK_URL, requestBody: cancelTaskRequest, responseBodyType: CancelTaskResponse.self) { responseBody in
            completionHandler(responseBody.success)
        }
    }
    
    // MARK: - Private Methods
    private func sendTask<T: CreateTaskRequest>(request: T, completionHandler: @escaping (Bool, String, String) -> Void) {
        networkManager.sendPostRequest(urlString: SUBMIT_TASK_URL, requestBody: request, responseBodyType: CreateTaskResponse.self) {
            responseBody in
            
            if responseBody.errorMsg == "" {
                completionHandler(true, responseBody.taskId, "")
            } else {
                completionHandler(false, responseBody.taskId, responseBody.errorMsg)
            }
        }
    }
    
}
