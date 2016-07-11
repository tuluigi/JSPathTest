//
//  NEJSPatch.m
//  JspathTest
//
//  Created by Luigi on 16/6/7.
//  Copyright © 2016年 Luigi. All rights reserved.
//

#import "NEJSPatch.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <JSPatch/JPEngine.h>
#import <CoreFoundation/CoreFoundation.h>
#import "RSA.h"
#import "NSData+CommonCrypto.h"
#import "NSDictionary+QueryString.h"
#import "FileHash.h"
#ifdef DEBUG
# define NELog(fmt, ...) NSLog((@"[文件名:%s]\n" "[函数名:%s]\n" "[行号:%d] \n" fmt), __FILE__, __FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
# define NELog(...);
#endif


typedef void(^NENETCompletionBlock)(NSData * _Nullable responseData,NSDictionary *responseDic, NSURLResponse * _Nullable response, NSError * _Nullable error);

static NSString *const kAESEncryptKey         = @"com.netease.opencourse.aes.encryptkey";

/**
 *  jspath 本地的key
 */
static NSString *const kNEJSPathKey             = @"NEJSpathKey";
static NSString *const kAppVersion              =@"NeAppVersion";//存储的app的version的key
static NSString *const kJsVersion               =@"NEJSFileVersion";//补丁文件的版本key

#ifdef DEBUG
static NSString *const kJSPathHost              =@"http://test.c.open.163.com";
#else
static NSString *const kJSPathHost              =@"http://c.open.163.com";
#endif
static NEJSPatch *sharedJSPath  =nil;
@interface NEJSPatch ()
@property (nonatomic,copy)NSString *appKey;//每个app单独的key
@property (nonatomic,copy)NSString *appVersion;
@property (nonatomic,strong)NSMutableDictionary *userInfoDic;

@end



@implementation NEJSPatch
@synthesize appVersion =_appVersion;
@synthesize appKey      =_appKey;
#pragma mark - private method
- (instancetype)init{
    self=[super init];
    if (self) {
    }
    return self;
}
+ (instancetype)sharedNEJSPath{
    @synchronized (self) {
        if (nil==sharedJSPath) {
            sharedJSPath=[[NEJSPatch alloc]  init];
             [JPEngine startEngine];
        }
    }
    return sharedJSPath;
}
#pragma mark -setter getter
- (void)setAppVersion:(NSString *)appVersion{
    _appVersion=appVersion;
}
- (NSString *)appVersion{
    if (nil==_appVersion||[_appVersion isEqualToString:@""]) {
        _appVersion=[NEJSPatch getApplicationVersion];
    }
    return _appVersion;
}
#pragma mark -publich method
+ (void)startWithAppKey:(NSString *)key appVersion:(NSString *)appVersion{
    [[NEJSPatch sharedNEJSPath] setAppKey:key];
    [[NEJSPatch sharedNEJSPath] setAppVersion:appVersion];
}

+ (void)setupUserData:(NSDictionary *)dic{
    if (dic) {
        [NEJSPatch sharedNEJSPath].userInfoDic=[NSMutableDictionary dictionaryWithDictionary:dic];
    }
    NSString *appVersion=[[NEJSPatch sharedNEJSPath] appVersion];
    NSString *deviceType=@"";
   UIUserInterfaceIdiom uiInterface= [UIDevice currentDevice].userInterfaceIdiom ;
    NSInteger isPad=0;
    switch (uiInterface) {
        case UIUserInterfaceIdiomPhone:{
            deviceType=@"iPhone";
        }break;
        case UIUserInterfaceIdiomPad:{
            deviceType=@"iPad";
            isPad=1;
        }break;
        case UIUserInterfaceIdiomTV:{
            deviceType=@"TV";
        }break;
        case UIUserInterfaceIdiomCarPlay:{
            deviceType=@"CarPlay";
        }break;
        default:
            break;
    }
    [[NEJSPatch sharedNEJSPath].userInfoDic setValue:appVersion forKey:@"iOS" ];
    [[NEJSPatch sharedNEJSPath].userInfoDic setValue:@(isPad) forKey:@"isPad"];
}
#pragma mark - NetConnection
+ (NSURLSessionTask *)requestWithUrl:(NSString *)url parm:(NSDictionary *)parm completionBlock:(NENETCompletionBlock)completionBlock{
    NSURL *urlPath=[NSURL URLWithString:url];
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:urlPath];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setTimeoutInterval:10];
    NSData *jsonData= nil;
    if ([NSJSONSerialization isValidJSONObject:parm]) {
        NSError *aJsonError;
        jsonData=[NSJSONSerialization dataWithJSONObject:parm options:NSJSONWritingPrettyPrinted error:&aJsonError];
        if (aJsonError) {
            NELog(@"parm 转json 失败;%@",aJsonError.description);
        }
    }
    if (jsonData) {
        [request setHTTPBody:jsonData];
    }
    NSURLSessionTask *task=[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
          NSLog(@"sync结果:\n%@",[[NSString alloc]  initWithData:data encoding:NSUTF8StringEncoding]);
        NSError *jsonError;
        id jsonObject;
        if (data) {
            jsonObject= [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
        }
        if (completionBlock) {
            completionBlock(data,jsonObject,response,error);
        }
    }];
    [task resume];
    return task;
}
/**
 *  和平台进行同步是否有更新
 */
