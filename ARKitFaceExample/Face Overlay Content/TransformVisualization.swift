/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Displays coordinate axes visualizing the tracked face pose (and eyes in iOS 12).
*/

import ARKit
import SceneKit
import Foundation

class TransformVisualization: NSObject, VirtualContentController {
    var contentNode: SCNNode?

    let destIP = "192.168.50.25"
    let destPort: UInt16 = 54326

    // Load multiple copies of the axis origin visualization for the transforms this class visualizes.
    lazy var rightEyeNode = SCNReferenceNode(named: "coordinateOrigin")
    lazy var leftEyeNode = SCNReferenceNode(named: "coordinateOrigin")
    
    /// - Tag: ARNodeTracking
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        // This class adds AR content only for face anchors.
        guard anchor is ARFaceAnchor else { return nil }
        
        // Load an asset from the app bundle to provide visual content for the anchor.
        contentNode = SCNReferenceNode(named: "coordinateOrigin")

        // Add content for eye tracking in iOS 12.
        self.addEyeTransformNodes()

        self.udpSetup(address: destIP, inport: destPort)

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
        self.udpSend(textToSend: faceAnchor.description, address: "172.20.10.2", inport: 54326)
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

    var fd: Int32 = 0
    var dest = sockaddr_in()

    deinit {
        if (fd != 0) {
            close(fd)
        }
    }

    func udpSetup(address: String, inport: UInt16) {
        fd = socket(AF_INET, SOCK_DGRAM, 0) // DGRAM makes it UDP

        var port = inport
        if (NSHostByteOrder() == NS_LittleEndian) {
            port = NSSwapShort(port)
        }

        dest.sin_len = UInt8(MemoryLayout.size(ofValue: dest))
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_addr.s_addr = inet_addr(address)
        dest.sin_port = port
    }

    func udpSend(textToSend: String, address: String, inport: UInt16) {
        textToSend.withCString { cstr -> () in
            var localCopy = dest

            withUnsafePointer(to: &localCopy) { pointer -> () in
                let memory = UnsafeRawPointer(pointer).bindMemory(to: sockaddr.self, capacity: 1)
                sendto(fd, cstr, strlen(cstr), 0, memory, socklen_t(dest.sin_len))
            }
        }
    }
}
