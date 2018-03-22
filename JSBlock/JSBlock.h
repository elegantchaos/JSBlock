//
//  JSBlock.h
//
//  Created by Sam Deane on 19/03/2018.
//  Copyright © 2018 Elegant Chaos. All rights reserved.
//

@import JavaScriptCore;

@protocol JSBlockExports<JSExport>
+ (instancetype)blockWithSignature:(NSString*)signature function:(JSValue*)function;
@end

@interface JSBlock : NSObject<JSBlockExports, NSCopying>
@property (strong, nonatomic, readonly) NSMethodSignature* signature;

+ (const char*)signatureForBlock:(id)block;
- (instancetype)initWithSignature:(const char*)signature function:(JSValue*)function;
@end
