// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 19/03/2018.
//  All code (c) 2018 - present day, Elegant Chaos Limited.
//  For licensing terms, see http://elegantchaos.com/license/liberal/.
//
//  We're relying on some Block API knowledge here:
//  http://releases.llvm.org/3.8.1/tools/docs/Block-ABI-Apple.html
//  With thanks also to Mike Ash for some important nuggets contained
//  in: https://www.mikeash.com/pyblog/friday-qa-2011-05-06-a-tour-of-mablockclosure.html
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

#import "JSBlock.h"

#import <objc/message.h>

/**
 Internal block structures.
 
 See http://releases.llvm.org/3.8.1/tools/docs/Block-ABI-Apple.html for more details.
 */

struct BlockDescriptor
{
    unsigned long reserved;
    unsigned long size;
    void *rest[1];
};

struct Block
{
    void *isa;
    int flags;
    int reserved;
    void *invoke;
    struct BlockDescriptor *descriptor;
};

enum {
    BLOCK_HAS_COPY_DISPOSE =  (1 << 25),
    BLOCK_HAS_CTOR =          (1 << 26), // helpers have C++ code
    BLOCK_IS_GLOBAL =         (1 << 28),
    BLOCK_HAS_STRET =         (1 << 29), // IFF BLOCK_HAS_SIGNATURE
    BLOCK_HAS_SIGNATURE =     (1 << 30),
};

// MARK: - Invocation

/**
 The higher level invocation function extracts the arguments, converts
 them to JSValues, and calls the JS function.
 
 We return the result as another JSValue.
 */

static JSValue* jsInvoke(JSValue* function, NSMethodSignature* signature, va_list args) {
    JSContext* context = function.context;
    NSUInteger count = [signature numberOfArguments];
    NSMutableArray* jsArgs = [NSMutableArray new];
    for (NSUInteger n = 1; n < count; ++n) {
        NSString* type = [NSString stringWithCString:[signature getArgumentTypeAtIndex:n] encoding:NSASCIIStringEncoding];
        if ([type isEqualToString:@"i"]) {
            int value = va_arg(args, int);
            [jsArgs addObject:[JSValue valueWithInt32:value inContext:context]];
            NSLog(@"arg #%ld %d", n, value);
        } else if ([type isEqualToString:@"d"]) {
            double value = va_arg(args, double);
            [jsArgs addObject:[JSValue valueWithDouble:value inContext:context]];
            NSLog(@"arg #%ld %lf", n, value);
        } else if ([type isEqualToString:@"I"]) {
            uint value = va_arg(args, uint);
            [jsArgs addObject:[JSValue valueWithUInt32:value inContext:context]];
            NSLog(@"arg #%ld %u", n, value);
        } else if ([type isEqualToString:@"c"]) {
            char value = va_arg(args, int);
            [jsArgs addObject:[JSValue valueWithBool:value inContext:context]];
            NSLog(@"arg #%ld %d", n, value);
        } else if ([type isEqualToString:@"B"]) {
            bool value = va_arg(args, int) != 0;
            [jsArgs addObject:[JSValue valueWithBool:value inContext:context]];
            NSLog(@"arg #%ld %s", n, value ? "true" : "false");
        } else if ([type isEqualToString:@"{CGRect={CGPoint=dd}{CGSize=dd}}"]) {
            CGRect value = va_arg(args, CGRect);
            [jsArgs addObject:[JSValue valueWithRect:value inContext:context]];
            NSLog(@"arg #%ld %@", n, NSStringFromRect(value));
        } else if ([type isEqualToString:@"{CGPoint=dd}"]) {
            CGPoint value = va_arg(args, CGPoint);
            [jsArgs addObject:[JSValue valueWithPoint:value inContext:context]];
            NSLog(@"arg #%ld %@", n, NSStringFromPoint(value));
        } else if ([type characterAtIndex:0] == '@') {
            id value = va_arg(args, id);
            [jsArgs addObject:[JSValue valueWithObject:value inContext:context]];
            NSLog(@"arg #%ld %@", n, value);
        } else {
            NSLog(@"arg #%ld type %@", n, type);
            [jsArgs addObject:[JSValue valueWithNullInContext:context]];
        }
    }
    
    
    JSValue* result = [function callWithArguments:jsArgs];
    return result;
}

/**
 Helpers to convert the return value to the correct type.
 */

