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
    let populatedPropertyName = JSStringCreateWithCFString("populatedByMoccaccino" as CFString)

    public override init() {
        var classDefinition : JSClassDefinition = JSClassDefinition()

        classDefinition.getProperty = { (context: JSContextRef?, object: JSObjectRef?, propertyName: JSStringRef?, exception: UnsafeMutablePointer<JSValueRef?>?) in
            let moccaccino = Unmanaged<Moccaccino>.fromOpaque(JSObjectGetPrivate(object)!).takeUnretainedValue()
            assert(moccaccino.context.jsGlobalContextRef == JSContextGetGlobalContext(context))
            let name = JSStringCopyCFString(kCFAllocatorDefault, propertyName) as String
            if let object = object {
                return moccaccino.getProperty(object: object, property: name, exception: exception)
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

    func getProperty(object: JSObjectRef, property: String, exception: UnsafeMutablePointer<JSValueRef?>?) -> JSValueRef? {
        if (!classesToIgnore.contains(property)) {
            if let objcClass : AnyClass = NSClassFromString(property) {
                return boxed(class: objcClass, exception: exception)
            }
        }
        
        return nil
    }
    
    func prototypeIsPopulated(prototype : JSObjectRef, context: JSContextRef, exception: UnsafeMutablePointer<JSValueRef?>?) -> Bool {
        let value = JSObjectGetProperty(context, prototype, populatedPropertyName, exception)
        return JSValueToBoolean(context, value)
    }
    
    func populatePrototype(prototype: JSObjectRef, class: AnyClass, context: JSContextRef, exception: UnsafeMutablePointer<JSValueRef?>?) {
        JSObjectSetProperty(context, prototype, populatedPropertyName, JSValueMakeBoolean(context, true), JSPropertyAttributes(kJSPropertyAttributeReadOnly), exception)
        let name = JSStringCreateWithCFString("test" as CFString)
        let method = JSObjectMakeFunctionWithCallback(context, name, { (context, function, this, argumentCount, arguments, exception) -> JSValueRef? in
            print("blah")
            return JSValueMakeNull(context)
        })
        JSObjectSetProperty(context, prototype, name, method, JSPropertyAttributes(kJSPropertyAttributeNone), exception)
    }
    
    func boxed(class: AnyClass, exception: UnsafeMutablePointer<JSValueRef?>?) -> JSValueRef? {
        let context = self.context.jsGlobalContextRef!
        if let value = JSValue(object: `class`, in: self.context) {
            if !class_conformsToProtocol(`class`, JSExport.self) {
                let classObject = value.jsValueRef as JSObjectRef
                if let proto = JSObjectGetPrototype(context, classObject) {
                    if (!prototypeIsPopulated(prototype: proto, context: context, exception: exception)) {
                        populatePrototype(prototype: proto, class: `class`, context: context, exception: exception)
                    }
                }
            }
            return value.jsValueRef;
        }
        return nil
    }
}
