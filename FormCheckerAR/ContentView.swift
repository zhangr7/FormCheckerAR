//
//  ContentView.swift
//  FormCheckerAR


import SwiftUI
import RealityKit
import ARKit
import Foundation
import FocusEntity

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

struct ARViewContainer: UIViewRepresentable {
    
    @Binding var modelConfirmedForPlacement: Model?
    
    @Binding var modelLoaded: Bool
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = CustomARView(frame: .zero)
        
        if !self.modelLoaded {
            let config = arView.setupARView()
            arView.session.run(config)
        }
        else {
            arView.setupForBodyTracking()
            arView.scene.addAnchor(bodySkeletonAnchor)
        }
       
        
        return arView
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        if let model = self.modelConfirmedForPlacement {
            if let modelEntity = model.modelEntity {
                print("DEBUG: adding model to scene - \(model.modelName)")
                
                let anchorEntity = AnchorEntity(plane: .horizontal) // error will be fixed once iphone is attached
                anchorEntity.addChild(modelEntity)
                
                uiView.scene.addAnchor(anchorEntity)
            } else {
                print("DEBUG: unable to load modelEntity for \(model.modelName)")
            }
            
            DispatchQueue.main.async {
                self.modelConfirmedForPlacement = nil
                self.modelLoaded = true
            }
    
        }
        if self.modelLoaded {
            uiView.setupForBodyTracking()
            uiView.scene.addAnchor(bodySkeletonAnchor)
        }
    }
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
        
        let config = self.setupARView()
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
        print("tracking")
    }
    
    func toInitializingState() {
        print("initializing")
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
