// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 22/03/2018.
//  All code (c) 2018 - present day, Elegant Chaos Limited.
//  For licensing terms, see http://elegantchaos.com/license/liberal/.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/**
 The code in here looks a bit scary, but 90% of it is just dedicated to setting up
 an example API and a set of unit tests.
 */

@import XCTest;
@import JavaScriptCore;
@import Moccaccino;

#import <JSBlock/JSBlock.h>

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

DECLARE_CALL_TYPE(NSInteger)
DECLARE_CALL_TYPE(NSUInteger)
DECLARE_CALL_TYPE(int)
DECLARE_CALL_TYPE(uint)
DECLARE_CALL_TYPE(double)
DECLARE_CALL_TYPE(char)
DECLARE_CALL_TYPE(bool)
DECLARE_CALL_TYPE(id)
DECLARE_CALL_TYPE(CGRect)
DECLARE_CALL_TYPE(CGPoint)
DECLARE_CALL_TYPE(CGSize)
DECLARE_CALL_TYPE(NSRange)

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

DEFINE_CALL_METHOD(NSInteger)
DEFINE_CALL_METHOD(NSUInteger)
DEFINE_CALL_METHOD(int)
DEFINE_CALL_METHOD(uint)
DEFINE_CALL_METHOD(double)
DEFINE_CALL_METHOD(char)
DEFINE_CALL_METHOD(bool)
DEFINE_CALL_METHOD(id)
DEFINE_CALL_METHOD(CGRect)
DEFINE_CALL_METHOD(CGPoint)
DEFINE_CALL_METHOD(CGSize)
DEFINE_CALL_METHOD(NSRange)

@end


// MARK: - Testing

/**
 Macro to define a javascript test for a given type.
 
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
    var block = JSBlock.blockWithSignatureFunction(_type_ ## BlockSignature, function(x,y) { _code_; }); \
    var someAPI = ExampleAPI.exampleWithBlock(block); \
    var result = someAPI.callBlockWith ## _type_ ## And ## _type_(_arg1_, _arg2_); \
    console.log(result); \
); \
[self.context evaluateScript:script]; \
} while(0)

@interface JSBlockTests : XCTestCase
@property (strong, nonatomic) Moccaccino* engine;
@property (strong, nonatomic) JSContext* context;
@property (strong, nonatomic) NSMutableString* buffer;
@end

@implementation JSBlockTests

- (void)setUp {
    // javascript context to run tests in
    Moccaccino* engine = [Moccaccino new];
    [engine test];
    JSContext* context = engine.context;
    
    // log any exceptions
    context.exceptionHandler = ^(JSContext* context, JSValue* exception) {
        NSLog(@"JS Error: %@", exception);
    };
    
    // install a console.log handler to capture output
    NSMutableString* buffer = [NSMutableString new];
    context[@"console"][@"log"] = ^(JSValue* value) {
        NSLog(@"js> %@", value);
        [buffer appendFormat:@"%@\n", value.toString];
    };
    
    self.engine = engine;
    self.context = context;
    self.buffer = buffer;
}

- (NSString*)trimmedBuffer {
    return [_buffer stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)testCall {
    [self.context evaluateScript:@QUOTE(
                                        var s = NSApplication;
                                        var s2 = NSApplication();
                                        s.test();
                                        var p = s.prototype;
                                        p.test2 = function() { console.log("blah2"); };
                                        s.test2();
                                        )];
}

- (void)testDouble {
    TEST(double, return x*y, 1.23, 4.0);
    XCTAssertEqualObjects(self.trimmedBuffer, @"4.92");
}

- (void)testNSInteger {
    TEST(NSInteger, return x+y, -2, -4);
    XCTAssertEqualObjects(self.trimmedBuffer, @"-6");
}

- (void)testNSUInteger {
    TEST(NSUInteger, return x+y, 2, 4);
    XCTAssertEqualObjects(self.trimmedBuffer, @"6");
}

- (void)testInt {
    TEST(int, return x+y, -2, -4);
    XCTAssertEqualObjects(self.trimmedBuffer, @"-6");
}

- (void)testUInt {
    TEST(uint, return x+y, 2, 4);
    XCTAssertEqualObjects(self.trimmedBuffer, @"6");
}

- (void)testBool {
    TEST(bool, return (x && y), true, true);
    TEST(bool, return (x && y), false, true);
    XCTAssertEqualObjects(self.trimmedBuffer, @"true\nfalse");
}

- (void)testString {
    TEST(id, return x + y, "test1", "test2");
    XCTAssertEqualObjects(self.trimmedBuffer, @"test1test2");
}

- (void)testRect {
    TEST(CGRect, return ({x:x.x + y.x, y:x.y + y.y, width:x.width + y.width, height:x.height+y.height}), ({x:1, y:2, width:10, height:10}), ({x:4, y:8, width:20, height:20}));
    [self.context evaluateScript:@"console.log(result.x);"];
    [self.context evaluateScript:@"console.log(result.y);"];
    [self.context evaluateScript:@"console.log(result.width);"];
    [self.context evaluateScript:@"console.log(result.height);"];
    XCTAssertEqualObjects(self.trimmedBuffer, @"[object Object]\n5\n10\n30\n30");
}

- (void)testPoint {
    TEST(CGPoint, return ({x:x.x + y.x, y:x.y + y.y}), ({x:1, y:2}), ({x:4, y:8}));
    [self.context evaluateScript:@"console.log(result.x);"];
    [self.context evaluateScript:@"console.log(result.y);"];
    XCTAssertEqualObjects(self.trimmedBuffer, @"[object Object]\n5\n10");
}

- (void)testSize {
    TEST(CGSize, return ({width:x.width + y.width, height:x.height+y.height}), ({width:10, height:10}), ({width:20, height:20}));
    [self.context evaluateScript:@"console.log(result.width);"];
    [self.context evaluateScript:@"console.log(result.height);"];
    XCTAssertEqualObjects(self.trimmedBuffer, @"[object Object]\n30\n30");
}

- (void)testRange {
    TEST(NSRange, return ({location:x.location + y.location, length:x.length + y.length}), ({location:1, length:2}), ({location:4, length:8}));
    [self.context evaluateScript:@"console.log(result.location);"];
    [self.context evaluateScript:@"console.log(result.length);"];
    XCTAssertEqualObjects(self.trimmedBuffer, @"[object Object]\n5\n10");
}


@end
