//
//  TaskCell.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 6/7/21.
//

import UIKit

class TaskCell: UICollectionViewCell {
 
    
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var progressText: UILabel!
    @IBOutlet weak var taskIDText: UILabel!
    @IBOutlet weak var detailsText: UILabel!
    @IBOutlet weak var robotText: UILabel!
    @IBOutlet weak var taskTypeText: UILabel!
    @IBOutlet weak var priorityText: UILabel!
    @IBOutlet weak var taskStateText: UILabel!
    @IBOutlet weak var startTimeText: UILabel!
    @IBOutlet weak var endTimeText: UILabel!
    
    func populateFromTask(task: TaskSummary) {
        
        layer.borderWidth = 1
        layer.borderColor = UIColor.lightGray.cgColor
        
        let progressValue = Float(task.progress.replacingOccurrences(of: "%", with: ""))
        progressBar.setProgress(0, animated: false)
        progressBar.trackTintColor = UIColor.systemGray4
        
        switch task.state {
        case "Completed":
            progressBar.trackTintColor = UIColor.systemGreen
            progressText.text = "Completed"
        case "Delayed":
            progressBar.trackTintColor = UIColor.systemYellow
            progressText.text = "Delayed"
        case "Cancelled":
            progressBar.trackTintColor = UIColor.white
            progressText.text = "Cancelled"
        case "Failed":
            progressBar.trackTintColor = UIColor.red
            progressText.text = "Failed"
        default:
            progressBar.setProgress((progressValue ?? 0) / 100, animated: false)
            progressText.text = task.progress
        }
        
        progressText.sizeToFit()
        taskIDText.text = task.taskId
        detailsText.text = task.description
        detailsText.sizeToFit()
        robotText.text = task.robotName
        taskTypeText.text = task.taskType
        priorityText.text = String(task.priority)
        taskStateText.text = task.state
        startTimeText.text = String(task.startTime)
        endTimeText.text = String(task.endTime)
        
    }
    
}
