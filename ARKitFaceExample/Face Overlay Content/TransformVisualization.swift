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
        self.udpSend(textToSend: faceAnchor.description, address: "192.168.1.126", inport: 54326)
    }
    
    func addEyeTransformNodes() {
        guard #available(iOS 12.0, *), let anchorNode = contentNode else { return }
        
        // Scale down the coordinate axis visualizations for eyes.
        rightEyeNode.simdPivot = float4x4(diagonal: [3, 3, 3, 1])
        leftEyeNode.simdPivot = float4x4(diagonal: [3, 3, 3, 1])
        
        anchorNode.addChildNode(rightEyeNode)
        anchorNode.addChildNode(leftEyeNode)
    }

    var fd: Int32 = 0

    deinit {
        if (fd != 0) {
            close(fd)
        }
    }

    func udpSend(textToSend: String, address: String, inport: UInt16) {
        if (fd == 0) {
            fd = socket(AF_INET, SOCK_DGRAM, 0) // DGRAM makes it UDP
        }

        var port = inport
        if (NSHostByteOrder() == NS_LittleEndian) {
            port = NSSwapShort(port)
        }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout.size(ofValue: addr))
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr(address)
        addr.sin_port = port

        textToSend.withCString { cstr -> () in
            var localCopy = addr

            withUnsafePointer(to: &localCopy) { pointer -> () in
                let memory = UnsafeRawPointer(pointer).bindMemory(to: sockaddr.self, capacity: 1)
                sendto(fd, cstr, strlen(cstr), 0, memory, socklen_t(addr.sin_len))
            }
        }
    }
}
