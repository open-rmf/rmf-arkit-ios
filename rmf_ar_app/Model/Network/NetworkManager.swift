//
//  Network.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 18/6/21.
//

import Foundation
import os

class NetworkManager {
    
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "network")
    
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
    
    func handleDataTaskResponse(data: Data?, response: URLResponse?, error: Error?) -> Data? {
        if let error = error {
            self.handleClientError(clientError: error)
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            self.handleServerError(serverResponse: response)
            return nil
        }
        
        guard let data = data else {
            self.logger.error("No data received")
            return nil
        }
        
        return data
    }
    
    func handleClientError(clientError: Error) {
        logger.error("Client Error - \(clientError.localizedDescription)")
    }
    
    func handleServerError(serverResponse: URLResponse?) {
        guard let httpResponse = serverResponse as? HTTPURLResponse else {
            logger.error("Server Error - Server Response not a HTTP response")
            return
        }
        
        logger.error("Server Error - Status Code: \(httpResponse.statusCode)")
    }
    
    func decodeJSON<T: Decodable>(from data: Data, to decodeType: T.Type) -> T? {
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            return try decoder.decode(decodeType, from: data)
            
        } catch {
            self.logger.error("\(error.localizedDescription)")
        }
        
        return nil
    }
    
    func encodeJSON<T: Encodable>(from encodedData: T) -> Data? {
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
