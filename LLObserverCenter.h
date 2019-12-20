//
//  LLObserverCenter.h
//  LLObserverCenter
//
//  Created by apple on 2019/12/18.
//  Copyright © 2019 LL. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLObserverCenter : NSObject

/// 根据标识添加观察（使用block ⚠️注意循环引用）
/// @param observer 观察者
/// @param identifier 标识
/// @param mainThread 是否主线程回调
/// @param block 监听回调(注意循环引用问题)
+ (void)addObserver:(id)observer
         identifier:(nullable NSString *)identifier
         mainThread:(BOOL)mainThread
              block:(void(^)(id observer, id anObject))block;

/// 根据标识发送
/// @param identifier 标识
/// @param anObject 传递数据
+ (void)postIdentifier:(NSString *)identifier
                object:(nullable id)anObject;


#pragma mark - 因内部使用NSMapTable持有观察者，正常情况无需手动调用移除观察
/// 根据标识移除观察
/// @param observer 观察者
/// @param identifier 标识
+ (void)removeObserver:(id)observer
            identifier:(nullable NSString *)identifier;

/// 移除观察者 所持有所有观察
/// @param observer 观察者
+ (void)removeObserver:(id)observer;

/// 查看当前所有的观察对象（打印输出）
+ (void)lookAllObserver;

@end

NS_ASSUME_NONNULL_END
