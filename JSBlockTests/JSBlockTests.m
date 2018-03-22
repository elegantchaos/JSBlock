// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 22/03/2018.
//  All code (c) 2018 - present day, Elegant Chaos Limited.
//  For licensing terms, see http://elegantchaos.com/license/liberal/.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

@import XCTest;
@import JavaScriptCore;

#include <JSBlock/JSBlock.h>

#define QUOTE(...) #__VA_ARGS__

/**
 Declare a block type and a method to call blocks of that type.
 */

#define DECLARE_CALL_TYPE(_type_) \
typedef _type_(^ _type_ ## Block)(_type_ t1, _type_ t2); \
- (_type_)callBlockWith ## _type_ :(_type_)v1 and ## _type_:(_type_)v2;

/**
 Define the method to take two arguments of a given type, and call a block with them.
 */

#define DEFINE_CALL_METHOD(_type_) \
- (_type_)callBlockWith ## _type_ :(_type_)v1 and ## _type_ :(_type_)v2 { \
_type_ ## Block block = self.block; \
return block(v1, v2); \
}

// MARK: - Example API

/**
 An example API which takes blocks of various types and does things with them.
 
 This intentionally takes a copy of the block (to prove that we can), stores a
 reference to it, then calls the block from a different method.
 */

@protocol ExampleAPIExports<JSExport>

typedef void(^VoidBlock)(double d, int i, NSString* s);

+ (instancetype)exampleWithBlock:(id)block;
- (void)callBlock:(double)d int:(int)i string:(NSString*)s;

DECLARE_CALL_TYPE(int)
DECLARE_CALL_TYPE(uint)
DECLARE_CALL_TYPE(double)
DECLARE_CALL_TYPE(char)
DECLARE_CALL_TYPE(bool)
DECLARE_CALL_TYPE(id)
DECLARE_CALL_TYPE(CGRect)

@end

@interface ExampleAPI : NSObject<ExampleAPIExports>
@property (copy, nonatomic, readonly) id block;
- (instancetype)initWithBlock:(id)block;
@end

@implementation ExampleAPI
- (instancetype)initWithBlock:(id)block {
    self = [super init];
    if (self) {
        _block = [block copy];
    }
    return self;
}

+ (instancetype)exampleWithBlock:(id)block {
    return [[self alloc] initWithBlock:block];
}

- (void)callBlock:(double)d int:(int)i string:(NSString*)s {
    VoidBlock block = self.block;
    block(d, i, s);
}

DEFINE_CALL_METHOD(double)
DEFINE_CALL_METHOD(int)
DEFINE_CALL_METHOD(uint)
DEFINE_CALL_METHOD(char)
DEFINE_CALL_METHOD(bool)
DEFINE_CALL_METHOD(id)
DEFINE_CALL_METHOD(CGRect)

@end

// MARK: - Testing

/**
 Define a javascript test for a given type.
 
 We define a javascript function which takes two arguments and applies an operation to them.
 This is passed to the example API as a block, and then a method on the API is called, which
 will invoke the block.
 
 As a convenience, we execute some Obj-C first to populate a global in the Javascript context with the correct block signature.
 In real code this would have to be supplied some other way (probably just manually).
 */

#define TEST(_type_, _code_, _arg1_, _arg2_) \
do { \
const char* _type_ ## sig = [JSBlock signatureForBlock:^ _type_(_type_ v1, _type_ v2) { return v1; }]; \
[self.context setObject:[JSValue valueWithObject:[NSString stringWithCString:_type_ ## sig encoding:NSASCIIStringEncoding] inContext:self.context] forKeyedSubscript:@"" #_type_ "BlockSignature"]; \
NSString* script = @QUOTE( \
var block = JSBlock.blockWithSignatureFunction(_type_ ## BlockSignature, function(x,y) { return _code_; }); \
var someAPI = ExampleAPI.exampleWithBlock(block); \
console.log(someAPI.callBlockWith ## _type_ ## And ## _type_(_arg1_, _arg2_)); \
); \
[self.context evaluateScript:script]; \
} while(0)

@interface JSBlockTests : XCTestCase
@property (strong, nonatomic) JSContext* context;
@property (strong, nonatomic) NSMutableString* buffer;
@end

@implementation JSBlockTests

- (void)setUp {
    // javascript context to run tests in
    JSContext* context = [JSContext new];
    
    // expose JSBlock and ExampleAPI
    context[@"JSBlock"] = [JSBlock class];
    context[@"ExampleAPI"] = [ExampleAPI class];
    
    // log any exceptions
    context.exceptionHandler = ^(JSContext* context, JSValue* exception) {
        NSLog(@"JS Error: %@", exception);
    };
    
    // install a console.log handler to capture output
    NSMutableString* buffer = [NSMutableString new];
    context[@"console"][@"log"] = ^(JSValue* value) {
        JSValueRef* exception = NULL;
        JSStringRef string = JSValueToStringCopy(value.context.JSGlobalContextRef, value.JSValueRef, exception);
        if (exception == NULL) {
            NSString* value = CFBridgingRelease(JSStringCopyCFString(NULL, string));
            NSLog(@"js> %@", value);
            [buffer appendFormat:@"%@\n", value];
        }
    };
    
    self.context = context;
    self.buffer = buffer;
}

- (NSString*)trimmedBuffer {
    return [_buffer stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)makeContext {
}

- (void)testDouble {
    TEST(double, x*y, 1.23, 4.0);
    XCTAssertEqualObjects(self.trimmedBuffer, @"4.92");
}

- (void)testInt {
    TEST(int, x+y, -2, -4);
    XCTAssertEqualObjects(self.trimmedBuffer, @"-6");
}

- (void)testUInt {
    TEST(uint, x+y, 2, 4);
    XCTAssertEqualObjects(self.trimmedBuffer, @"6");
}

- (void)testBool {
    TEST(bool, (x && y), true, true);
    TEST(bool, (x && y), false, true);
    XCTAssertEqualObjects(self.trimmedBuffer, @"true\nfalse");
}

- (void)testString {
    TEST(id, x + y, "test1", "test2");
    XCTAssertEqualObjects(self.trimmedBuffer, @"test1test2");
}

- (void)testStruct {
    TEST(CGRect, x + y, ({x:1, y:2}), ({x:1, y:2}));
    XCTAssertEqualObjects(self.trimmedBuffer, @"[object Object]");
}


@end
