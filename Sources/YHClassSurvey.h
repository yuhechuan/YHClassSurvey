//
//  YHClassSurvey.h
//  YHClassSurvey
//
//  Created by ruaho on 2019/6/12.
//  Copyright © 2019 ruaho. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * 检测之前要运行自己的app  把每个用的页面都初始化一次  再做检测
 */

@interface YHClassSurvey : NSObject

/**
 获取当前工程下自己创建的所有类 并检测打印
 */

+ (NSArray <NSString *>*)yh_bundleOwnClassesListAndSurvery;

/**
 获取当前工程下所有类（含系统类、cocoPods类） 并检测打印
 */
+ (NSArray <NSString *>*)yh_bundleAllClassesListAndSurvery;

@end

NS_ASSUME_NONNULL_END
