//
//  TaskManager.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 5/7/21.
//

import UIKit

// MARK: - ViewController
class TaskViewController: UIViewController {
    
    @IBOutlet weak var taskCollection: UICollectionView!
    @IBOutlet weak var slideIndicator: UIView!
    @IBOutlet weak var addTaskButton: UIButton!
    
    private var initialPointOrigin: CGPoint!
    private var pointOriginSet = false
    
    private let reuseIdentifier = "TaskCell"
    private let sectionInsets = UIEdgeInsets(top: 40.0, left: 20.0, bottom: 75.0, right: 20.0)
    private let tasksInSingleFrame: CGFloat = 1
    
    private var updateTimer: Timer!
    
    var taskManager: TaskManager!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureRecognizerAction))
        view.addGestureRecognizer(panGesture)
        
        slideIndicator.roundCorners(.allCorners, radius: 10)
        
        taskCollection.delegate = self
        taskCollection.dataSource = self
        
        startUpdateTimer()
    }
    
    override func viewDidLayoutSubviews() {
        if !pointOriginSet {
            initialPointOrigin = self.view.frame.origin
            pointOriginSet = true
        }
        
        taskCollection.frame = view.bounds
        taskCollection.frame.size.width -= 20
        taskCollection.frame.origin.x += 10
        
        taskCollection.reloadData()
    }
    
    @objc func panGestureRecognizerAction(sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: view)
        
        // Dont allow user to drag upwards
        if translation.y <= 0 {
            return
        }
        
        // Set frame origin using the translation
        view.frame.origin = CGPoint(x: 0, y: self.initialPointOrigin.y + translation.y)
        
        if sender.state == .ended {
            let dragVelocity = sender.velocity(in: view)
            if dragVelocity.y >= 1300 {
                self.dismiss(animated: true, completion: nil)
            } else {
                // Set back to original position of the view controller
                UIView.animate(withDuration: 0.3) {
                    self.view.frame.origin = self.initialPointOrigin
                }
            }
        }
    }
    
    @objc func updateData() {
        taskManager.downloadTaskList()
        taskCollection.reloadData()
    }
    
    @IBAction func addTaskButtonPressed(_ sender: Any) {
        let taskCreationVC = TaskCreationViewController()
        let taskCreationNavigationVC = UINavigationController(rootViewController: taskCreationVC)
        
        taskCreationVC.taskManager = self.taskManager
        
        taskCreationNavigationVC.modalTransitionStyle = .coverVertical
        taskCreationNavigationVC.modalPresentationStyle = .fullScreen
        
        present(taskCreationNavigationVC, animated: true, completion: nil)
    }
    
    private func startUpdateTimer() {
        updateTimer = Timer(timeInterval: 1.0, target: self, selector: #selector(updateData), userInfo: nil, repeats: true)
        
        // Add some tolerance to the timer (+- 0.2 seconds) to reduce load
        updateTimer.tolerance = 0.2
        
        // Add timer to common run loop -> prevents timer from not firing if user interacting with UI
        RunLoop.current.add(updateTimer, forMode: .common)
    }
    
    private func stopUpdateTimer() {
        updateTimer.invalidate()
    }
    
    deinit {
        stopUpdateTimer()
    }
}

// MARK: - UICollectionViewDataSource
extension TaskViewController: UICollectionViewDataSource {
    
    // How many cells to return
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return taskManager.taskList.count
    }
    
    // Cell view to show at each index
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! TaskCell
        
        let currentTask = taskManager.taskList[indexPath.item]
        
        cell.populateFromTask(task: currentTask)
        
        return cell
    }
    
    // Tap recognizer for each cell
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        handleCancelling(indexToCancel: indexPath.item)
    }
    
    private func handleCancelling(indexToCancel: Int) {
        // Need to stop the timer to avoid possible race condition where indexPath no longer
        // refers to correct task inside taskList since latest data may have shifted the taskList ordering
        stopUpdateTimer()
        
        let selectedTask = self.taskManager.taskList[indexToCancel]
        
        // Cannot cancel a task that has ended
        if selectedTask.done {
            return
        }
        
        let cancelMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        cancelMenu.addAction(UIAlertAction(title: "Cancel Task", style: .destructive) {
            _ in
        
            self.showCancelWaitingAlert()
            
            // Cancel the task and on completion remove the temporary alert then show a new alert stating outcome
            self.taskManager.cancelTask(taskId: selectedTask.taskId) {
                success in
                
                // UI handling must be done on main thread
                DispatchQueue.main.async {
                    
                    // Dismiss cancel waiting alert and show the outcome alert
                    self.dismiss(animated: true) {
                        var title: String
                        var message: String
                        
                        switch success {
                        case true:
                            title = "Cancellation Success"
                            message = "The selected task has been cancelled"
                        case false:
                            title = "Cancellation Failure"
                            message = "The selected task could not be cancelled"
                        }

                        let outcomeAlert = UIAlertController(title: title, message: message, preferredStyle: .alert)

                        outcomeAlert.addAction(UIAlertAction(title: "Ok", style: .default))

                        self.present(outcomeAlert, animated: true)
                    }
                    
                    
                }
            }
        })
        
        cancelMenu.addAction(UIAlertAction(title: "Back", style: .cancel))
        
        // After we have finished presenting the cancel menu we need to update the UI/Data and restart the timer
        present(cancelMenu, animated: true) {
            self.updateData()
            self.startUpdateTimer()
        }
    }
    
    private func showCancelWaitingAlert() {
        let attemptCancelAlert = UIAlertController(title: "Attempting to Cancel Task...", message: "\n\n", preferredStyle: .alert)

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
}

// MARK: - CollectionViewFlowLayoutDelegate
extension TaskViewController: UICollectionViewDelegateFlowLayout {
    
    // Cell sizing
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath)
    -> CGSize {
        let paddingSpace = sectionInsets.left * (tasksInSingleFrame + 1)
        let availableWidth = taskCollection.frame.width - paddingSpace
        let widthPerItem = availableWidth / tasksInSingleFrame
        
        return CGSize(width: widthPerItem, height: view.frame.height - sectionInsets.top - sectionInsets.bottom)
    }
    
    // Cell insets
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int)
    -> UIEdgeInsets {
        return sectionInsets
    }
    
    // Spacing between successive cells
    func collectionView(
        _ collectionView:UICollectionView,
        layout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt: Int)
    -> CGFloat {
        return sectionInsets.left
    }
}
