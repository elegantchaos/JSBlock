// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 19/03/2018.
//  All code (c) 2018 - present day, Elegant Chaos Limited.
//  For licensing terms, see http://elegantchaos.com/license/liberal/.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

@import JavaScriptCore;

@protocol JSBlockExports<JSExport>
+ (instancetype)blockWithSignature:(NSString*)signature function:(JSValue*)function;
@end

@interface JSBlock : NSObject<JSBlockExports, NSCopying>
@property (strong, nonatomic, readonly) JSValue* function;
@property (strong, nonatomic, readonly) NSMethodSignature* signature;

+ (const char*)signatureForBlock:(id)block;
- (instancetype)initWithSignature:(const char*)signature function:(JSValue*)function;
@end
