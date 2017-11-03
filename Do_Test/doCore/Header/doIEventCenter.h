//
//  doIEventCenter.h
//  DoCore
//
//  Created by wl on 16/6/2.
//  Copyright © 2016年 DongXian. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol doIEventCenter <NSObject>
- (void)eventOn:(NSString *)onEvent;
- (void)eventOff:(NSString *)offEvent;
@end
