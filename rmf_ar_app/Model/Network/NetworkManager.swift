//
//  Network.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 18/6/21.
//

import Foundation
import os

class NetworkManager {
    
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NetworkManager")
    
    // MARK: - REST Methods
    func sendGetRequest<T: Decodable>(urlString: String, responseBodyType: T.Type, completionHandler: @escaping (T) -> Void) {
        guard let url = URL(string: urlString) else {
            logger.error("Invalid URL: \(urlString)")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let responseData = self.handleDataTaskResponse(data: data, response: response, error: error) else {
                return
            }
            
            // Run completionHandler only if successfully decoded
            if let responseBody = self.decodeJSON(from: responseData, to: responseBodyType) {
                completionHandler(responseBody)
            }
        }
        
        task.resume()
    }
    
    func sendPostRequest<T: Encodable, U: Decodable>(urlString: String, requestBody: T, responseBodyType: U.Type, completionHandler: @escaping (U) -> Void) {
        
        guard let url = URL(string: urlString) else {
            logger.error("Invalid URL: \(urlString)")
            return
        }
        
        guard let requestData = self.encodeJSON(from: requestBody) else {
            return
        }
        
        // Timeout after 1 minute
        var urlRequest = URLRequest(url: url, timeoutInterval: 60)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            guard let responseData = self.handleDataTaskResponse(data: data, response: response, error: error) else {
                return
            }
            
            // Run completionHandler only if successfully decoded
            if let responseBody = self.decodeJSON(from: responseData, to: responseBodyType) {
                completionHandler(responseBody)
            }
        }
        
        task.resume()
        
    }

    // MARK: - Web Socket Methods
    func openWebSocketConnection(urlString: String) -> URLSessionWebSocketTask? {
        guard let url = URL(string: urlString) else {
            logger.error("Invalid URL: \(urlString)")
            return nil
        }
        
        let webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask.resume()
        
        return webSocketTask
    }
    
    func closeWebSocketConnection(webSocketConnection: URLSessionWebSocketTask) {
        let reason = "Closing connection".data(using: .utf8)
        webSocketConnection.cancel(with: .normalClosure, reason: reason)
    }
    
    func sendWebSocketRequest<T: Encodable, U: Decodable>(webSocketConnection: URLSessionWebSocketTask, requestBody: T, responseBodyType: U.Type, completionHandler: @escaping (U) -> Void) {
        
        guard let requestData = self.encodeJSON(from: requestBody) else {
            return
        }
        
        let webSocketData = URLSessionWebSocketTask.Message.data(requestData)
        
        webSocketConnection.send(webSocketData) {
            error in
            
            if let error = error {
                self.logger.error("\(error.localizedDescription)")
            }
        }
        
        webSocketConnection.receive() {
            result in
            
            switch result {
            case .success(let response):
                // Response can either be as data or as
                switch response {
                case .data(let data):
                    if let responseBody = self.decodeJSON(from: data, to: responseBodyType) {
                        completionHandler(responseBody)
                    }

                case .string(let text):
                    if let responseBody = self.decodeJSON(from: text.data(using: .utf8)!, to: responseBodyType) {
                        completionHandler(responseBody)
                    }
                @unknown default:
                    // Should never happen unless URLSessionWebSocketTask.Message type is changed
                    fatalError()
                }
                
            case .failure(let error):
                self.logger.error("\(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Private Methods
    private func handleDataTaskResponse(data: Data?, response: URLResponse?, error: Error?) -> Data? {
        if let error = error {
            handleClientError(clientError: error)
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            handleServerError(serverResponse: response)
            return nil
        }
        
        guard let data = data else {
            logger.error("No data received")
            return nil
        }
        
        return data
    }
    
    private func handleClientError(clientError: Error) {
        logger.error("Client Error - \(clientError.localizedDescription)")
    }
    
    private func handleServerError(serverResponse: URLResponse?) {
        guard let httpResponse = serverResponse as? HTTPURLResponse else {
            logger.error("Server Error - Server Response not a HTTP response")
            return
        }
        
        logger.error("Server Error - Status Code: \(httpResponse.statusCode)")
    }
    
    private func decodeJSON<T: Decodable>(from data: Data, to decodeType: T.Type) -> T? {
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            return try decoder.decode(decodeType, from: data)
            
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        
        return nil
    }
    
    private func encodeJSON<T: Encodable>(from encodedData: T) -> Data? {
        do {
            let jsonEncoder = JSONEncoder()
            jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
            return try jsonEncoder.encode(encodedData)
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        
        return nil
    }
    
}
