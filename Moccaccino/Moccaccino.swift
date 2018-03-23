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
    
    static var globalContext : JSContext? = nil
    
    public override init() {
        var classDefinition : JSClassDefinition = JSClassDefinition()
        
//        classDefinition.initialize = { (context: JSContextRef?, object: JSObjectRef?) in
//            _ = withUnsafeMutablePointer(to: &Moccaccino.globalContext, {
//                JSObjectSetPrivate(object, $0)
//            })
//        }
//
        classDefinition.getProperty = { (context: JSContextRef?, object: JSObjectRef?, propertyName: JSStringRef?, exception: UnsafeMutablePointer<JSValueRef?>?) in
            let name = JSStringCopyCFString(kCFAllocatorDefault, propertyName) as String
            if (name != "Object") {
                if let objcClass : AnyObject = NSClassFromString(name) {
                    let data = JSObjectGetPrivate(object)
                    let context = Unmanaged<JSContext>.fromOpaque(data!).takeUnretainedValue()
                    if let value = JSValue(object: objcClass, in: context) {
                        return value.jsValueRef;
                    }
                }
            }
            
            return nil
        }
        
        let classInstance = JSClassCreate(&classDefinition)
        let globalContext = JSGlobalContextCreate(classInstance)
        self.context = JSContext(jsGlobalContextRef: globalContext)
        Moccaccino.globalContext = context
        let global = JSContextGetGlobalObject(globalContext)
//        _ = withUnsafeMutablePointer(to: &context, {
//            JSObjectSetPrivate(global, $0)
//        })
        JSObjectSetPrivate(global, UnsafeMutableRawPointer(Unmanaged.passUnretained(context).toOpaque()))

    }
    
    @objc public func test() {
        
    }
}
