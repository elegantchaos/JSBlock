//
//  Moccaccino.swift
//  JSBlock
//
//  Created by Sam Deane on 23/03/2018.
//

import Cocoa
import JavaScriptCore

/**
 Minimalist replacement for Mocha.
 
 Attempts to use the modern JavaSwiftCore facilities to do as much of
 the bridging as possible.
 */

@objc public class Moccaccino : NSObject {
    @objc public var context : JSContext
    
    let classesToIgnore = Set(["Object"])
    
    public override init() {
        var classDefinition : JSClassDefinition = JSClassDefinition()

        classDefinition.getProperty = { (context: JSContextRef?, object: JSObjectRef?, propertyName: JSStringRef?, exception: UnsafeMutablePointer<JSValueRef?>?) in
            let moccaccino = Unmanaged<Moccaccino>.fromOpaque(JSObjectGetPrivate(object)!).takeUnretainedValue()
            let name = JSStringCopyCFString(kCFAllocatorDefault, propertyName) as String
            if (!moccaccino.classesToIgnore.contains(name)) {
                if let objcClass : AnyClass = NSClassFromString(name) {
                    if let value = JSValue(object: objcClass, in: moccaccino.context) {
                        if !class_conformsToProtocol(objcClass, JSExport.self) {
                            
                            if let prototype = value.forProperty("prototype") {
                                let name = JSStringCreateWithCFString("test" as CFString)
//                                let method = JSObjectMakeFunctionWithCallback(moccaccino.context.jsGlobalContextRef, name, { (context, function, this, argumentCount, arguments, exception) -> JSValueRef? in
//                                    print("blah")
//                                    return JSValueMakeNull(context)
//                                })
                                let testFunc : @convention(block) () -> () = {
                                    print("blah")
                                    
                                }
//                                prototype.setValue(JSValue(jsValueRef: method, in: moccaccino.context), forProperty: "test")
                                prototype.setValue(JSValue(object: testFunc, in: moccaccino.context), forProperty: "test")
                                print("\(prototype)")
                                JSObjectSetPrototype(moccaccino.context.jsGlobalContextRef, value.jsValueRef, prototype.jsValueRef)
                            }
                        }
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
