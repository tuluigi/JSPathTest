//
//  NEJSPatch.h
//  JspathTest
//
//  Created by Luigi on 16/6/7.
//  Copyright © 2016年 Luigi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NEJSPatch : NSObject

/**
 *  初始化设置appKey，appVersion
 *
 *  @param key        没给app申请的appKey
 *  @param appVersion App的版本号，如果传nil或者@“”，则以NSBundle中 CFBundleShortVersionString 作为appversion
 */
+ (void)startWithAppKey:(NSString *)key appVersion:(NSString *)appVersion;
/**
 *  启动时候调用，检测脚本更新
 */
+ (void)sync;





/**
 *  条件下发，配置用户的数据
 *  该方法要在sync之前调用
 *  内部有两个默认内置参数 iOS :系统个版本号； isPad =1:是否是ipad
 *  @param dic
 */
+ (void)setupUserData:(NSDictionary *)dic;
@end
