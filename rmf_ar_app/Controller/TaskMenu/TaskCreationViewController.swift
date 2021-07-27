//
//  TaskCreationViewController.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 8/7/21.
//

import Foundation
import UIKit
import Eureka
import os

class TaskCreationViewController: FormViewController {
    
    var taskManager: TaskManager!
    var dashboardConfig: DashboardConfig!
    
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "TaskCreationViewController")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigationBar()
        
        LabelRow.defaultCellUpdate = { cell, row in
            cell.textLabel?.textColor = .red
            cell.textLabel?.font = UIFont.systemFont(ofSize: 13)
            
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if dashboardConfig == nil {
            displayDefaultDashboard()
            
            taskManager.networkManager.sendGetRequest(urlString: URLConstants.DASHBOARD, responseBodyType: DashboardConfig.self) {
                responseResult in
                
                switch responseResult {
                case .success(let data):
                    self.dashboardConfig = data
                    
                    // All UI operations must be done on main thread
                    DispatchQueue.main.async {
                        self.form.removeAll()
                        self.displayDashboard(from: data)
                    }
                    
                case .failure(let e):
                    self.logger.error("\(e.localizedDescription)")
                }
            }
        }
    }

    private func setupNavigationBar() {
        
        self.navigationItem.title = "Create Task"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backButtonPressed))
        
    }
    
    @objc private func backButtonPressed() {
        self.dismiss(animated: true, completion: nil)
    }
    
    private func displayDashboard(from dashboardConfig: DashboardConfig) {
        // Display start time and priority setting
        form +++ Section("Submit a Task")
            <<< IntRow("StartTime") { row in
                row.title = "Set start time (mins from now)"
                row.value = 0
                
                // Validation
                row.add(rule: RuleGreaterOrEqualThan(min: 0))
            }
            .cellUpdate { (cell, row) in
                if !row.isValid {
                    cell.titleLabel?.textColor = .systemRed
                }
            }
            
            <<< StepperRow("Priority").cellSetup { (cell, row) in
                row.title = "Choose a priority"
                row.value = 0
                
                // Validation
                row.add(rule: RuleGreaterOrEqualThan(min: 0, msg: "Priority can only be 0 or 1", id: nil))
                row.add(rule: RuleSmallerOrEqualThan(max: 1, msg: "Priority can only be 0 or 1", id: nil))
                
                row.validationOptions = .validatesOnChange
                
            }
            .cellUpdate { (cell, row) in
                if row.value != nil {
                    // Always show an integer instead of a float
                    cell.valueLabel.text = "\(Int(row.value!))"
                }
                
                if !row.isValid {
                    cell.titleLabel?.textColor = .systemRed
                }
            }
            .onRowValidationChanged { cell, row in
                self.visualizeValidationError(cell: cell, row: row)
            }
        
        form +++ Section("Task Type")
            
            <<< SegmentedRow<String>("TaskTypeSelector") { row in
                row.options = dashboardConfig.validTask
                
                // Validation
                row.add(rule: RuleRequired(msg: "Please select a task type", id: nil))
            }
            .onRowValidationChanged { cell, row in
                self.visualizeValidationError(cell: cell, row: row)
            }
        
        setupTaskSections(from: dashboardConfig)
        
        form +++ ButtonRow("SubmitButton") { row in
            row.title = "Submit Request"
            
            // Hide the button if no task type selected
            row.hidden = Condition.function(["TaskTypeSelector"], {form in
                return ((form.rowBy(tag: "TaskTypeSelector") as? SegmentedRow<String>)?.value == nil)
            })
        }
        .onCellSelection { cell, row in
            // Only submit the task request if all forms are valid
            // validate will only run on sections/rows that are visible
            if self.form.validate().count == 0 {
                self.handleTaskSubmission(dashboardConfig: dashboardConfig)
            }
        }
    }
    
    private func setupTaskSections(from dashboardConfig: DashboardConfig) {
        for taskType in dashboardConfig.validTask {
            switch taskType {
            case "Delivery":
                setupDeliverySection(deliveryTasks: dashboardConfig.task.Delivery)
            case "Loop":
                setupLoopSection(loopTasks: dashboardConfig.task.Loop)
            case "Clean":
                setupCleanSection(cleanTasks: dashboardConfig.task.Clean)
            default:
                continue
            }
        }
    }
    
    private func setupDeliverySection(deliveryTasks: ValidDeliveryTasks) {
        
        form +++ Section("Delivery Task") { section in
            // Only show when the task type selector is on Delivery
            section.hidden = Condition.function(["TaskTypeSelector"], {form in
                return !((form.rowBy(tag: "TaskTypeSelector") as? SegmentedRow)?.value == "Delivery")
            })
        }
        
        <<< PickerInputRow<String>("DeliveryTaskPicker"){ row in
            row.title = "Delivery task"
            row.noValueDisplayText = "Select delivery task"
            
            row.options = []
            
            if let availableOptions = deliveryTasks.option {
                for (key, _) in availableOptions {
                    row.options.append(key)
                }
                row.value = row.options.first
            }
        }
    }
    
    private func setupLoopSection(loopTasks: ValidLoopTasks) {
        form +++ Section("Loop Task") { section in
            // Only show when the task type selector is on Loop
            section.hidden = Condition.function(["TaskTypeSelector"], {form in
                return !((form.rowBy(tag: "TaskTypeSelector") as? SegmentedRow)?.value == "Loop")
            })
        }
        
        <<< PickerInputRow<String>("StartLocationPicker") { row in
            row.title = "Start location"
            row.noValueDisplayText = "Select location"
            
            if let availablePlaces = loopTasks.places {
                row.options =  availablePlaces
            }
            
            // Validation
            let notSameAsEndLocationRule = RuleClosure<String>{
                rowValue in
                
                let endLocationRow: PickerInputRow<String>? = self.form.rowBy(tag: "EndLocationPicker")
                let endValue = endLocationRow?.value
                
                if rowValue == endValue {
                    return ValidationError(msg: "Start and end locations cannot be the same")
                } else {
                    return nil
                }
            }
            
            row.add(rule: notSameAsEndLocationRule)
            row.add(rule: RuleRequired())
        }
        .onRowValidationChanged { cell, row in
            self.visualizeValidationError(cell: cell, row: row)
            
            // Need to validate both rows whenever one is changed
            if let endLocationRow = self.form.rowBy(tag: "EndLocationPicker") as? PickerInputRow<String> {
                endLocationRow.validate()
                self.visualizeValidationError(cell: endLocationRow.cell, row: endLocationRow)
            }
        }
        
        <<< PickerInputRow<String>("EndLocationPicker") { row in
            row.title = "End location"
            row.noValueDisplayText = "Select location"
            
            if let availablePlaces = loopTasks.places {
                row.options =  availablePlaces
            }
            
            // Validation
            let notSameAsStartLocationRule = RuleClosure<String>{
                rowValue in
                
                let startLocationRow: PickerInputRow<String>? = self.form.rowBy(tag: "StartLocationPicker")
                let startValue = startLocationRow?.value
                
                if rowValue == startValue {
                    return ValidationError(msg: "Start and end locations cannot be the same")
                } else {
                    return nil
                }
            }
            
            row.add(rule: notSameAsStartLocationRule)
            row.add(rule: RuleRequired())
        }
        .onRowValidationChanged { cell, row in
            self.visualizeValidationError(cell: cell, row: row)
            
            // Need to validate both rows whenever one is changed
            if let startLocationRow = self.form.rowBy(tag: "StartLocationPicker") as? PickerInputRow<String> {
                startLocationRow.validate()
                self.visualizeValidationError(cell: startLocationRow.cell, row: startLocationRow)
            }
        }
        
        <<< StepperRow("NumberOfLoops").cellSetup { cell, row in
            row.title = "Number of Loops"
            row.value = 1
            row.cell.stepper.minimumValue = 1
            
            // Validation
            row.add(rule: RuleGreaterThan(min: 0, msg: "Number of loops must be greater than 0"))
            
        }
        .cellUpdate { cell, row in
            if row.value != nil {
                // Always show an integer instead of a float
                cell.valueLabel.text = "\(Int(row.value!))"
            }
            
            if !row.isValid {
                cell.titleLabel?.textColor = .systemRed
            }
        }
        .onRowValidationChanged { cell, row in
            self.visualizeValidationError(cell: cell, row: row)
        }
    }
    
    private func setupCleanSection(cleanTasks: ValidCleanTasks) {
        form +++ Section("Clean Task") { section in
            section.hidden = Condition.function(["TaskTypeSelector"], {form in
                // Only show when the task type selector is on Clean
                return !((form.rowBy(tag: "TaskTypeSelector") as? SegmentedRow)?.value == "Clean")
            })
        }
        
        <<< PickerInputRow<String>("CleanTaskPicker") { row in
            row.title = "Clean task"
            row.noValueDisplayText = "Select cleaning task"
            
            if let availableOptions = cleanTasks.option {
                row.options =  availableOptions
                row.value = row.options.first
            }
        }
    }
    
    private func displayDefaultDashboard() {
        form +++ Section("No tasks configured")
    }
    
    private func visualizeValidationError(cell: BaseCell, row: BaseRow) {
        let rowIndex = row.indexPath!.row
        while row.section!.count > rowIndex + 1 && row.section?[rowIndex  + 1] is LabelRow {
            row.section?.remove(at: rowIndex + 1)
        }
        if !row.isValid {
            for (index, validationMsg) in row.validationErrors.map({ $0.msg }).enumerated() {
                let labelRow = LabelRow() { label in
                    label.title = validationMsg
                    label.cell.height = { 30 }
                }
                let indexPath = row.indexPath!.row + index + 1
                row.section?.insert(labelRow, at: indexPath)
            }
        }
    }
    
    private func handleTaskSubmission(dashboardConfig: DashboardConfig) {
         showSubmitWaitingAlert()
        
        self.submitTask(dashboardConfig: dashboardConfig) {
            success, taskId, error in
            
            // UI handling must be done on main thread
            DispatchQueue.main.async {
                
                // Dismiss waiting alert and show the outcome alert
                self.dismiss(animated: true) {
                    var title: String
                    var message: String
                    
                    switch success {
                    case true:
                        title = "Succesfully added task"
                        message = "Task has been added with ID: \(taskId)"
                    case false:
                        title = "Failed to add Task"
                        message = "Failed with error: \(error)"
                    }

                    let outcomeAlert = UIAlertController(title: title, message: message, preferredStyle: .alert)

                    outcomeAlert.addAction(UIAlertAction(title: "Ok", style: .default) {_ in
                        
                        // Dismiss the task creation view controller and go back to the main task view
                        self.navigationController?.dismiss(animated: true, completion: nil)
                    })

                    self.present(outcomeAlert, animated: true)
                }
            }
        }
    }
    
    private func showSubmitWaitingAlert() {
        let attemptCancelAlert = UIAlertController(title: "Attempting to Submit Task...", message: "\n\n", preferredStyle: .alert)

        // Add a loading wheel and adjust layout correctly
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        attemptCancelAlert.view.addSubview(loadingIndicator)
        
        let constraints = [
            loadingIndicator.centerXAnchor.constraint(equalTo: attemptCancelAlert.view.centerXAnchor),
            loadingIndicator.bottomAnchor.constraint(equalTo: attemptCancelAlert.view.bottomAnchor, constant: -10)
        ]
        NSLayoutConstraint.activate(constraints)
        
        loadingIndicator.isUserInteractionEnabled = false
        loadingIndicator.startAnimating()

        self.present(attemptCancelAlert, animated: true, completion: nil)
    }
    
    private func submitTask(dashboardConfig: DashboardConfig, completionHandler: @escaping (Bool, String, String) -> Void) {
        guard let taskManager = self.taskManager else { return }
        
        // Button is hidden if task type selector is nil so forced unwrap is safe
        let taskType = (self.form.rowBy(tag: "TaskTypeSelector") as? SegmentedRow<String>)!.value
        
        // Validation rules ensure that each row must have a value so forced unwrap is always safe
        let startTime = (self.form.rowBy(tag: "StartTime") as? IntRow)!.value!
        let priority = Int((self.form.rowBy(tag: "Priority") as? StepperRow)!.value!)
        
        switch taskType {
        case "Delivery":
            let deliveryOption = (self.form.rowBy(tag: "DeliveryTaskPicker") as? PickerInputRow<String>)!.value!
            
            let deliveryData = (dashboardConfig.task.Delivery.option?[deliveryOption])!
                
            taskManager.createDeliveryTask(startTime: startTime, priority: priority, pickupPlaceName: deliveryData.pickupPlaceName, pickupDispenser: deliveryData.pickupDispenser, dropoffPlaceName: deliveryData.dropoffPlaceName, dropoffIngestor: deliveryData.dropoffIngestor, completionHandler: completionHandler)
            
        case "Loop":
            let startLocation = (self.form.rowBy(tag: "StartLocationPicker") as? PickerInputRow<String>)!.value!
            let endLocation = (self.form.rowBy(tag: "EndLocationPicker") as? PickerInputRow<String>)!.value!
            let numLoops = Int((self.form.rowBy(tag: "NumberOfLoops") as? StepperRow)!.value!)
            
            taskManager.createLoopTask(startTime: startTime, priority: priority, startName: startLocation, finishName: endLocation, numLoops: numLoops, completionHandler: completionHandler)
        
        case "Clean":
            let cleanOption = (self.form.rowBy(tag: "CleanTaskPicker") as? PickerInputRow<String>)!.value!
            
            taskManager.createCleanTask(startTime: startTime, priority: priority, startWaypoint: cleanOption, completionHandler: completionHandler)
        default:
            return
        }
        
        
    }
}
