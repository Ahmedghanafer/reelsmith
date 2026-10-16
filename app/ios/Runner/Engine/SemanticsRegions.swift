#if DEBUG
import ObjectiveC
import UIKit

/// Makes a Flutter semantics container with an identifier one element that holds its children, as a container of
/// SwiftUI with `accessibilityElement(children: .contain)` was in `m6`, so a UI test finds a control among the
/// descendants of its region.
///
/// Flutter's iOS embedder puts a node with children in a `SemanticsObjectContainer` that has no identifier and the
/// frame of the screen, and lays the node itself beside its children as the container's first element. For a node
/// with an identifier that is no element of its own (no label, value, hint or action), the container takes the
/// node's identifier and frame, and the node gives up its identifier, so the identifier is found once. Debug builds
/// only, the build the UI tests run.
///
/// https://developer.apple.com/documentation/objectivec/1418707-class_replacemethod
/// https://developer.apple.com/documentation/objectivec/1418587-imp_implementationwithblock
/// https://developer.apple.com/documentation/uikit/uiaccessibilityidentification/accessibilityidentifier
/// https://developer.apple.com/documentation/objectivec/nsobject/1615111-accessibilityframe
/// https://github.com/flutter/flutter/blob/3.47.7/engine/src/flutter/shell/platform/darwin/ios/framework/Source/SemanticsObject.mm
enum SemanticsRegions {
    private typealias Identifier = @convention(c) (AnyObject, Selector) -> NSString?
    private typealias Frame = @convention(c) (AnyObject, Selector) -> CGRect

    /// Called once, at the launch.
    static func install() {
        let identifier = NSSelectorFromString("accessibilityIdentifier")
        let frame = NSSelectorFromString("accessibilityFrame")
        guard let object: AnyClass = NSClassFromString("SemanticsObject"),
            let container: AnyClass = NSClassFromString("SemanticsObjectContainer"),
            let objectIdentifier = class_getInstanceMethod(object, identifier),
            let containerIdentifier = class_getInstanceMethod(container, identifier),
            let containerFrame = class_getInstanceMethod(container, frame)
        else {
            print("semantics regions: the classes of the embedder were not found")
            return
        }
        let ownIdentifier = unsafeBitCast(method_getImplementation(objectIdentifier), to: Identifier.self)
        let otherIdentifier = unsafeBitCast(method_getImplementation(containerIdentifier), to: Identifier.self)
        let screenFrame = unsafeBitCast(method_getImplementation(containerFrame), to: Frame.self)

        /// The identifier of a node with children that is no element of its own, else nil.
        func regionIdentifier(of node: AnyObject) -> NSString? {
            guard let node = node as? NSObject, !node.isAccessibilityElement,
                (node.value(forKey: "hasChildren") as? Bool) == true,
                let name = ownIdentifier(node, identifier), name.length > 0
            else {
                return nil
            }
            return name
        }

        let nodeBlock: @convention(block) (AnyObject) -> NSString? = { node in
            regionIdentifier(of: node) == nil ? ownIdentifier(node, identifier) : nil
        }
        class_replaceMethod(
            object, identifier, imp_implementationWithBlock(nodeBlock), method_getTypeEncoding(objectIdentifier))

        let containerBlock: @convention(block) (AnyObject) -> NSString? = { holder in
            if let node = (holder as? NSObject)?.value(forKey: "semanticsObject") as? NSObject,
                let name = regionIdentifier(of: node)
            {
                return name
            }
            return otherIdentifier(holder, identifier)
        }
        class_replaceMethod(
            container, identifier, imp_implementationWithBlock(containerBlock),
            method_getTypeEncoding(containerIdentifier))

        let frameBlock: @convention(block) (AnyObject) -> CGRect = { holder in
            if let node = (holder as? NSObject)?.value(forKey: "semanticsObject") as? NSObject,
                regionIdentifier(of: node) != nil
            {
                return node.accessibilityFrame
            }
            return screenFrame(holder, frame)
        }
        class_replaceMethod(
            container, frame, imp_implementationWithBlock(frameBlock), method_getTypeEncoding(containerFrame))
    }
}
#endif
