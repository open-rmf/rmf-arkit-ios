//
//  SettingsViewController.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 3/8/21.
//

import Foundation
import UIKit
import Eureka


class SettingsViewController: FormViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Settings"
        
        form +++ Section("Building Map Settings")
            <<< SwitchRow("ShowWalls") { row in
                row.title = "Show walls"
                row.value = Settings.shared.isWallsVisible
            }
            .onChange { row in
                Settings.shared.isWallsVisible = row.value!
            }
    }
}
