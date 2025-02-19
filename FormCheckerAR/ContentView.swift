//
//  ContentView.swift
//  FormCheckerAR


import SwiftUI
import RealityKit
import ARKit
import Foundation
import FocusEntity
import Combine
import AVFoundation

struct ContentView : View {
    
    @State private var isPlacementEnabled = false
    @State private var selectedModel: Model?
    @State private var modelConfirmedForPlacement: Model?
    
    @State private var modelLoaded = false
    
    private var models: [Model] = {
        // Dynamically get file names
        let filemanager = FileManager.default
        
        guard let path = Bundle.main.resourcePath, let files = try? filemanager.contentsOfDirectory(atPath: path) else {
            return []
        }
        
        var availableModels: [Model] = []
        for filename in files where filename.hasSuffix("usdz")  {
            let modelName = filename.replacingOccurrences(of: ".usdz", with: "")
            let model = Model(modelName: modelName)
            availableModels.append(model)
        }
        
        return availableModels
    }()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(modelConfirmedForPlacement: self.$modelConfirmedForPlacement, modelLoaded: self.$modelLoaded).edgesIgnoringSafeArea(.all)
            
            if self.isPlacementEnabled {
                PlacementButtonsView(isPlacementEnabled: self.$isPlacementEnabled, selectedModel: self.$selectedModel, modelConfirmedForPlacement: self.$modelConfirmedForPlacement)
            }
                else  {
                    ModelPickerView(isPlacementEnabled: self.$isPlacementEnabled,
                        selectedModel: self.$selectedModel, modelLoaded: self.$modelLoaded,
                                    models: self.models)
                }
            }
        }
       
    }

private var bodySkeleton: Body?
private let bodySkeletonAnchor = AnchorEntity()

private var joints: [String:Entity] = [:]
private var collisionSubs: [AnyCancellable] = []

let loadSound = Bundle.main.path(forResource: "model_placed", ofType: "mp3")
var loadAudio = AVAudioPlayer()

let guidance = AVSpeechSynthesizer()

struct ARViewContainer: UIViewRepresentable {
    
    @Binding var modelConfirmedForPlacement: Model?
    
    @Binding var modelLoaded: Bool
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = CustomARView(frame: .zero)
        
        let config = arView.setupARView()
        arView.session.run(config)
        
