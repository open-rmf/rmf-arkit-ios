//
//  SettingsManager.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 3/8/21.
//

import Foundation

class Settings {
    
    // Singleton
    static let shared = Settings()
    
    // Settings for app
    
    // Building Map settings
    @Published var isWallsVisible = true
    
}
