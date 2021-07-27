//
//  Network.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 18/6/21.
//

import Foundation
import os

class NetworkManager {
    
    var session: URLSession
    
    init() {
        let configuration = URLSessionConfiguration.default
        
        configuration.timeoutIntervalForResource = 5
        
        session = URLSession(configuration: configuration)
    }
    
    // MARK: - REST Methods
    func sendGetRequest<T: Decodable>(urlString: String, responseBodyType: T.Type, completionHandler: @escaping (Result<T, NetworkManagerError>) -> Void) {
        guard let url = URL(string: urlString) else {
            completionHandler(.failure(.URLInvalid(urlString)))
            return
        }
        
        let task = session.dataTask(with: url) { data, response, error in
            
            let responseResult = self.handleDataTaskResponse(data: data, response: response, error: error, responseBodyType: responseBodyType)
            
            completionHandler(responseResult)
        }
        
        task.resume()
    }
    
    func sendPostRequest<T: Encodable, U: Decodable>(urlString: String, requestBody: T, responseBodyType: U.Type, completionHandler: @escaping (Result<U, NetworkManagerError>) -> Void) {
        
        guard let url = URL(string: urlString) else {
            return
        }
        
        // Setup urlRequest with a timeout of 20 seconds
        var urlRequest = URLRequest(url: url, timeoutInterval: 20)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        
        // Encode data
        let encodeResult = self.encodeJSON(from: requestBody)
        
        switch encodeResult {
        case .success(let requestData):
            urlRequest.httpBody = requestData
        case .failure(let e):
            completionHandler(.failure(e))
            return
        }
        
        let task = session.dataTask(with: urlRequest) { data, response, error in
            let responseResult = self.handleDataTaskResponse(data: data, response: response, error: error, responseBodyType: responseBodyType)
            
            completionHandler(responseResult)
        }
        
        task.resume()
        
    }

    // MARK: - Web Socket Methods
    func openWebSocketConnection(urlString: String) -> URLSessionWebSocketTask? {
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        let webSocketTask = session.webSocketTask(with: url)
        webSocketTask.resume()
        
        return webSocketTask
    }
    
    func closeWebSocketConnection(webSocketConnection: URLSessionWebSocketTask) {
        let reason = "Closing connection".data(using: .utf8)
        webSocketConnection.cancel(with: .normalClosure, reason: reason)
    }
    
    func sendWebSocketRequest<T: Encodable, U: Decodable>(webSocketConnection: URLSessionWebSocketTask, requestBody: T, responseBodyType: U.Type, completionHandler: @escaping (Result<U, NetworkManagerError>) -> Void) {
        
        let encodeResult = self.encodeJSON(from: requestBody)
        var webSocketData: URLSessionWebSocketTask.Message
        
        switch encodeResult {
        case .success(let requestData):
            webSocketData = URLSessionWebSocketTask.Message.data(requestData)
        case .failure(let e):
            completionHandler(.failure(e))
            return
        }
        
        webSocketConnection.send(webSocketData) {
            error in
            
            if let error = error {
                let msg = self.handleClientError(clientError: error)
                completionHandler(.failure(.ClientError(msg)))
            }
        }
        
        webSocketConnection.receive() {
            result in
            
            switch result {
            case .success(let response):
                // Response can either be as data or as string
                switch response {
                case .data(let data):
                    let decodeResult = self.decodeJSON(from: data, to: responseBodyType)
                    completionHandler(decodeResult)

                case .string(let text):
                    let decodeResult = self.decodeJSON(from: text.data(using: .utf8)!, to: responseBodyType)
                    completionHandler(decodeResult)
                @unknown default:
                    // Should never happen unless URLSessionWebSocketTask.Message type is changed
                    fatalError()
                }
                
            case .failure(let error):
                completionHandler(.failure(.ServerError(error.localizedDescription)))
            }
        }
    }
    
    // MARK: - Private Methods
    private func handleDataTaskResponse<T: Decodable>(data: Data?, response: URLResponse?, error: Error?, responseBodyType: T.Type) -> Result<T, NetworkManagerError> {
        if let error = error {
            let msg = handleClientError(clientError: error)
            return .failure(.ClientError(msg))
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let msg = handleServerError(serverResponse: response)
            return .failure(.ServerError(msg))
        }
        
        guard let data = data else {
            return .failure(.ServerError("No data received"))
        }
        
        return self.decodeJSON(from: data, to: responseBodyType)
    }
    
    private func handleClientError(clientError: Error) -> String {
        return clientError.localizedDescription
    }
    
    private func handleServerError(serverResponse: URLResponse?) -> String {
        guard let httpResponse = serverResponse as? HTTPURLResponse else {
            return "Server Response not a HTTP response"
        }
        
        return "Status Code: \(httpResponse.statusCode)"
    }
    
    private func decodeJSON<T: Decodable>(from data: Data, to decodeType: T.Type) -> Result<T, NetworkManagerError> {
        
        var msg = "Type: \(decodeType) | "
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            return .success(try decoder.decode(decodeType, from: data))
            
        } catch let DecodingError.dataCorrupted(context) {
            msg = "\(context.debugDescription)"
        } catch let DecodingError.keyNotFound(key, context) {
            msg = "Key '\(key.stringValue)' not found: \(context.debugDescription) | codingPath: \(context.codingPath.description)"
        } catch let DecodingError.valueNotFound(value, context) {
            msg = "Value '\(value)' not found: \(context.debugDescription) | codingPath: \(context.codingPath)"
        } catch let DecodingError.typeMismatch(type, context)  {
            msg = "Type '\(String(describing: type))' mismatch: \(context.debugDescription) | codingPath:\(context.codingPath.description)"
        } catch {
            msg = "JSON Decode error: \(error.localizedDescription)"
        }
        
        return .failure(.DecodeError(msg))
    }
    
    private func encodeJSON<T: Encodable>(from encodedData: T) -> Result<Data, NetworkManagerError> {
        
        var msg = ""
        
        do {
            let jsonEncoder = JSONEncoder()
            jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
            return .success(try jsonEncoder.encode(encodedData))
        } catch let EncodingError.invalidValue(type, context) {
            msg = "Type '\(String(describing: type))' mismatch: \(context.debugDescription)"
        } catch {
            msg = "JSON Encode error: \(error.localizedDescription)"
        }
        
        return .failure(.EncodeError(msg))
    }
    
}
