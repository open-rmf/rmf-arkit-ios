//
//  Network.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 18/6/21.
//

import Foundation
import ARKit
import RealityKit

struct NetworkManager {
    
    func getJSONfromURLasync<T>(urlString: String, modelType: T.Type, completionHandler: @escaping (T) -> Void) where T : Decodable {
        let url = URL(string: urlString)!
        
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
            
            // Since the option is available and to keep consistent formatting we will use camelCase
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                guard let data = data else {
                    print("ERROR: No data retrieved")
                    return
                }
                
                let result = try decoder.decode(modelType, from: data)
                completionHandler(result)
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
