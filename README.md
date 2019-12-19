# 原理
LLObserverCenter参考NSNotificationCenter实现方式，采用单例全局管理，单例持有观察者NSMapTable，NSMapTable集合中储存所有添加的block字典，在发送通知观察时从字典中取出对应的block调用。

#### 1、单例持有NSMapTable集合
这里采用`NSMapTable`来储存block，`NSMapTable`强引用key，弱引用value，这样做的好处在于：当其中储存的对象销毁后，会自动从`NSMapTable`移除，使用`NSMapTable`可以保证生命周期不受单例影响。
具体参考--->>[Cocoa 集合类型：NSPointerArray，NSMapTable，NSHashTable](http://www.saitjr.com/ios/nspointerarray-nsmaptable-nshashtable.html)
#### 2、保证一个对象只添加一次观察者
多次添加观察者，调用时会响应多次，未解决此问题故采用对象内存地址和标识符作为字典的key，保证一个对象只添加一次。
#### 3、多线程安全
采用GCD信号量来保证线程安全。

#### LLObserverCenter.h 方法如下
```
/// 根据标识添加观察（使用block ⚠️注意循环使用）
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
```

#### 使用方式
添加观察者
```
[LLObserverCenter addObserver:self identifier:@"testA" mainThread:YES block:^(id  _Nonnull observer, id  _Nonnull anObject) {
        
}];
```
发送通知消息
```
[LLObserverCenter postIdentifier:@"testA" object:nil];
```
