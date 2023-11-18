//
//  Joints.swift
//  FormCheckerAR


import Foundation

enum Joints: CaseIterable {
    case head
    case spine1
    case spine2
    case hip
    case kneeRight
    case kneeLeft
    case footRight
    case footLeft
    case shoulderRight
    case shoulderLeft
    case elbowRight
    case elbowLeft
    case handRight
    case handLeft
    
    var jointString: String {
        switch self {
        case .head:
            return "head_joint"
        case .spine1:
            return "spine_3_joint"
        case .spine2:
            return "spine_6_joint"
        case . hip:
            return "hips_joint"
        case .kneeRight:
            return "right_leg_joint"
        case .kneeLeft:
            return "left_leg_joint"
        case .footRight:
            return "right_foot_joint"
        case .footLeft:
            return "left_foot_joint"
        case .shoulderRight:
            return "right_shoulder_1_joint"
        case .shoulderLeft:
            return "left_shoulder_1_joint"
        case .elbowRight:
            return "right_arm_joint"
        case .elbowLeft:
            return "left_arm_joint"
        case .handRight:
            return "right_hand_joint"
        case .handLeft:
            return "left_hand_joint"
        }
        
    }
}


