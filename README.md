# iOS ARKit Interface to RMF
## Contents

- **[About](#about)**
- **[Setup](#setup)**
    - **[Requirements](#requirements)**
    - **[Connecting to RMF](#connecting-to-rmf)**
    - **[Adding a new tag](#adding-a-new-tag)**
- **[Usage](#usage)**
    - **[Robot Tag Localization](#robot-tag-localization)**
    - **[Tasks](#tasks)**
- **[Advanced](#advanced)**
</br>

## About
This iOS app utilizes Augmented Reality (AR) to enhance monitoring and introspection of the [Robotics Middleware Framework](https://github.com/open-rmf/rmf). Currently the app will display the following information:
- Robot Data
    - Name
    - Fleet
    - Assigned tasks
    - Status
    - Battery percentage
    - Level
- Navigation Graphs
    - Edges
    - Vertices
    - Named vertices
- Trajectories
    - Conflicts
- Wall Graphs

## Setup
### Requirements
* XCode 12+
* Swift 5+
* iOS 14.5+

### Running on your device
You will need an Apple ID in order to upload the app to your device. To configure your account with XCode select `XCode > Preferences > Account` and login with your Apple ID. To upload the app onto your device open the .xcodeproj file in XCode. Next, ensure your device is correctly plugged in then from the menu bar select `Product > Destination > "Your Device Name"`. Build and run the project to install it onto your device.

The first time you run the app you will receive an error as it will not be verified. To verify the app go into the settings app on your device and navigate to `General > Device Management > "Your Developer ID"`. Press the button labelled `Trust`. Once done you will be able to open and run the app on your device.

### Connecting to RMF
Ensure that the RMF API Server is running and change the IP addresses in [URLConstants.swift](rmf_ar_app/Resources/URLConstants.swift) to match with the correct end points.

### Adding a new Robot tag
Within XCode navigate to the [Assets.xcassets](rmf_ar_app/Resources/Assets.xcassets) folder. Drag and drop the new image you wish to use as a tag. Within the attributes inspector panel on the right ensure that you label the image with the same name as the robot it will be tagged to. You will also need to set the size of the image in the real world. ARKit relies on these measurements to detect and track the image so ensure your values are as accurate as possible.
</br>

## Usage
### Robot Tag Localization
#### Initial Localization
Once the ARKit coaching overlay has disappeard and your iOS device is tracking normally, simply scan the tag of a stationary robot. If the app is able to find the robot in RMF then the robots data should appear overlaid on the tag. Subsequently, any navigation graphs and unscanned robots will be displayed.

#### Relocalization
It is possible for ARKit's tracking to drift causing the visuals to no longer be aligned correctly with RMF. If this occurs simply scan a stationary robot. If a significant translation or rotational error is detected then the app will correct itself.

#### Untracked Robots
Any robot whose tag is not tracked will be displayed with a marker. A tracked tag will be considered untracked if not detected by ARKit for longer than the specified timeout interval in [ARConstants.swift](#rmf_ar_app/Resources/ARConstants.swift).

### Tasks
##### Task List
To open the tasks list press the button labelled "tasks" in the top right hand corner of the screen. This will bring up a list of current tasks. 

##### Add Task
To add a task simply press the "+" button and a form containing the valid tasks and options will appear. Once the form is correctly filled you can press the submit button to send the task to RMF. A popup box will inform you if the task was succesfully scheduled or not.

##### Cancel Task
To cancel a task, press on the task you wish to cancel. If the task is cancellable then a menu with the option to cancel will appear. Only tasks that are queued may be cancelled.

## Advanced
<details>
<summary>Changing the localization technique</summary>
Currently the only localization method is via scanning robot tags. However, it is possible to easily implement a different localization technique. There are only two requirements that a new localizer must follow:
</br>
</br>
  
1. Set the world origin of the current ARView's session using the method `setWorldOrigin(relativeTransform: simd_float4x4)`
    - [ARKit docs](https://developer.apple.com/documentation/arkit/arsession/2942278-setworldorigin)
2. Fire a notification on the topic "setWorldOrigin"
    - The notification must contain a dictionary containing the current level name

If step 2 is not followed then none of the AR visuals will appear.
</details>
