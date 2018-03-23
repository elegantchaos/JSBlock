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
        
        classDefinition.getProperty = { (context: JSContextRef?, object: JSObjectRef?, propertyName: JSStringRef?, exception: UnsafeMutablePointer<JSValueRef?>?) in
            let name = JSStringCopyCFString(kCFAllocatorDefault, propertyName) as String
            if (name != "Object") {
                if let objcClass : AnyObject = NSClassFromString(name) {
                    if let value = JSValue(object: objcClass, in: Moccaccino.globalContext) {
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
    }
    
    @objc public func test() {
        
    }
}