+ (void)sync{
    NSDictionary *dic=[[NSUserDefaults standardUserDefaults]  objectForKey:kNEJSPathKey];
    if (dic) {
        NSString *lastVersion=[dic objectForKey:kAppVersion];
        if (lastVersion&&lastVersion.length>0) {
            NSString *currentVersion=[[NEJSPatch sharedNEJSPath] appVersion];
            if (![lastVersion isEqualToString:currentVersion]) {//说明版本号不一样，这时候可能是app升级
                //如果是app升级，则将本地的jspath的根目录文件给删除
                NSString *rootJSPathDir=[NEJSPatch rootJSPathDir];
                NSError *error;
                BOOL isSuccees =[[NSFileManager defaultManager] removeItemAtPath:rootJSPathDir error:&error];
                if (nil==error&&isSuccees) {
                    [[NSFileManager defaultManager] createDirectoryAtPath:rootJSPathDir withIntermediateDirectories:YES attributes:nil error:nil];
                    
                }
            }else{//如果版本号一样，则先执行本地已经存在的js文件
                NSString *mainJsPath=[self mainJSPath];
                BOOL isExist=[[NSFileManager defaultManager] fileExistsAtPath:mainJsPath];
                if (isExist) {
                    //本地文件进行了aes加密，需要先解密，然后再执行该脚本
                    NSData *encryptScripData=[NSData dataWithContentsOfFile:mainJsPath];
                    NSData *decryScripData=[encryptScripData decryptedAES256DataUsingKey:kAESEncryptKey  error:nil];
                    if (decryScripData) {
                        NSString *scripContent=[[NSString alloc]  initWithData:decryScripData encoding:NSUTF8StringEncoding];
                        [JPEngine evaluateScript:scripContent];
                    }else{
                        //删除本地解密失败的js脚本文件
                        [[NSFileManager defaultManager] removeItemAtPath:[self mainJSPath] error:nil];
                    }
                }
            }
        }
    }
    
    
    NSString *apiPath=[NSString stringWithFormat:@"%@/mob/ios/checkPatch.do?appKey=%@&appVersion=%@",kJSPathHost,[[NEJSPatch sharedNEJSPath] appKey],[[NEJSPatch sharedNEJSPath] appVersion]];
    [self requestWithUrl:apiPath parm:nil completionBlock:^(NSData * _Nullable responseData, NSDictionary *responseDic, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSInteger code=[[responseDic objectForKey:@"code"] integerValue];
        NSDictionary *dataDic=[responseDic objectForKey:@"data"];
        if (responseDic&&nil==error) {
            NSInteger localScripVersion =[[dic objectForKey:kJsVersion] integerValue];
            NSInteger scripVersion      =[[dataDic objectForKey:@"patchVersion"] integerValue];
            NSString *encryptFileMd5    =[dataDic objectForKey:@"md5"];
            NSString *publishKey        =[dataDic objectForKey:@"publicKey"];
            NSString *downloadUrl       =[dataDic objectForKey:@"jsUrl"];
           
            
            BOOL shouldDownlodFile=YES;//默认需要下载新的
            //1、先检测是否有新脚本
            if (scripVersion ==localScripVersion) {//两个版本相等的情况下，检测本地是否有该文件，没有的话则下载
                BOOL isExist=[[NSFileManager defaultManager]  fileExistsAtPath:[self mainJSPath]];
                shouldDownlodFile=!isExist;
            }
            
            //2、如果是条件下发的话，则检测是否符合条件
            id conditionString =[dataDic objectForKey:@"condition"];
            if ([conditionString isKindOfClass:[NSString class]]) {//条件下发
                if (conditionString&&((NSString *)conditionString).length>1) {
                    NSArray *tempArray=[[[NEJSPatch sharedNEJSPath].userInfoDic allValues] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:conditionString]];
                    if (tempArray&&tempArray.count) {//说明有符合条件的
                        shouldDownlodFile=YES;
                        NELog(@"符合条件，需要下发");
                    }else{
                        shouldDownlodFile=NO;
                        NELog(@"没有符合条件的");
                    }
                }
            }

            if (shouldDownlodFile) {//有新的脚本文件，需要下载新的
                [self downloadFileWithUrl:downloadUrl scripVersion:scripVersion encryptFileMd5:encryptFileMd5 rsaPublishKey:publishKey];
            }
        }
    }];
}

