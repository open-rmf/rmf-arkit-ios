//
//  Network.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 18/6/21.
//

import Foundation
import ARKit
import RealityKit

class NetworkManager {
    
    func sendGetRequest<T: Decodable>(urlString: String, responseBodyType: T.Type, completionHandler: @escaping (T) -> Void) {
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                self.handleClientError(clientError: error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                self.handleServerError(serverResponse: response)
                return
            }
            
            do {
                guard let data = data else {
                    print("ERROR: No data received")
                    return
                }
                
                
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let result = try decoder.decode(responseBodyType, from: data)
                
                completionHandler(result)
            } catch {
                print(error)
            }
        }
        
        task.resume()
    }
    
    func sendPostRequest<T: Encodable, U: Decodable>(urlString: String, requestBody: T, responseBodyType: U.Type, responseHandler: @escaping (U) -> Void) {
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            return
        }
        
        var requestBody: Optional<Data> = nil
        
        do {
            let jsonEncoder = JSONEncoder()
            jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
            requestBody = try jsonEncoder.encode(requestBody)
        } catch {
            print(error)
        }
        
        guard requestBody != nil else {
            print("Failed to convert request model to Data")
            return
        }
        
        // Timeout after 1 minute
        var urlRequest = URLRequest(url: url, timeoutInterval: 60)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestBody
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                self.handleClientError(clientError: error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                self.handleServerError(serverResponse: response)
                return
            }
            
            do {
                guard let data = data else {
                    print("ERROR: No data received")
                    return
                }
                
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let responseBody = try decoder.decode(responseBodyType.self, from: data)
                
                responseHandler(responseBody)
            } catch {
                print(error)
            }
        }
        
        task.resume()
        
    }
    
    func handleClientError(clientError: Error) {
        // TODO: Better handling of client error
        print("ERROR: Client Error - \(clientError.localizedDescription)")
    }
    
    func handleServerError(serverResponse: URLResponse?) {
        // TODO: Better handling of server error
        guard let httpResponse = serverResponse as? HTTPURLResponse else {
            print("ERROR: Server Response not a HTTP response")
            return
        }
        
        print("ERROR: Server Error - Status Code: \(httpResponse.statusCode)")
    }
    
    
    
}
