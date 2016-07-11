//
//  ViewController.m
//  JspathTest
//
//  Created by Luigi on 16/5/28.
//  Copyright © 2016年 Luigi. All rights reserved.
//

#import "ViewController.h"
#import "RSA.h"
#import "NEJSPatch.h"
@interface ViewController ()
@property (nonatomic,assign)__block NSInteger count;
@property (nonatomic,strong)NSURLSession *session;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    UIButton *button=[UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:@"请求接口" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(startRequestJSPath) forControlEvents:UIControlEventTouchUpInside];
    button.frame=CGRectMake(100, 200, 100, 50);
    [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.view addSubview:button];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void)startRequestJSPath{
    [NEJSPatch sync];
}
- (void)jspatchTest{
    UIAlertController *alertViewController=[UIAlertController alertControllerWithTitle:@"公开课jsPath测试" message:@"哈哈哈哈哈 我来测试了" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancleAction=[UIAlertAction actionWithTitle:@"知道啦" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    [alertViewController addAction:cancleAction];
    [self presentViewController:alertViewController animated:YES completion:^{
        
    }];
}
@end