/**
 *  下载js脚本文件
 *
 *  @param urlPath       文件地址
 *  @param fileMd5String 服务器加密md5签名
 *  @param publishKey    服务器返回rsa公钥
 */
+ (void)downloadFileWithUrl:(NSString *)urlPath scripVersion:(NSInteger )scripVersion encryptFileMd5:(NSString *)encryptFileMd5 rsaPublishKey:(NSString *)publishKey{
    NSURL *url=[NSURL URLWithString:urlPath];
    NSURLSessionDownloadTask *downTask=[[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (nil==error&&location) {//文件下载成功
            //创建文件夹
            if (![[NSFileManager defaultManager] fileExistsAtPath:[self rootJSPathDir]]) {
                [[NSFileManager defaultManager] createDirectoryAtPath:[self rootJSPathDir] withIntermediateDirectories:YES attributes:nil error:nil];
            }
            
            NSString *currentJSVersionDir=[[self rootJSPathDir] stringByAppendingPathComponent:[[NEJSPatch sharedNEJSPath] appVersion]];
            if (![[NSFileManager defaultManager] fileExistsAtPath:currentJSVersionDir]) {
                [[NSFileManager defaultManager] createDirectoryAtPath:currentJSVersionDir withIntermediateDirectories:YES attributes:nil error:nil];
            }
            
            NSData *scripData=[NSData dataWithContentsOfURL:location];
            NSString *localFileMd5String=[[scripData md5String] lowercaseString];
            NSString *severFileMd5String=[[RSA decryptString:encryptFileMd5 publicKey:publishKey] lowercaseString];
            if ([severFileMd5String isEqualToString:localFileMd5String]) {//文件没有被篡改，可以正常使用, 执行脚本
                NSData *encryScripData=[scripData AES256EncryptedDataUsingKey:kAESEncryptKey error:nil];
                if (encryScripData) {
                    BOOL isCreated=[encryScripData writeToFile:[self mainJSPath] atomically:YES];
                    if (isCreated) {//加密的文件写入本地成功
                        NSDictionary *jspathDic=@{[self jsPathAppVersionKey]:@(scripVersion),kAppVersion:[NEJSPatch sharedNEJSPath].appVersion};
                        [[NSUserDefaults standardUserDefaults] setObject:jspathDic forKey:kNEJSPathKey];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        [JPEngine evaluateScript:[[NSString alloc]  initWithData:scripData encoding:NSUTF8StringEncoding]];
                        NELog(@"补丁文件写入本地成功");
                    }else{
                         NELog(@"补丁文件写入本地失败");
                    }
                }
            }else{//文件md5签名不一样，可能被篡改，需要本地删除该脚本文件
                [[NSFileManager defaultManager]  removeItemAtPath:[self mainJSPath] error:nil];
            }
        }else{//文件下载失败
            NELog(@"文件下载失败");
        }
    }];
    [downTask resume];
    
}

#pragma mrak -private method
/**
 *  获取当前app的版本
 *
 *  @return
 */
+ (NSString*) getApplicationVersion{
    NSString* appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    return appVersion;
}
+ (NSString *)jsPathAppVersionKey{
    NSString *appVersion=[[NEJSPatch sharedNEJSPath] appVersion];
    NSString *jspathKey=[NSString stringWithFormat:@"%@_%@",@"kNEJSPathAppVersion",appVersion];
    return jspathKey;
}
+ (NSString *)rootJSPathDir{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *fileDirPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"NEJSPath"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:fileDirPath])
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:fileDirPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return fileDirPath;
    
}
+ (NSString *)mainJSPath{
    NSString *mainJspath= [NSString stringWithFormat:@"%@/%@/main.js",[NEJSPatch rootJSPathDir],[[NEJSPatch sharedNEJSPath] appVersion]];
    return mainJspath;
}
@end




