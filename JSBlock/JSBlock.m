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



#define INVOKE_METHOD_RETURNING(_type_) \
- (_type_) _type_ ## InvokeWithSignature:(NSMethodSignature*)signature arguments:(va_list)args

@interface JSBlock()
INVOKE_METHOD_RETURNING(void);
INVOKE_METHOD_RETURNING(double);
INVOKE_METHOD_RETURNING(int);
INVOKE_METHOD_RETURNING(uint);
INVOKE_METHOD_RETURNING(char);
INVOKE_METHOD_RETURNING(bool);
INVOKE_METHOD_RETURNING(id);
INVOKE_METHOD_RETURNING(CGRect);
@end


static void InvokeBlock(JSBlock* block, ...) {
    va_list args;
    va_start(args, block);
    [block voidInvokeWithSignature:block.signature arguments:args];
    va_end(args);
}

#define INVOKE_BLOCK_RETURNING(_type_) \
static _type_ _type_ ## InvokeBlock(JSBlock* block, ...) { \
_type_ result; \
memset(&result, 0, sizeof(result)); \
va_list args; \
va_start(args, block); \
result = [block _type_ ## InvokeWithSignature:block.signature arguments:args]; \
va_end(args); \
\
return result; \
} \

INVOKE_BLOCK_RETURNING(double)
INVOKE_BLOCK_RETURNING(int)
INVOKE_BLOCK_RETURNING(uint)
INVOKE_BLOCK_RETURNING(char)
INVOKE_BLOCK_RETURNING(bool)
INVOKE_BLOCK_RETURNING(id)
INVOKE_BLOCK_RETURNING(CGRect)

#define INVOKE_CASE(_char_, _type_) case _char_: _invoke = (IMP) _type_ ## InvokeBlock; break


@implementation JSBlock
{
    int _flags;
    int _reserved;
    IMP _invoke;
    struct BlockDescriptor *_descriptor;
    JSValue* _function;
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
        switch (_signature.methodReturnType[0]) {
                INVOKE_CASE('d', double);
                INVOKE_CASE('i', int);
                INVOKE_CASE('I', uint);
                INVOKE_CASE('c', char);
                INVOKE_CASE('B', bool);
                INVOKE_CASE('@', id);
                INVOKE_CASE('{', CGRect);
            default:
                _invoke = (IMP)InvokeBlock;
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

- (JSValue*)_invokeWithSignature:(NSMethodSignature*)signature arguments:(va_list)args {
    JSContext* context = _function.context;
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
        } else if ([type characterAtIndex:0] == '@') {
            id value = va_arg(args, id);
            [jsArgs addObject:[JSValue valueWithObject:value inContext:context]];
            NSLog(@"arg #%ld %@", n, value);
        } else {
            NSLog(@"arg #%ld type %@", n, type);
            [jsArgs addObject:[JSValue valueWithNullInContext:context]];
        }
    }
    
    
    JSValue* result = [_function callWithArguments:jsArgs];
    return result;
}

- (void)voidInvokeWithSignature:(NSMethodSignature *)signature arguments:(va_list)args {
    JSValue* result = [self _invokeWithSignature:signature arguments:args];
    if (result && !result.isNull) {
        NSLog(@"Unexpected result: %@", result);
    }
}

- (double)doubleInvokeWithSignature:(NSMethodSignature *)signature arguments:(va_list)args {
    JSValue* result = [self _invokeWithSignature:signature arguments:args];
    return result.toDouble;
}

- (int)intInvokeWithSignature:(NSMethodSignature *)signature arguments:(va_list)args {
    JSValue* result = [self _invokeWithSignature:signature arguments:args];
    return result.toInt32;
}

- (uint)uintInvokeWithSignature:(NSMethodSignature *)signature arguments:(va_list)args {
    JSValue* result = [self _invokeWithSignature:signature arguments:args];
    return result.toUInt32;
}

- (char)charInvokeWithSignature:(NSMethodSignature *)signature arguments:(va_list)args {
    JSValue* result = [self _invokeWithSignature:signature arguments:args];
    return result.toInt32;
}

- (bool)boolInvokeWithSignature:(NSMethodSignature *)signature arguments:(va_list)args {
    JSValue* result = [self _invokeWithSignature:signature arguments:args];
    return result.toBool;
}

- (id)idInvokeWithSignature:(NSMethodSignature *)signature arguments:(va_list)args {
    JSValue* result = [self _invokeWithSignature:signature arguments:args];
    return result.toObject;
}


- (CGRect)CGRectInvokeWithSignature:(NSMethodSignature *)signature arguments:(va_list)args {
    JSValue* result = [self _invokeWithSignature:signature arguments:args];
    return result.toRect;
}

@end