static inline double return_double(JSValue* value) { return value.toDouble; }
static inline int return_int(JSValue* value) { return value.toInt32; }
static inline uint return_uint(JSValue* value) { return value.toUInt32; }
static inline char return_char(JSValue* value) { return value.toInt32; }
static inline bool return_bool(JSValue* value) { return value.toBool; }
static inline id return_id(JSValue* value) { return value.toObject; }
static inline CGRect return_CGRect(JSValue* value) { return value.toRect; }
static inline CGPoint return_CGPoint(JSValue* value) { return value.toPoint; }


/**
 We use a few different low level invocation functions - one for each return type - as a quick
 and easy way of getting the compiler to put the right sized return value onto the stack.
 
 This isn't scalable for generic structs, since there are an infinite variety of them and
 we can't declare a function for every one.
 
 In theory we ought to be able to use the signature plus knowledge of the ABI to figure out
 where the return value is supposed to go (registers, stack, or a bit of both) and how big it is.
 We could then execute a few assembler instructions to put it into the right place.
 
 This might allow us to have a single invocation function to handle all cases.
 
 */

static void invoke(JSBlock* block, ...) {
    va_list args;
    va_start(args, block);
    jsInvoke(block.function, block.signature, args);
    va_end(args);
}

#define INVOKE_BLOCK_RETURNING(_type_) \
static _type_ _type_ ## _invoke(JSBlock* block, ...) { \
va_list args; \
va_start(args, block); \
JSValue* jsResult = jsInvoke(block.function, block.signature, args); \
va_end(args); \
return return_ ## _type_(jsResult); \
} \

INVOKE_BLOCK_RETURNING(double)
INVOKE_BLOCK_RETURNING(int)
INVOKE_BLOCK_RETURNING(uint)
INVOKE_BLOCK_RETURNING(char)
INVOKE_BLOCK_RETURNING(bool)
INVOKE_BLOCK_RETURNING(id)
INVOKE_BLOCK_RETURNING(CGRect)
INVOKE_BLOCK_RETURNING(CGPoint)

#define INVOKE_CASE(_char_, _type_) case _char_: _invoke = (IMP) _type_ ## _invoke; break


@implementation JSBlock
{
    int _flags;
    int _reserved;
    IMP _invoke;
    struct BlockDescriptor *_descriptor;
}

+ (const char*)signatureForBlock:(id)blockObj {
    struct Block *block = (__bridge void * )blockObj;
    struct BlockDescriptor *descriptor = block->descriptor;
    
    assert(block->flags & BLOCK_HAS_SIGNATURE);
    
    int index = 0;
    if(block->flags & BLOCK_HAS_COPY_DISPOSE)
        index += 2;
    
    return descriptor->rest[index];
}

+ (instancetype)blockWithSignature:(NSString*)signature function:(JSValue*)function {
    return [[self alloc] initWithSignature:signature.UTF8String function:function];
}

- (double)returnResult {
    return 7.67;
}

- (instancetype)initWithSignature:(const char*)signature function:(JSValue*)function {
    self = [super init];
    if (self) {
        _flags = BLOCK_HAS_SIGNATURE;
        _descriptor = calloc(1, sizeof(struct BlockDescriptor));
        _descriptor->size = class_getInstanceSize([self class]);
        _descriptor->rest[0] = (void *) signature;
        _signature = [NSMethodSignature signatureWithObjCTypes:signature];
        const char* type = _signature.methodReturnType;
        switch (type[0]) {
            INVOKE_CASE('d', double);
            INVOKE_CASE('i', int);
            INVOKE_CASE('I', uint);
            INVOKE_CASE('c', char);
            INVOKE_CASE('B', bool);
            INVOKE_CASE('@', id);
                
            case '{':
                if (strcmp(type, "{CGRect={CGPoint=dd}{CGSize=dd}}") == 0) {
                    _invoke = (IMP)CGRect_invoke;
                    break;
                } else if (strcmp(type, "{CGPoint=dd}") == 0) {
                    _invoke = (IMP)CGPoint_invoke;
                    break;
                } else {
                    NSLog(@"generic structures not handled yet");
                }
                break;
            default:
                _invoke = (IMP)invoke;
        }
        _function = function;
    }
    
    return self;
}

- (void)dealloc {
    free(_descriptor);
}

- (id)copyWithZone:(nullable NSZone*)zone {
    return self;
}

@end

