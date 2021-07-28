//
//  TrajectoryEntity.swift
//  rmf_ar_app
//
//  Created by Matthew Booker on 19/7/21.
//

import Foundation
import RealityKit
import UIKit

class TrajectoryEntity: Entity {
    
    var segments: [ModelEntity] = []
    
    required init() {
        super.init()
    }
    
    required init(trajectory: RobotTrajectory, currentTime: Int, color: UIColor, heightLevel: Int) {
        super.init()
        
        self.name = "trajectory\(trajectory.id)"
        
        for i in 0..<trajectory.segments.count - 1 {
            let startKnot = trajectory.segments[i]
            let endKnot = trajectory.segments[i + 1]
            
            if currentTime >= endKnot.t {
                // This trajectory is in the past and should not be visualized
                continue
            }
            else if currentTime <= startKnot.t {
                // This trajectory is in the future and should be fully visualized
                addFullSegment(startKnot: startKnot, endKnot: endKnot, color: color, heightLevel: heightLevel)
            }
            else if currentTime > startKnot.t && currentTime < endKnot.t {
                // This trajectory is the current one and should be partially visualized based on current time
                addPartialSegment(startKnot: startKnot, endKnot: endKnot, currentTime: currentTime, color: color, heightLevel: heightLevel)
            }
        }
    }
    
    private func addFullSegment(startKnot: SplineKnot, endKnot: SplineKnot, color: UIColor, heightLevel: Int) {
        
        let directionVec = simd_float2(endKnot.x[0], endKnot.x[1]) - simd_float2(startKnot.x[0], startKnot.x[1])
        
        let edgeLength = length(directionVec)
        let midpoint = simd_float2(startKnot.x[0], startKnot.x[1]) + directionVec/2
        
        let theta = atan2(directionVec.y, directionVec.x)
        let edgeRotation = simd_quatf(angle: theta, axis: [0,0,1])
        
        let pathModel = ModelEntity(mesh: .generateBox(width: edgeLength, height: ARConstants.Trajectory.PATH_SIZE, depth: ARConstants.Trajectory.PATH_SIZE), materials: [SimpleMaterial(color: color, roughness: 1.0, isMetallic: false)])
        
        let z = ARConstants.Trajectory.Z_OFFSET + Float(heightLevel) * ARConstants.Trajectory.HEIGHT_LEVEL_STEP
        
        pathModel.components[Transform] = Transform(scale: [1,1,1], rotation: edgeRotation, translation: [midpoint.x, midpoint.y, z])
        
        self.addChild(pathModel, preservingWorldTransform: false)
    }
    
    private func addPartialSegment(startKnot: SplineKnot, endKnot: SplineKnot, currentTime: Int, color: UIColor, heightLevel: Int) {
         
        let splineCoefficients = getSplineCoefficients(startKnot: startKnot, endKnot: endKnot)
        
        let t = computeT(currentTime: currentTime, tInitial: splineCoefficients.initialTime, tFinal: splineCoefficients.finalTime)
        
        // Use spline coefficients to get position at current time
        let xPos = splineCoefficients.x.a * pow(t, 3) + splineCoefficients.x.b * pow(t, 2) + splineCoefficients.x.c * t + splineCoefficients.x.d
        let yPos = splineCoefficients.y.a * pow(t, 3) + splineCoefficients.y.b * pow(t, 2) + splineCoefficients.y.c * t + splineCoefficients.y.d
        let theta = splineCoefficients.th.a * pow(t, 3) + splineCoefficients.th.b * pow(t, 2) + splineCoefficients.th.c * t + splineCoefficients.th.d
        
        let intermediateKnot = SplineKnot(t: currentTime, v: startKnot.v, x: [xPos, yPos, theta])
    
        addFullSegment(startKnot: intermediateKnot, endKnot: endKnot, color: color, heightLevel: heightLevel)
    }
    
    private func computeT(currentTime: Int, tInitial: Int, tFinal: Int) -> Float {
        return Float(currentTime - tInitial) / Float(tFinal - tInitial)
    }
    
    private func getSplineCoefficients(startKnot: SplineKnot, endKnot: SplineKnot) -> SplineCoefficients {
        
        let x = computeCoefficients(initialPosition: startKnot.x[0], finalPosition: endKnot.x[0], initialVelocity: startKnot.v[0], finalVelocity: endKnot.v[0], initialTime: startKnot.t, finalTime: endKnot.t)
        
        let y = computeCoefficients(initialPosition: startKnot.x[1], finalPosition: endKnot.x[1], initialVelocity: startKnot.v[1], finalVelocity: endKnot.v[1], initialTime: startKnot.t, finalTime: endKnot.t)
        
        let th = computeCoefficients(initialPosition: startKnot.x[2], finalPosition: endKnot.x[2], initialVelocity: startKnot.v[2], finalVelocity: endKnot.v[2], initialTime: startKnot.t, finalTime: endKnot.t)
        
        return SplineCoefficients(x: x, y: y, th: th, initialTime: startKnot.t, finalTime: endKnot.t)
    }
    
    private func computeCoefficients(initialPosition x0: Float, finalPosition x1: Float, initialVelocity v0: Float, finalVelocity v1: Float, initialTime: Int, finalTime: Int) -> SplineCoefficients.Coefficients {
        let td = finalTime - initialTime
        let w0 = v0 / Float(td)
        let w1 = v1 / Float(td)
        
        let a = w1 + w0 - 2 * x1 + 2 * x0
        let b = -w1 - 2 * w0 + 3 * x1 - 3 * x0
        let c = w0
        let d = x0
        
        return SplineCoefficients.Coefficients(a: a, b: b, c: c, d: d)
    }
    
    private struct SplineCoefficients {
        let x: Coefficients
        let y: Coefficients
        let th: Coefficients
        
        let initialTime: Int
        let finalTime: Int
        
        struct Coefficients {
            let a: Float
            let b: Float
            let c: Float
            let d: Float
        }
    }
}
