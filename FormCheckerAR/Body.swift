//
//  Body.swift
//  FormCheckerAR
//
//  Created by Robert Zhang on 11/16/23.
//

import Foundation
import RealityKit
import ARKit

class Body: Entity {
    var joints: [String: Entity] = [:]
    var bones: [String: Entity] = [:]
    
    required init(for bodyAnchor: ARBodyAnchor) {
        super.init()
        
        for jointName in Joints.allCases {
            var jointRadius: Float = 0.02
            var jointColor: UIColor = .blue
            
            let jointEntity = createJoint(radius: jointRadius, color: jointColor)
            joints[jointName.jointString] = jointEntity
            self.addChild(jointEntity)
        }
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
    
    private func createJoint(radius: Float, color: UIColor = .white) -> Entity {
        let mesh = MeshResource.generateSphere(radius: radius)
        let material = SimpleMaterial(color: color, roughness: 0.8, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        
        return entity
    }
    
    func update(with bodyAnchor: ARBodyAnchor) {
        let rootPosition = simd_make_float3(bodyAnchor.transform.columns.3)
        
        for jointName in Joints.allCases {
            if let jointEntity = joints[jointName.jointString],
               let jointEntityTransform = bodyAnchor.skeleton.modelTransform(for: ARSkeleton.JointName(rawValue: jointName.jointString) ) {
                
                let jointEntityOffsetFromRoot = simd_make_float3(jointEntityTransform.columns.3)
                jointEntity.position = jointEntityOffsetFromRoot + rootPosition
                jointEntity.orientation = Transform(matrix: jointEntityTransform).rotation
            }
        }
    }
    
}
