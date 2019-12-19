//
//  LLObserverCenter.m
//  LLObserverCenter
//
//  Created by apple on 2019/12/18.
//  Copyright © 2019 LL. All rights reserved.
//

/*
 使用阅读👇👇👇👇
 NSMapTable 用来存储观察者优点：可以持有键和值的弱引用，当键或值当中的一个被释放时，整个这一项就会被移除掉

 因此使用LLObserverCenter实例对象添加的观察，无需手动移除，在观察者被释放时，所持有的对象也被释放

 removeObserver:
 removeObserver:identifier:
 以上两个移除观察，实际上无特殊使用场景，可以忽略
 🔚
*/

#import "LLObserverCenter.h"

@interface LLObserverCenter ()

@property (nonatomic, strong) NSMapTable <NSString * ,id> *observerMapTable;
@property (nonatomic, strong) NSMapTable <id ,NSMutableDictionary *> *blockMapTable;
@property (nonatomic, strong) NSMapTable <id ,NSMutableDictionary *> *threadMapTable;

@property (nonatomic, strong) dispatch_semaphore_t semaphore;

@end

static NSString * const appendingIdentifierKeyConst = @"-LLObserverCenter-0";
static NSString * const appendingBlockKeyConst = @"-LLObserverCenterBlock-0";
static NSString * const appendingMainThreadKeyConst = @"-LLObserverCenterMainThread-0";

@implementation LLObserverCenter

static LLObserverCenter *_observerCenter = nil;

+ (instancetype)sharedObserverCenter {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _observerCenter = [[super allocWithZone:NULL] init];
    });
    return _observerCenter;
}

- (instancetype)init {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _observerCenter = [super init];
        self.observerMapTable = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableWeakMemory];
        self.blockMapTable = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory valueOptions:NSMapTableStrongMemory];
        self.threadMapTable = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory valueOptions:NSMapTableStrongMemory];
        self.semaphore = dispatch_semaphore_create(0);
        dispatch_semaphore_signal(self.semaphore);
    });
    return _observerCenter;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [self sharedObserverCenter];
}

- (instancetype)copyWithZone:(NSZone *)zone {
    return _observerCenter;
}

- (instancetype)mutableCopyWithZone:(NSZone *)zone {
    return _observerCenter;
}

+ (void)addObserver:(id)observer
         identifier:(NSString *)identifier
         mainThread:(BOOL)mainThread
              block:(void (^)(id _Nonnull, id _Nonnull))block {
    
    // 等待信号 信号总量-1，当信号总量为0时就会一直等待（阻塞所在线程），否则就可以正常执行
    dispatch_semaphore_wait([LLObserverCenter sharedObserverCenter].semaphore, DISPATCH_TIME_FOREVER);
    
    // key规则 观察者内存地址+标识+常量字符串
    NSString *key = [NSString stringWithFormat:@"%@-%@",[NSString stringWithFormat:@"%p",observer], [identifier stringByAppendingString:appendingIdentifierKeyConst]];
    
    // 查看blockMapTable是否存在此观察者
    NSMutableDictionary *blockDictionary = [[LLObserverCenter sharedObserverCenter].blockMapTable objectForKey:observer];
    if (!blockDictionary) {
        blockDictionary = [NSMutableDictionary dictionary];
    }
    // 存储block回调相关
    NSString *blockKey = [key stringByAppendingString:appendingBlockKeyConst];
    [blockDictionary setObject:block forKey:blockKey];

    // 查看threadMapTable是否存在此观察者
    NSMutableDictionary *mainThreadDictionary = [[LLObserverCenter sharedObserverCenter].threadMapTable objectForKey:observer];
    if (!mainThreadDictionary) {
        mainThreadDictionary = [NSMutableDictionary dictionary];
    }
    // 存储主线程配置相关
    NSString *mainThreadKey = [key stringByAppendingString:appendingMainThreadKeyConst];
    [mainThreadDictionary setObject:[NSNumber numberWithBool:mainThread] forKey:mainThreadKey];

    // LLObserverCenter实例对象保存观察者
    [[LLObserverCenter sharedObserverCenter].observerMapTable setObject:observer forKey:key];
    // LLObserverCenter实例对象保存block
    [[LLObserverCenter sharedObserverCenter].blockMapTable setObject:blockDictionary forKey:observer];
    // LLObserverCenter实例对象保存线程配置
    [[LLObserverCenter sharedObserverCenter].threadMapTable setObject:mainThreadDictionary forKey:observer];
    
    dispatch_semaphore_signal([LLObserverCenter sharedObserverCenter].semaphore);
}

