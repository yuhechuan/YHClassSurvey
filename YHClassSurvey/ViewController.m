//
//  ViewController.m
//  YHClassSurvey
//
//  Created by ruaho on 2019/6/12.
//  Copyright © 2019 ruaho. All rights reserved.
//

#import "ViewController.h"
#import "YHClassSurvey.h"
#import <objc/runtime.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    /*
     打印出项目中  未被使用过的类名
     */
    
    NSLog(@"%@",[YHClassSurvey yh_bundleOwnClassesListAndSurvery]);
}


@end
