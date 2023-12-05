//
//  Body.swift
//  FormCheckerAR
//
//  Created by Robert Zhang on 11/16/23.
//

import Foundation
import RealityKit
import ARKit

let matchSound = Bundle.main.path(forResource: "form_match", ofType: "mp3")
var matchAudio = AVAudioPlayer()

class Body: Entity {
    var joints: [String: ModelEntity] = [:]
    var jointsMatch: [String: Bool] = [:]
    var bones: [String: Entity] = [:]
    
    required init(for bodyAnchor: ARBodyAnchor) {
        super.init()
        
        var jointRadius: Float = 0.04
        var jointColor: UIColor = .blue
        let jointGroup = CollisionGroup(rawValue: 1 << 0)
//        let allButJointGroup = CollisionGroup.all.subtracting(jointGroup)
//        let jointFilter = CollisionFilter(group: jointGroup, mask: allButJointGroup)
        for jointName in Joints.allCases {
            let jointEntity = createJoint(radius: jointRadius, color: jointColor, name: jointName.jointString)
//            jointEntity.collision?.filter = jointFilter
            joints[jointName.jointString] = jointEntity
            jointsMatch[jointName.jointString] = false
            self.addChild(jointEntity)
        }
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
    
    private func createJoint(radius: Float, color: UIColor = .white, name: String) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: radius)
        let material = SimpleMaterial(color: color, roughness: 0.8, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = name
        entity.collision = CollisionComponent(shapes: [ShapeResource.generateSphere(radius: radius)])
        
        return entity
    }
    
    func update(with bodyAnchor: ARBodyAnchor) {
        let rootPosition = simd_make_float3(bodyAnchor.transform.columns.3)
        
        for jointName in Joints.allCases {
            if let jointEntity = joints[jointName.jointString],
               let jointEntityTransform = bodyAnchor.skeleton.modelTransform(for: ARSkeleton.JointName(rawValue: jointName.jointString)) {
                
                let jointEntityOffsetFromRoot = simd_make_float3(jointEntityTransform.columns.3)
                jointEntity.position = jointEntityOffsetFromRoot + rootPosition
                jointEntity.orientation = Transform(matrix: jointEntityTransform).rotation
            }
        }
        
        if jointsMatch.allSatisfy({$0.value == true}){
            do {
                matchAudio = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: matchSound!))
            }
            catch {
                print("DEBUG: can't play sound")
            }
            matchAudio.play()
        }
    }
    
}
