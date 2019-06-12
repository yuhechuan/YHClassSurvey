//
//  YHClassSurvey.m
//  YHClassSurvey
//
//  Created by ruaho on 2019/6/12.
//  Copyright © 2019 ruaho. All rights reserved.
//

#import "YHClassSurvey.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/ldsyms.h>


// 类的方法列表已修复
#define RW_METHODIZED         (1<<30)

// 类已经初始化了
#define RW_INITIALIZED        (1<<29)

// 类在初始化过程中
#define RW_INITIALIZING       (1<<28)

// class_rw_t->ro 是 class_ro_t 的堆副本
#define RW_COPIED_RO          (1<<27)

// 类分配了内存，但没有注册
#define RW_CONSTRUCTING       (1<<26)

// 类分配了内存也注册了
#define RW_CONSTRUCTED        (1<<25)

// GC：class 有不安全的 finalize 方法
#define RW_FINALIZE_ON_MAIN_THREAD (1<<24)

// 类的 +load 被调用了
#define RW_LOADED             (1<<23)


# if __arm64__
#   define ISA_MASK        0x0000000ffffffff8ULL
# elif __x86_64__
#   define ISA_MASK        0x00007ffffffffff8ULL
# endif

#if __LP64__
typedef uint32_t mask_t;
#else
typedef uint16_t mask_t;
#endif
typedef uintptr_t cache_key_t;

struct bucket_t {
    cache_key_t _key;
    IMP _imp;
};

struct cache_t {
    struct bucket_t *_buckets;
    mask_t _mask;
    mask_t _occupied;
};

struct entsize_list_tt {
    uint32_t entsizeAndFlags;
    uint32_t count;
};

struct method_t {
    SEL name;
    const char *types;
    IMP imp;
};

struct method_list_t {
    uint32_t entsizeAndFlags;
    uint32_t count;
    struct method_t first;
};

struct ivar_t {
    int32_t *offset;
    const char *name;
    const char *type;
    uint32_t alignment_raw;
    uint32_t size;
};

struct ivar_list_t {
    uint32_t entsizeAndFlags;
    uint32_t count;
    struct ivar_t first;
};

struct property_t {
    const char *name;
    const char *attributes;
};

struct property_list_t {
    uint32_t entsizeAndFlags;
    uint32_t count;
    struct property_t first;
};

struct chained_property_list {
    struct chained_property_list *next;
    uint32_t count;
    struct property_t list[0];
};

typedef uintptr_t protocol_ref_t;
struct protocol_list_t {
    uintptr_t count;
    protocol_ref_t list[0];
};

struct class_ro_t {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;  // instance对象占用的内存空间
#ifdef __LP64__
    uint32_t reserved;
#endif
    const uint8_t * ivarLayout;
    const char * name;  // 类名
    struct method_list_t * baseMethodList;
    struct protocol_list_t * baseProtocols;
    const struct ivar_list_t * ivars;  // 成员变量列表
    const uint8_t * weakIvarLayout;
    struct property_list_t *baseProperties;
};

struct class_rw_t {
    uint32_t flags;
    uint32_t version;
    const struct class_ro_t *ro;
    struct method_list_t * methods;    // 方法列表
    struct property_list_t *properties;    // 属性列表
    const struct protocol_list_t * protocols;  // 协议列表
    Class firstSubclass;
    Class nextSiblingClass;
    char *demangledName;
};

#define FAST_DATA_MASK          0x00007ffffffffff8UL
struct class_data_bits_t {
    uintptr_t bits;
};

/*
 public:
 class_rw_t* data() {
 return (class_rw_t *)(bits & FAST_DATA_MASK);
 }
 */

/* OC对象 */
struct yh_objc_object {
    void *isa;
};

/* 类对象 */
struct yh_objc_class {
    void *isa;
    Class superclass;
    struct cache_t cache;
    struct class_data_bits_t bits;
};

@implementation YHClassSurvey

/*
 *获取当前工程下自己创建的所有类 并检测打印
 */
+ (NSArray <NSString *>*)yh_bundleOwnClassesListAndSurvery {
    
    NSMutableArray *resultArray = [NSMutableArray new];
    unsigned int classCount;
    const char **classes;
    Dl_info info;
    
    dladdr(&_mh_execute_header, &info);
    classes = objc_copyClassNamesForImage(info.dli_fname, &classCount);
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);
    dispatch_apply(classCount, dispatch_get_global_queue(0, 0), ^(size_t index) {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        NSString *className = [NSString stringWithCString:classes[index] encoding:NSUTF8StringEncoding];
        Class class = NSClassFromString(className);
        NSString *class_name = [self surveyClass:class];
        if (class_name) {
            [resultArray addObject:class_name];
        }
        dispatch_semaphore_signal(semaphore);
    });
    
    return resultArray.copy;
}


/*
 *获取当前工程下所有类（含系统类、cocoPods类） 并检测打印
 */
+ (NSArray <NSString *>*)yh_bundleAllClassesListAndSurvery {
    
    NSMutableArray *resultArray = [NSMutableArray new];
    int classCount = objc_getClassList(NULL, 0);
    
    Class *classes = NULL;
    classes = (__unsafe_unretained Class *)malloc(sizeof(Class) *classCount);
    classCount = objc_getClassList(classes, classCount);
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);
    dispatch_apply(classCount, dispatch_get_global_queue(0, 0), ^(size_t index) {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        Class class = classes[index];
        NSString *className = [self surveyClass:class];
        if (className) {
            [resultArray addObject:className];
        }
        dispatch_semaphore_signal(semaphore);
    });
    
    free(classes);
    
    return resultArray.copy;
}

/*
 // 系统原始方法
 #define RW_INITIALIZED (1<<29)
 bool isInitialized() {
 return getMeta()->data()->flags & RW_INITIALIZED;
 }
 */

/*
 * 检测元类的 flags 判断此类是否被初始化
 */
+ (NSString *)surveyClass:(Class)class {
    // 获取类的结构体
    struct yh_objc_class *yh =      (__bridge struct yh_objc_class *)class;
    // 获取原类类的结构体  不可调用方法 这样会主动初始化它
    struct yh_objc_class *yhMeta =  (struct yh_objc_class *)((long long)yh->isa & ISA_MASK);
    
    struct class_data_bits_t bits = yhMeta->bits;
    struct class_rw_t *rw = (struct class_rw_t *)(bits.bits & FAST_DATA_MASK);
    uint32_t flags = rw->flags;
    // 拿出第 29位的值 判断是否被初始化
    uint32_t re = (flags & RW_INITIALIZED);
    
    NSString *className = NSStringFromClass(class);
    if (re) {
        return nil;
    } else {
        return className;
    }
}


@end
