//
//  TrajectoryManager.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 13/7/21.
//

import Foundation

class TrajectoryManager {
    let TRAJ_SERVER_URL = "ws://192.168.1.201:8006"
    
    var networkManager: NetworkManager
    
    var webSocketConnection: URLSessionWebSocketTask?
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
        
        webSocketConnection = self.networkManager.openWebSocketConnection(urlString: TRAJ_SERVER_URL)
    }
}
