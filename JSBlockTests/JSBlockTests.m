//
//  JSBlockTests.m
//  JSBlockTests
//
//  Created by Sam Deane on 22/03/2018.
//

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

/**
 Define a javascript test for a given type.
 
 We define a javascript function which takes two arguments and applies an operation to them.
 This is passed to the example API as a block, and then a method on the API is called, which
 will invoke the block.
 */

#define TEST(_type_, _code_, _arg1_, _arg2_) \
do { \
const char* _type_ ## sig = [JSBlock signatureForBlock:^ _type_(_type_ v1, _type_ v2) { return v1; }]; \
[context setObject:[JSValue valueWithObject:[NSString stringWithCString:_type_ ## sig encoding:NSASCIIStringEncoding] inContext:context] forKeyedSubscript:@"" #_type_ "BlockSignature"]; \
NSString* script = @QUOTE( \
var block = JSBlock.blockWithSignatureFunction(_type_ ## BlockSignature, function(x,y) { return _code_; }); \
var someAPI = ExampleAPI.exampleWithBlock(block); \
print(someAPI.callBlockWith ## _type_ ## And ## _type_(_arg1_, _arg2_)); \
); \
[context evaluateScript:script]; \
} while(0)


/**
 An example API which takes blocks of various types and does things with them.
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

NSMutableString* PrintBuffer = nil;

static void resetPrintBuffer(void) {
    PrintBuffer = [NSMutableString new];
}

static NSString* printBuffer(void) {
    return [PrintBuffer stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static JSValueRef printCallback(JSContextRef context, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
    for (NSUInteger n = 0; n < argumentCount; ++n) {
        JSStringRef string = JSValueToStringCopy(context, arguments[n], exception);
        if (*exception == NULL) {
            NSString* value = CFBridgingRelease(JSStringCopyCFString(NULL, string));
            NSLog(@"js> %@", value);
            [PrintBuffer appendFormat:@"%@\n", value];
        }
    }
    return JSValueMakeNull(context);
}


static JSContext* MakeTestContext(void) {
    JSContext* context = [JSContext new];
    context[@"JSBlock"] = [JSBlock class];
    context[@"ExampleAPI"] = [ExampleAPI class];
    
    context.exceptionHandler = ^(JSContext* context, JSValue* exception) {
        NSLog(@"JS Error: %@", exception);
    };
    
    JSStringRef printName = JSStringCreateWithUTF8CString(@"print".UTF8String);
    JSObjectRef print = JSObjectMakeFunctionWithCallback(context.JSGlobalContextRef, printName, printCallback);
    context[@"print"] = [JSValue valueWithJSValueRef:print inContext:context];
    JSStringRelease(printName);
    
    return context;
}

void test(void) {
    JSContext* context = MakeTestContext();
    
    
    NSString* script = @QUOTE(
                              var items = NSArray.arrayWithContentsOfArray([1,2]);
                              print(items);
                              );
    [context evaluateScript:script];
    
}


@interface JSBlockTests : XCTestCase

@end

@implementation JSBlockTests

- (void)setUp {
    resetPrintBuffer();
}

- (void)testDouble {
    JSContext* context = MakeTestContext();
    TEST(double, x*y, 1.23, 4.0);
    XCTAssertEqualObjects(printBuffer(), @"4.92");
}

- (void)testInt {
    JSContext* context = MakeTestContext();
    TEST(int, x+y, -2, -4);
    XCTAssertEqualObjects(printBuffer(), @"-6");
}

- (void)testUInt {
    JSContext* context = MakeTestContext();
    TEST(uint, x+y, 2, 4);
    XCTAssertEqualObjects(printBuffer(), @"6");
}

- (void)testBool {
    JSContext* context = MakeTestContext();
    TEST(bool, (x && y), true, true);
    TEST(bool, (x && y), false, true);
    XCTAssertEqualObjects(printBuffer(), @"true\nfalse");
}

- (void)testString {
    JSContext* context = MakeTestContext();
    TEST(id, x + y, "test1", "test2");
    XCTAssertEqualObjects(printBuffer(), @"test1test2");
}

- (void)testStruct {
    JSContext* context = MakeTestContext();
    TEST(CGRect, x + y, ({x:1, y:2}), ({x:1, y:2}));
    XCTAssertEqualObjects(printBuffer(), @"[object Object]");
}


@end
