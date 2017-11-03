//
//  TYPEID_Model.m
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_ListView_UIModel.h"
#import "doProperty.h"
#import "doIListData.h"
#import "do_ListView_UIView.h"
#import "doIEventCenter.h"

@interface do_ListView_UIModel()<doIEventCenter>

@end

@implementation do_ListView_UIModel

#pragma mark - 注册属性（--属性定义--）
/*
[self RegistProperty:[[doProperty alloc]init:@"属性名" :属性类型 :@"默认值" : BOOL:是否支持代码修改属性]];
 */
-(void)OnInit
{
    [super OnInit];
    
    //注册属性
    //属性声明
    [self RegistProperty:[[doProperty alloc]init:@"canScrollToTop" :Bool :@"true" :YES]];
    [self RegistProperty:[[doProperty alloc]init:@"templates" :String :@"" :NO]];
    [self RegistProperty:[[doProperty alloc]init:@"isHeaderVisible" :Bool :@"false" :YES]];
    [self RegistProperty:[[doProperty alloc]init:@"isFooterVisible" :Bool :@"false" :YES]];
    [self RegistProperty:[[doProperty alloc]init:@"headerView" :String :@"" :YES]];
    [self RegistProperty:[[doProperty alloc]init:@"footerView" :String :@"" :YES]];
    [self RegistProperty:[[doProperty alloc]init:@"isShowbar" :Bool :@"true" :YES]];
    [self RegistProperty:[[doProperty alloc]init:@"selectedColor" :String :@"" :YES]];
    [self RegistProperty:[[doProperty alloc]init:@"bounces" :Bool :@"true" :NO]];
}
- (void)DidLoadView
{
    [super DidLoadView];
    
    [((do_ListView_UIView *)self.CurrentUIModuleView) loadModuleJS];
}
- (void)eventOn:(NSString *)onEvent
{
    [((do_ListView_UIView *)self.CurrentUIModuleView) eventName:onEvent :@"on"];
}

- (void)eventOff:(NSString *)offEvent
{
    [((do_ListView_UIView *)self.CurrentUIModuleView) eventName:offEvent :@"off"];
}
@end
