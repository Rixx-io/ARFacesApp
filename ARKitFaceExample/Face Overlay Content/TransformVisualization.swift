import ARKit
import SceneKit
import Foundation

class TransformVisualization: NSObject, VirtualContentController {
    var contentNode: SCNNode?
    var view: ViewController
    
    // Load multiple copies of the axis origin visualization for the transforms this class visualizes.
    lazy var rightEyeNode = SCNReferenceNode(named: "coordinateOrigin")
    lazy var leftEyeNode = SCNReferenceNode(named: "coordinateOrigin")
    
    init(_ inview: ViewController) {
        view = inview
        super.init()
        self.udpSetup()
    }

    /// - Tag: ARNodeTracking
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        // This class adds AR content only for face anchors.
        guard anchor is ARFaceAnchor else { return nil }
        
        // Load an asset from the app bundle to provide visual content for the anchor.
        contentNode = SCNReferenceNode(named: "coordinateOrigin")

        // Add content for eye tracking in iOS 12.
        self.addEyeTransformNodes()
        
        // Provide the node to ARKit for keeping in sync with the face anchor.
        return contentNode
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard #available(iOS 12.0, *), let faceAnchor = anchor as? ARFaceAnchor
            else { return }
        
        rightEyeNode.simdTransform = faceAnchor.rightEyeTransform
        leftEyeNode.simdTransform = faceAnchor.leftEyeTransform

        // NSLog(faceAnchor.description)
        // let pitch = asin(-faceAnchor.transform[2][1]) * (180/3.14156)
        // let yaw = atan2(faceAnchor.transform[2][0], faceAnchor.transform[2][2]) * (180/3.14156)
        // let roll = atan2(faceAnchor.transform[0][1], faceAnchor.transform[1][1]) * (180/3.14156)
        // self.udpSend(textToSend: faceAnchor.description)
        // print("\(faceAnchor.description)")
        self.udpSend(udpDescription(face: faceAnchor))
        // self.udpSend(textToSend: "Hello")

    }
    
    func addEyeTransformNodes() {
        guard #available(iOS 12.0, *), let anchorNode = contentNode else { return }
        
        anchorNode.simdPivot = float4x4(diagonal: [3, 3, 3, 5])

        // Scale down the coordinate axis visualizations for eyes.
        // rightEyeNode.simdPivot = float4x4(diagonal: [3, 3, 3, 1])
        // leftEyeNode.simdPivot = float4x4(diagonal: [3, 3, 3, 1])
        
        // anchorNode.addChildNode(rightEyeNode)
        // anchorNode.addChildNode(leftEyeNode)
    }


    func udpDescription(face: ARFaceAnchor) -> String {
        var d: [String: Any] = [:]

        func pry(_ transform: simd_float4x4) -> [Float] {
            let rad2deg = 180 / Float.pi
            let pitch = asin(-transform[2][1]) * rad2deg
            let roll = atan2(transform[0][1], transform[1][1]) * rad2deg
            let yaw = atan2(transform[2][0], transform[2][2]) * rad2deg
            return [pitch, roll, yaw]
        }

        func xyz(_ transform: simd_float4x4) -> [Float] {
            return [transform[3][0], transform[3][1], transform[3][2]]
        }

        d["identifier"] = "\(face.identifier)"
        d["tracked"] = face.isTracked

        d["translation"] = xyz(face.transform)
        d["orientation"] = pry(face.transform)

        d["lefteye"]  = ["orientation": pry(face.leftEyeTransform)]
        d["righteye"] = ["orientation": pry(face.rightEyeTransform)]
        d["lookatpoint"] = [face.lookAtPoint[0], face.lookAtPoint[1], face.lookAtPoint[2]]

        // https://developer.apple.com/documentation/arkit/arfaceanchor/2928251-blendshapes
        d["tongueout"] = face.blendShapes[.tongueOut]

        let j = try! JSONSerialization.data(withJSONObject: d, options: [])
        return String(data: j, encoding: .utf8)!
    }

    var finder: ServiceFinder?
    var connected = false
    var currentDest: Dest?

    func udpSetup() {
        finder = ServiceFinder("face-receiver")

        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { timer in
            let dest = self.finder!.bestDest()
            if (dest != nil) {
                if (!self.connected) {
                    self.connected = true
//                    self.view.connectionIndicator.text = "🟢"
                }
            } else {
                if (self.connected) {
                    self.connected = false
//                    self.view.connectionIndicator.text = "🔴"
                }
                
            }
            self.udpSend("ping")
        }
    }

    func udpSend(_ textToSend: String) {
        let bestDest = finder!.bestDest()
        if (bestDest !== currentDest) {
            currentDest = bestDest
            if (currentDest != nil) {
                print("Connected to \(currentDest!.ip):\(currentDest!.port)")
            } else {
                print("No connection!")
            }
        }
        if (currentDest == nil) {
            return
        }

        textToSend.withCString { cstr -> () in
            var localCopy = currentDest!.sock

            withUnsafePointer(to: &localCopy) { pointer -> () in
                let memory = UnsafeRawPointer(pointer).bindMemory(to: sockaddr.self, capacity: 1)
                sendto(currentDest!.fd, cstr, strlen(cstr), 0, memory, socklen_t(currentDest!.sock.sin_len))
            }
        }
    }
}