+ (void)postIdentifier:(NSString *)identifier
                object:(id)anObject {
    // 等待信号 信号总量-1，当信号总量为0时就会一直等待（阻塞所在线程），否则就可以正常执行
    dispatch_semaphore_wait([LLObserverCenter sharedObserverCenter].semaphore, DISPATCH_TIME_FOREVER);
    
    // 所有观察者key
    NSArray <NSString *> *keyArray = [[[LLObserverCenter sharedObserverCenter].observerMapTable keyEnumerator] allObjects];
    
    // 匹配规则key
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH %@",[identifier stringByAppendingString:appendingIdentifierKeyConst]];
    
    // 所有匹配的观察者key
    NSArray <NSString *> *filters = [keyArray filteredArrayUsingPredicate:predicate];
    
    // 遍历所有的匹配观察者
    for (NSString *key in filters) {
        // 观察者
        id observer = [[LLObserverCenter sharedObserverCenter].observerMapTable objectForKey:key];
        // 观察者绑定的回调字典
        NSMutableDictionary *blockDictionary = [[LLObserverCenter sharedObserverCenter].blockMapTable objectForKey:observer];
        // 观察者绑定的主线程字典
        NSMutableDictionary *mainThreadDictionary = [[LLObserverCenter sharedObserverCenter].threadMapTable objectForKey:observer];
        
        // 回调key
        NSString *blockKey = [key stringByAppendingString:appendingBlockKeyConst];
        void(^block)(id observer, id anObject) = [blockDictionary objectForKey:blockKey];
        
        if (block) {
            // 主线程key
            NSString *mainThreadKey = [key stringByAppendingString:appendingMainThreadKeyConst];
            BOOL mainThread = [[mainThreadDictionary objectForKey:mainThreadKey] boolValue];
            dispatch_queue_t queue ;
            if (mainThread) {
                queue = dispatch_get_main_queue();
            } else {
                queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            }
            
            dispatch_async(queue, ^{
                block(observer, anObject);
            });
        }
    }
    // 发送观察信号 信号总量+1
    dispatch_semaphore_signal([LLObserverCenter sharedObserverCenter].semaphore);
}

+ (void)removeObserver:(id)observer
            identifier:(NSString *)identifier {
    
    // 等待信号 信号总量-1，当信号总量为0时就会一直等待（阻塞所在线程），否则就可以正常执行
    dispatch_semaphore_wait([LLObserverCenter sharedObserverCenter].semaphore, DISPATCH_TIME_FOREVER);
    
    // 所有观察者key
    NSArray <NSString *> *keyArray = [[[LLObserverCenter sharedObserverCenter].observerMapTable keyEnumerator] allObjects];

    // 匹配规则key 
    NSString *predicateWithFormat = @"";
    if (identifier.length == 0) {
        predicateWithFormat = [NSString stringWithFormat:@"SELF BEGINSWITH '%@'",[NSString stringWithFormat:@"%p",observer]] ;
    } else {
        predicateWithFormat = [NSString stringWithFormat:@"SELF ENDSWITH '%@'",[identifier stringByAppendingString:appendingIdentifierKeyConst]];
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateWithFormat];
    
    // 所有匹配的观察者key
    NSArray <NSString *> *filters = [keyArray filteredArrayUsingPredicate:predicate];
 
    // 遍历所有的匹配观察者
    for (NSString *key in filters) {
        // 观察者
        id observer = [[LLObserverCenter sharedObserverCenter].observerMapTable objectForKey:key];

        [[LLObserverCenter sharedObserverCenter].blockMapTable removeObjectForKey:observer];
        [[LLObserverCenter sharedObserverCenter].threadMapTable removeObjectForKey:observer];
        [[LLObserverCenter sharedObserverCenter].observerMapTable removeObjectForKey:key];
    }
    
    // 发送观察信号 信号总量+1
    dispatch_semaphore_signal([LLObserverCenter sharedObserverCenter].semaphore);
}

+ (void)removeObserver:(id)observer {
    [self removeObserver:observer identifier:nil];
}

+ (void)lookAllObserver {
    // 所有观察者key
    NSArray <NSString *> *keyArray = [[[LLObserverCenter sharedObserverCenter].observerMapTable keyEnumerator] allObjects];
    
    NSLog(@"lookKeyArray - %@",keyArray);
}

@end
