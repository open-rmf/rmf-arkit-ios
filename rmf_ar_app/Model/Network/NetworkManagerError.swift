//
//  NetworkErrors.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 27/7/21.
//

import Foundation

enum NetworkManagerError: Error {
    case URLInvalid(String)
    case ClientError(String)
    case ServerError(String)
    case DecodeError(String)
    case EncodeError(String)
}

extension NetworkManagerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .URLInvalid(let urlString):
            return String("'\(urlString)' is not a valid URL")
        case .ClientError(let msg):
            return String("Client Error - \(msg)")
        case .ServerError(let msg):
            return String("Server Error - \(msg)")
        case .DecodeError(let msg):
            return String("Decode Error - \(msg)")
        case .EncodeError(let msg):
            return String("Encode Error - \(msg)")
        }
    }
}