        return arView
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        if let model = self.modelConfirmedForPlacement {
            if let modelEntity = model.modelEntity {
                print("DEBUG: adding model to scene - \(model.modelName)")
                for anchor in uiView.scene.anchors {
                    if anchor.name == "model_anchor" {
                        uiView.scene.removeAnchor(anchor)
                    }
                }
                
                var material = PhysicallyBasedMaterial()
                material.blending = .transparent(opacity: .init(floatLiteral: 0.6))
                modelEntity.model?.materials[0] = material
                modelEntity.collision = CollisionComponent(shapes: [ShapeResource.generateConvex(from: modelEntity.model!.mesh)])
                
                let anchorEntity = AnchorEntity(plane: .horizontal) // error will be fixed once iphone is attached
                anchorEntity.name = "model_anchor"
                modelEntity.name = "model"
                anchorEntity.addChild(modelEntity)
                uiView.scene.addAnchor(anchorEntity)
                
                var jointCollisionSubscriptionBeg:AnyCancellable
                var jointCollisionSubscriptionEnd:AnyCancellable
                
                jointCollisionSubscriptionBeg = uiView.scene.subscribe(
                    to: CollisionEvents.Began.self,
                    on: modelEntity
                ) { event in
                    DispatchQueue.main.async {
                        print("DEBUG: collision occurred")
                        let mEntity = event.entityA as? ModelEntity
                        let jEntity = event.entityB as? ModelEntity
                    
                    
                        jEntity?.model?.materials = [SimpleMaterial(color: .green, roughness: 0.8, isMetallic: false)]
                        
                        bodySkeleton?.jointsMatch[jEntity!.name] = true

                    }
                } as! AnyCancellable
                        
                jointCollisionSubscriptionEnd = uiView.scene.subscribe(
                    to: CollisionEvents.Ended.self,
                    on: modelEntity
                ) { event in
                    DispatchQueue.main.async {
                        print("DEBUG: collision ended")
                        let mEntity = event.entityA as? ModelEntity
                        let jEntity = event.entityB as? ModelEntity
                    
                    
                        jEntity?.model?.materials = [SimpleMaterial(color: .blue, roughness: 0.8, isMetallic: false)]
                        
                        bodySkeleton?.jointsMatch[jEntity!.name] = false

                    }
                } as! AnyCancellable
                
                jointCollisionSubscriptionBeg.store(in: &collisionSubs)
                jointCollisionSubscriptionEnd.store(in: &collisionSubs)
                
            } else {
                print("DEBUG: unable to load modelEntity for \(model.modelName)")
            }
            
            DispatchQueue.main.async {
                self.modelConfirmedForPlacement = nil
                self.modelLoaded = true
            }
            
        }
        if self.modelLoaded {
            do {
                loadAudio = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: loadSound!))
            }
            catch {
                print("DEBUG: can't play sound")
            }
            loadAudio.play()
            
            uiView.setupForBodyTracking()
            uiView.scene.addAnchor(bodySkeletonAnchor)
      
            let modelAnchor = uiView.scene.anchors.first(where: {$0.name == "model_anchor"})
            
            Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { timer in
//                let bodyAnchor = uiView.scene.anchors[uiView.scene.anchors.count - 1]
                let bodyAnchor = bodySkeleton?.joints["hips_joint"]
                let dstABS = distanceBetweenEntitiesABS(bodyAnchor?.position(relativeTo: nil) ?? [0, 0, 0], and: (modelAnchor?.position(relativeTo: nil))!)
                let dst = distanceBetweenEntities(bodyAnchor?.position(relativeTo: nil) ?? [0, 0, 0], and: (modelAnchor?.position(relativeTo: nil))!)

                print("Distance: \(dst)")
                let max = dstABS.max()
                let dstABSArr = [dstABS.x, dstABS.y, dstABS.z]
                let dstArr = [dst.x, dst.y, dst.z]
                let index = dstABSArr.firstIndex(of: max)
                let utterance = getUtterance(for: index ?? 4, in: dstABSArr, in: dstArr, in: dstABS)
                let voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.siri_female_en-AU_compact")
                utterance.voice = voice
                guidance.speak(utterance)
            }
    
        }
    }
}

private func distanceBetweenEntitiesABS(_ a: SIMD3<Float>,
                                       and b: SIMD3<Float>) -> SIMD3<Float> {
        
        var distance: SIMD3<Float> = [0, 0, 0]
        distance.x = abs(a.x - b.x)
        distance.y = abs(a.y - b.y)
        distance.z = abs(a.z - b.z)
        return distance
    }

private func getUtterance(for index: Int, in dstABSArr: [Float], in dstArr: [Float], in dstABS: SIMD3<Float>) -> AVSpeechUtterance {
    var text: String
    var utterance: AVSpeechUtterance = AVSpeechUtterance(string: "")
    switch index {
    case 0:
        if dstArr[index] > 0.07 {
            text = "Move to your right"
            utterance = AVSpeechUtterance(string: text)
        }
        else if dstArr[index] < -0.07 {
            text = "Move to your left"
            utterance = AVSpeechUtterance(string: text)
        }
    case 1:
        if dstArr[index] < 0.65 {
            text = "Raise your body"
            utterance = AVSpeechUtterance(string: text)
        }
        else if dstArr[index] > 0.8 {
            text = "Lower your body"
            utterance = AVSpeechUtterance(string: text)
        }
        else {
            let newIndex = dstABSArr.firstIndex(of: [dstABS.x, dstABS.z].max()!)
            utterance = getUtterance(for: newIndex ?? 0, in: dstABSArr, in: dstArr, in: dstABS)
        }
    case 2:
        if dstArr[index] > 0.04 {
            text = "Take a step backwards"
            utterance = AVSpeechUtterance(string: text)
        }
        else if dstArr[index] < -0.09
        {
            text = "Take a step towards the camera"
            utterance = AVSpeechUtterance(string: text)
        }
    default:
        text = "Move into camera frame"
        utterance = AVSpeechUtterance(string: text)
        print("DEBUG: Can't get distance between model and body")
    }
    
    return utterance
}

