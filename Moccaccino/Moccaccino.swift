//
//  Moccaccino.swift
//  JSBlock
//
//  Created by Sam Deane on 23/03/2018.
//

import Cocoa
import JavaScriptCore


@objc public class Moccaccino : NSObject {
    @objc public var context : JSContext
    
    public override init() {
        var classDefinition : JSClassDefinition = JSClassDefinition()

        classDefinition.getProperty = { (context: JSContextRef?, object: JSObjectRef?, propertyName: JSStringRef?, exception: UnsafeMutablePointer<JSValueRef?>?) in
            let name = JSStringCopyCFString(kCFAllocatorDefault, propertyName) as String
            if (name != "Object") {
                if let objcClass : AnyObject = NSClassFromString(name) {
                    let moccaccino = Unmanaged<Moccaccino>.fromOpaque(JSObjectGetPrivate(object)!).takeUnretainedValue()
                    if let value = JSValue(object: objcClass, in: moccaccino.context) {
                        return value.jsValueRef;
                    }
                }
            }
            
            return nil
        }
        
        let classInstance = JSClassCreate(&classDefinition)
        let globalContext = JSGlobalContextCreate(classInstance)
        self.context = JSContext(jsGlobalContextRef: globalContext)

        super.init()

        // store reference to self as the private data for the global object, so that we can retrieve it in callbacks
        let global = JSContextGetGlobalObject(globalContext)
        JSObjectSetPrivate(global, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
    }
    
    @objc public func test() {
        
    }
}
