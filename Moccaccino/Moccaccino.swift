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
        let classInstance = JSClassCreate(&classDefinition)
        let globalContext = JSGlobalContextCreate(classInstance)
        self.context = JSContext(jsGlobalContextRef: globalContext)
    }
    
    @objc public func test() {
        
    }
}
//
//JSContext* globalContext = nil;
//
//JSValueRef GlobalGetProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
//    NSString *name = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, propertyName));
//    if (![name isEqualToString:@"Object"]) {
//        Class class = NSClassFromString(name);
//        if (class) {
//            JSValue* value = [JSValue valueWithObject:class inContext:globalContext];
//            return value.JSValueRef;
//        }
//    }
//
//    return NULL;
//}
//
//
//JSContext* ContextWithCustomGlobalClass() {
//    JSClassDefinition globalClass;
//    memset(&globalClass, 0, sizeof(globalClass));
//    globalClass.getProperty = GlobalGetProperty;
//
//    JSClassRef class = JSClassCreate(&globalClass);
//    JSGlobalContextRef context = JSGlobalContextCreate(class);
//    globalContext =  [JSContext contextWithJSGlobalContextRef:context]; // this needs to be a lookup table
//    return globalContext;
//}