private func distanceBetweenEntities(_ a: SIMD3<Float>,
                                       and b: SIMD3<Float>) -> SIMD3<Float> {
        
        var distance: SIMD3<Float> = [0, 0, 0]
        distance.x = (a.x - b.x)
        distance.y = (a.y - b.y)
        distance.z = (a.z - b.z)
        return distance
    }

extension ARView: ARSessionDelegate {
    func setupForBodyTracking() {
        let configuration = ARBodyTrackingConfiguration()
        self.session.run(configuration)
        
        self.session.delegate = self
    }
    
    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let bodyAnchor = anchor as? ARBodyAnchor {
                if let skeleton = bodySkeleton {
                    skeleton.update(with: bodyAnchor)
                } else {
                    bodySkeleton = Body(for: bodyAnchor)
                    bodySkeletonAnchor.addChild(bodySkeleton!)
//                    print(self.scene.anchors)
                }
            }
        }
        
    }
}

class CustomARView: ARView {
    
    let focusSquare = FESquare()
    
    required init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        
        focusSquare.viewDelegate = self
        focusSquare.delegate = self
        focusSquare.setAutoUpdate(to: true)

    }
    
    
    @objc required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder: ) has not been implemented")
    }
    
    func setupARView() -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        
        return config
    }
}

extension CustomARView: FEDelegate {
    func toTrackingState() {
        
//        print("tracking")
        return
    }
    
    func toInitializingState() {
//        print("initializing")
    }
}

struct ModelPickerView: View {
    
    @Binding var isPlacementEnabled: Bool
    @Binding var selectedModel: Model?
    
    @Binding var modelLoaded: Bool
    
    var models: [Model]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 30) {
                ForEach(0 ..< self.models.count) {
                    index in
                    Button(action: {
                        print("DEBUG: selected model with name: \(self.models[index].modelName)")
                        self.isPlacementEnabled = true
                        self.selectedModel = self.models[index]
                        self.modelLoaded = false
                    }) {
                        Image(uiImage: self.models[index].image)
                            .resizable()
                            .frame(height: 80)
                            .aspectRatio(1/1, contentMode: .fit)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                        
                }
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.5))
    }
}

struct PlacementButtonsView: View {
    
    @Binding var isPlacementEnabled: Bool
    @Binding var selectedModel: Model?
    @Binding var modelConfirmedForPlacement: Model?
    
    var body: some View {
        HStack {
            // Cancel Button
            Button(action: {
                print("DEBUG: Cancel model placement.")
                self.resetPlacementParameters()
            }) {
                Image(systemName: "xmark")
                    .frame(width: 60, height: 60)
                    .font(.title)
                    .background(Color.white.opacity(0.75))
                    .cornerRadius(30)
                    .padding(20)
            }
            
            // Confirm Button
            Button(action: {
                print("DEBUG: model placement confirmation.")
                
                self.modelConfirmedForPlacement = self.selectedModel
                self.resetPlacementParameters()
            })  {
                Image(systemName: "checkmark")
                    .frame(width: 60, height: 60)
                    .font(.title)
                    .background(Color.white.opacity(0.75))
                    .cornerRadius(30)
                    .padding(20)
            }
        }
    }
    
    func resetPlacementParameters() {
        self.isPlacementEnabled = false
        self.selectedModel = nil
    }
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
