//
//  TYPEID_View.m
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_ListView_UIView.h"

#import "doUIModuleHelper.h"
#import "doScriptEngineHelper.h"
#import "doInvokeResult.h"
#import "doIPage.h"
#import "doISourceFS.h"
#import "doUIContainer.h"
#import "doJsonHelper.h"
#import "doServiceContainer.h"
#import "doIUIModuleFactory.h"
#import "doServiceContainer.h"
#import "doILogEngine.h"
#import "doEGORefreshTableHeaderView.h"
#import "doTextHelper.h"
#import "doIDataFS.h"
#import "doDefines.h"

@interface do_ListView_UIView()<doEGORefreshTableDelegate>
@property (nonatomic,strong) doEGORefreshTableHeaderView *doEGOHeaderView;
@property (nonatomic,strong) UIView *footerView;
@property (nonatomic,strong) UIView *inserHeaderView;
@property (nonatomic,strong) UIActivityIndicatorView *activityView;
@property (nonatomic, assign) float currentFooterViewMoveUpOffset; // 当前footerView上拉距离
@property (nonatomic, assign) float currentHeadViewMoveDownOffset; // 当前headview下拉距离
@property (nonatomic, assign) BOOL endDrag; // 是否结束拖拽
@end
@implementation do_ListView_UIView
{
    NSMutableDictionary *_cellTemplatesDics;
    NSMutableArray* _cellTemplatesArray;
    UIColor *_selectColor;
    doUIModule *_headViewModel;
    doUIModule *_footerViewModel;
    id<doIUIModuleView> _headView;
    id<doIUIModuleView> _footView;
    id<doIListData> _dataArrays;
    NSArray *_binds;
    
    doUIContainer *_headerContainer;
    doUIContainer *_footerContainer;
    
    BOOL _isHeaderVisible;
    BOOL _isFooterVisible;
    //标示doEGOHeaderView/doEGOFooterView第一次添加
    BOOL _isHeaderFirstLoad;
    BOOL _isRefreshing;
    
    doInvokeResult *_invokeResults;
    NSMutableDictionary *_node;
    
    CGFloat estimateHeight;
    
    NSMutableDictionary *heights;
    
    BOOL _isFree;
    
    BOOL _isPosition;
    
    BOOL _pushStatus;
    
    BOOL _pullStatus;
    
    NSInteger _firstVisiblePosition;
    NSInteger _lastVisiblePosition;
    
    BOOL _isShowHeader;
    
    UILongPressGestureRecognizer *_longPress;
    
    BOOL _isEventOn;
    
    // cellModle
    NSMutableArray *cellModes;
}
#pragma mark - doIUIModuleView协议方法（必须）
//引用Model对象
- (void) LoadView: (doUIModule *) _doUIModule
{
    _model = (typeof(_model)) _doUIModule;
    _cellTemplatesDics = [[NSMutableDictionary alloc]init];
    _cellTemplatesArray = [[NSMutableArray alloc]init];
    _binds = [NSArray array];
    self.tableFooterView = [[UIView alloc]init];
    
    self.delegate = self;
    self.dataSource = self;
    
    //默认值
    self.showsVerticalScrollIndicator = YES;
    _isHeaderFirstLoad = YES;
    _isHeaderVisible = NO;
    _isFooterVisible = NO;
    _isRefreshing = NO;
    
    _selectColor = [UIColor clearColor];
    self.backgroundColor = [UIColor clearColor];
    self.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    estimateHeight = 0.0f;
    heights = [NSMutableDictionary dictionary];
    
    _isFree = NO;
    _isPosition = YES;
    _pushStatus = NO;
    _pullStatus = NO;
    
    _firstVisiblePosition = -1;
    _lastVisiblePosition = -1;
    
    _isShowHeader = NO;
    
    self.backgroundColor = [doUIModuleHelper GetColorFromString:@"#00000000" :[UIColor whiteColor]];
    
    _longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    
    _isEventOn = NO;
    
    cellModes = [NSMutableArray array];
    
    _endDrag = NO;
}

- (void)loadModuleJS
{
    if (_headerContainer) {
        NSString *header = [_model GetPropertyValue:@"headerView"];
        [_headerContainer LoadDefalutScriptFile:header];
    }
    if (_footerContainer) {
        NSString *header = [_model GetPropertyValue:@"footerView"];
        [_footerContainer LoadDefalutScriptFile:header];
    }
}

- (BOOL)findSuperView:(UIView *)v
{
    if ([v.superview isKindOfClass:[UITableViewCell class]]) {
        return YES;
    }
    if (!v.superview) {
        return NO;
    }
    return [self findSuperView:v.superview];
}
//销毁所有的全局对象
- (void) OnDispose
{
    _isFree = YES;
    [self removeGestureRecognizer:_longPress];
    _longPress = nil;
    
    self.delegate = nil;
    self.dataSource = nil;
    _model = nil;
    //自定义的全局属性
    [(doModule*)_dataArrays Dispose];
    for(doModule* module in [_cellTemplatesDics allValues]){
        [module Dispose];
    }
    for (doUIModule *cellMode in cellModes) {
        [cellMode Dispose];
    }
    [_cellTemplatesDics removeAllObjects];
    _cellTemplatesDics = nil;
    [_cellTemplatesArray removeAllObjects];
    _cellTemplatesArray = nil;
    _binds = nil;
    [_headViewModel Dispose];
    _headViewModel = nil;
    [_footerViewModel Dispose];
    _footerViewModel = nil;
    [_headView OnDispose];
    _headView = nil;
    [_footView OnDispose];
    _footView = nil;
    [_headerContainer Dispose];
    _headerContainer = nil;
    [_footerContainer Dispose];
    _footerContainer = nil;
    
    
}
//实现布局
- (void) OnRedraw
{
    //重新调整视图的x,y,w,h
    [doUIModuleHelper OnRedraw:_model];
    
    //实现布局相关的修改
    [_headView OnRedraw];
    [_footView OnRedraw];
    
    self.scrollEnabled = ![self findSuperView:self];
    
    [self layoutSubviews];
    if (!_isHeaderVisible) {
        [self.inserHeaderView removeFromSuperview];
    }
    if (!_isFooterVisible) {
        [self.footerView removeFromSuperview];
    }
}

#pragma mark - TYPEID_IView协议方法（必须）
#pragma mark - Changed_属性
/*
 如果在Model及父类中注册过 "属性"，可用这种方法获取
 NSString *属性名 = [(doUIModule *)_model GetPropertyValue:@"属性名"];
 
 获取属性最初的默认值
 NSString *属性名 = [(doUIModule *)_model GetProperty:@"属性名"].DefaultValue;
 */
- (void)change_canScrollToTop:(NSString *)newValue
{
    //自己的代码实现
    BOOL isScroll = [newValue boolValue];
    self.scrollsToTop = isScroll;
}
- (void)change_selectedColor:(NSString *)newValue
{
    UIColor *defulatCol = [doUIModuleHelper GetColorFromString:[_model GetProperty:@"selectedColor"].DefaultValue :[UIColor clearColor]];
    _selectColor = [doUIModuleHelper GetColorFromString:newValue :defulatCol];
}
- (void)change_templates:(NSString *)newValue
{
    NSArray *arrays = [newValue componentsSeparatedByString:@","];
    [_cellTemplatesDics removeAllObjects];
    [_cellTemplatesArray removeAllObjects];
    for(int i=0;i<arrays.count;i++)
    {
        NSString *modelStr = arrays[i];
        if(modelStr != nil && ![modelStr isEqualToString:@""])
        {
            [_cellTemplatesArray addObject:modelStr];
        }
    }
    if (_binds.count>0) {
        [self bindItems:_binds];
        [self refreshItems:nil];
    }
    heights = [NSMutableDictionary dictionary];
    _binds = [NSMutableArray array];
}

- (void)change_headerView:(NSString *)newValue
{
    id<doIPage> pageModel = _model.CurrentPage;
    doSourceFile *fileName = [pageModel.CurrentApp.SourceFS GetSourceByFileName:newValue];
    @try {
        if(!fileName)
        {
            [NSException raise:@"listview" format:@"无效的headView:%@",newValue,nil];
        }
        _headerContainer = [[doUIContainer alloc] init:pageModel];
        [_headerContainer LoadFromFile:fileName:nil:nil];
        _headViewModel = _headerContainer.RootView;
        if (_headViewModel == nil)
        {
            [NSException raise:@"listview" format:@"创建view失败",nil];
        }
        UIView *insertView = (UIView*)_headViewModel.CurrentUIModuleView;
        _headView = _headViewModel.CurrentUIModuleView;
        if (insertView == nil)
        {
            [NSException raise:@"listview" format:@"创建view失败"];
        }
        _isHeaderFirstLoad = NO;
        if (insertView) {
            self.inserHeaderView = insertView;
            [self addSubview:insertView];
        }
        if (pageModel.ScriptEngine) {
            [_headerContainer LoadDefalutScriptFile:newValue];
        }
        
    }
    @catch (NSException *exception) {
        [[doServiceContainer Instance].LogEngine WriteError:exception :exception.description];
        doInvokeResult* _result = [[doInvokeResult alloc]init];
        [_result SetException:exception];
    }
}
- (void)change_footerView:(NSString *)newValue
{
    id<doIPage> pageModel = _model.CurrentPage;
    doSourceFile *fileName = [pageModel.CurrentApp.SourceFS GetSourceByFileName:newValue];
    @try {
        if(!fileName)
        {
            [NSException raise:@"listview" format:@"无效的footView:%@",newValue,nil];
            return;
        }
        _footerContainer = [[doUIContainer alloc] init:pageModel];
        [_footerContainer LoadFromFile:fileName:nil:nil];
        _footerViewModel = _footerContainer.RootView;
        if (_footerViewModel == nil)
        {
            [NSException raise:@"listview" format:@"创建view失败",nil];
            return;
        }
        UIView *insertView = (UIView*)_footerViewModel.CurrentUIModuleView;
        _footView = _footerViewModel.CurrentUIModuleView;
        if (insertView == nil)
        {
            [NSException raise:@"listview" format:@"创建view失败"];
            return;
        }
        if (insertView) {
            self.footerView = insertView;
            [self addSubview:insertView];
        }
        if (pageModel.ScriptEngine) {
            [_footerContainer LoadDefalutScriptFile:newValue];
        }
        
    }
    @catch (NSException *exception) {
        [[doServiceContainer Instance].LogEngine WriteError:exception :exception.description];
        doInvokeResult* _result = [[doInvokeResult alloc]init];
        [_result SetException:exception];
    }
}

- (void)change_isShowbar:(NSString *)newValue
{
    self.showsVerticalScrollIndicator = [[doTextHelper alloc] StrToBool:newValue :NO];
}
- (void)change_isHeaderVisible:(NSString *)newValue
{
    _isHeaderVisible = [[doTextHelper alloc] StrToBool:newValue :NO];
}
- (void)change_isFooterVisible:(NSString *)newValue
{
    _isFooterVisible = [[doTextHelper alloc]StrToBool:newValue :NO];
}
- (void)change_bounces:(NSString *)newValue
{
    self.bounces = [newValue boolValue];
}
#pragma mark -
#pragma mark 重写get方法
- (doEGORefreshTableHeaderView *)doEGOHeaderView
{
    if (!_doEGOHeaderView) {
        _doEGOHeaderView = [[doEGORefreshTableHeaderView alloc]initWithFrame:CGRectMake(0, 0 - self.bounds.size.height, self.bounds.size.width, self.bounds.size.height)];
        _doEGOHeaderView.backgroundColor = [UIColor clearColor];
        _isHeaderFirstLoad = NO;
        _doEGOHeaderView.delegate = self;
        [self addSubview:_doEGOHeaderView];
    }
    return _doEGOHeaderView;
}
- (UIView *)getFooterView
{
    CGRect frame;
    if ([_dataArrays GetCount]<=0) {
        frame =  CGRectMake(0,_model.RealHeight, _model.RealWidth ,  _footerView.frame.size.height);
    }else
    {
        frame =  CGRectMake(0, self.contentSize.height, _model.RealWidth , _footerView.frame.size.height);
    }
    if (self.footerView) {
        //        self.footerView.frame = frame;
        return self.footerView;
    }
    UIView *footerView = [[UIView alloc]init];
    footerView.backgroundColor = self.backgroundColor;
    frame = CGRectMake(0, frame.origin.y, frame.size.width, 80);
    footerView.frame = frame;
    //1.创建lab
    UILabel *lab = [[UILabel alloc]init];
    lab.frame = CGRectMake(0, 0, 100, 80);
    lab.text = @"加载更多";
    lab.font = [UIFont systemFontOfSize:17];
    lab.center = CGPointMake(CGRectGetWidth(footerView.bounds)/2, CGRectGetHeight(footerView.bounds)/2);
    lab.textColor = [UIColor lightGrayColor];
    lab.textAlignment = NSTextAlignmentCenter;
    [footerView addSubview:lab];
    
    //创建progressbar
    UIActivityIndicatorView *progress = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    progress.hidesWhenStopped = YES;
    progress.frame = CGRectMake(0, 20,  footerView.frame.size.width, 80);
    progress.center = CGPointMake(CGRectGetWidth(footerView.bounds)/2-CGRectGetWidth(lab.bounds)/2-20, CGRectGetHeight(footerView.bounds)/2);
    
    self.activityView = progress;
    [footerView addSubview:progress];
    [self.footerView removeFromSuperview];
    self.footerView = footerView;
    return footerView;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (_isFree) {
        return;
    }
    UIView *headView = (UIView *)_headView;
    CGFloat realW = self.frame.size.width;
    CGFloat realH = _headViewModel.RealHeight;
    headView.frame = CGRectMake(0, -realH, realW, realH);
    CGFloat visibleTableDiffBoundsHeight = (self.bounds.size.height - MIN(self.bounds.size.height, self.contentSize.height));
    CGRect footerFrame = self.footerView.frame;
    footerFrame.size.width = self.frame.size.width;
    footerFrame.origin.y = self.contentSize.height + visibleTableDiffBoundsHeight;
    self.footerView.frame = footerFrame;
}


#pragma mark -
#pragma mark - 同步异步方法的实现
- (void)rebound:(NSArray *)parms
{
    _isRefreshing = NO;
    _pushStatus = NO;
    _pullStatus = NO;
    _isShowHeader = NO;
    _endDrag = NO;
    _currentHeadViewMoveDownOffset = 0.0;
    _currentFooterViewMoveUpOffset = 0.0;
    if (!_headView && _isHeaderVisible) {
        [self.doEGOHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self];
    }
    [UIView animateWithDuration:0.2 animations:^{
        self.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
        if (self.contentOffset.y<=0) {
            [self setContentOffset:CGPointZero animated:YES];
        }
    }];
    
    [_activityView stopAnimating];
    
    [self layoutSubviews];
}

- (void)scrollToPosition:(NSArray *)parms
{
    self.scrollEnabled = NO;
    NSDictionary * _dictParas = [parms objectAtIndex:0];
    NSInteger position = [doJsonHelper GetOneInteger:_dictParas :@"position" :0];
    BOOL isSmooth = [doJsonHelper GetOneBoolean:_dictParas :@"isSmooth" :NO];
    _isPosition = isSmooth;
    
    int row = [_dataArrays GetCount];
    if (row>0) {
        if (position >= row) {
            position = row-1;
        }else if (position < 0){
            position = 0;
        }
    }else
        position = NSNotFound;
    NSIndexPath *index = [NSIndexPath indexPathForRow:position inSection:0];
    [self scrollToRowAtIndexPath:index atScrollPosition:UITableViewScrollPositionTop animated:isSmooth];
    
    self.scrollEnabled = YES;
}


- (void) bindItems: (NSArray*) parms
{
    _binds = parms;
    NSDictionary * _dictParas = [parms objectAtIndex:0];
    id<doIScriptEngine> _scriptEngine = [parms objectAtIndex:1];
    NSString* _address = [doJsonHelper GetOneText: _dictParas :@"data": nil];
    @try {
        if (_address == nil || _address.length <= 0) [NSException raise:@"doListView" format:@"未指定相关的listview data参数！",nil];
        id bindingModule = [doScriptEngineHelper ParseMultitonModule: _scriptEngine : _address];
        if (bindingModule == nil) [NSException raise:@"doListView" format:@"data参数无效！",nil];
        if([bindingModule conformsToProtocol:@protocol(doIListData)])
        {
            if(_dataArrays!= bindingModule)
                _dataArrays = bindingModule;
            if ([_dataArrays GetCount]>0) {
                [self refreshItems:parms];
            }
        }
        
    }
    @catch (NSException *exception) {
        [[doServiceContainer Instance].LogEngine WriteError:exception :exception.description];
        doInvokeResult* _result = [[doInvokeResult alloc]init];
        [_result SetException:exception];
        
    }
}
- (void) refreshItems: (NSArray*) parms
{
    [self reloadData];
}
- (void)showHeader:(NSArray *)parms
{
    if (_isHeaderVisible) {
        _isShowHeader = YES;
        CGFloat headerHeight;
        if (self.inserHeaderView) {
            headerHeight = CGRectGetHeight(self.inserHeaderView.frame);
        }
        else
        {
            headerHeight = 65;
        }
        @try {
            [self scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
        } @catch (NSException *exception) {
            
        } @finally {
            
        }
        
        for (int i =1; i < headerHeight; i ++) {//模拟触发pull事件
            [self fireEvent:0 withOffsetY:i withEventName:@"pull"];
        }
        
        
        [self setContentInset:UIEdgeInsetsMake(headerHeight, 0, 0, 0)];
        if (!self.inserHeaderView) {//默认处理
            [_doEGOHeaderView setState:EGOOPullRefreshLoading];
            [_doEGOHeaderView egoRefreshScrollViewDidEndDragging:self];
        }
        //需要手动调用
        float duration = headerHeight / 65 * 0.25;
        [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
            [self setContentOffset:CGPointMake(0, -headerHeight)];
            [self fireEvent:1 withOffsetY:headerHeight withEventName:@"pull"];
        } completion:^(BOOL finished) {
            [self fireEvent:2 withOffsetY:headerHeight withEventName:@"pull"];
        }];
    }
}

#pragma mark - private methed
- (void)fireEvent:(int)state withOffsetY:(CGFloat)y withEventName :(NSString *)name
{
    if (!self.bounces && !_isShowHeader) {
        return;
    }
    if (!_invokeResults) {
        _invokeResults = [[doInvokeResult alloc] init:_model.UniqueKey];
    }
    if (!_node) {
        _node = [NSMutableDictionary dictionary];
    }
    [_node setObject:@(state) forKey:@"state"];
    [_node setObject:@(fabs(y/_model.YZoom)) forKey:@"offset"];
    [_invokeResults SetResultNode:_node];
    [_model.EventCenter FireEvent:name :_invokeResults];
}

- (void)fireScrollEvent
{
    if (_isRefreshing) {
        return;
    }
    doInvokeResult *result = [[doInvokeResult alloc]init];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    NSArray *cells = [self visibleCells];
    
    UITableViewCell *cell = [cells firstObject];
    NSIndexPath *indexFirst = [self indexPathForCell:cell];
    
    
    UITableViewCell *cell1 = [cells lastObject];
    NSIndexPath *indexLast = [self indexPathForCell:cell1];
    
    //防止调用多次
    if (_firstVisiblePosition == indexFirst.row && _lastVisiblePosition == indexLast.row) {
        return;
    }
    
    _firstVisiblePosition = indexFirst.row;
    _lastVisiblePosition = indexLast.row;
    
    [dict setObject:@(_lastVisiblePosition) forKey:@"lastVisiblePosition"];
    [dict setObject:@(_firstVisiblePosition) forKey:@"firstVisiblePosition"];
    
    [result SetResultNode:dict];
    [_model.EventCenter FireEvent:@"scroll" :result];
}
- (void)fireTouch1:(NSString*)eventName withIndexPath:(NSIndexPath *)indexPath;
{
    CGRect rectInTableView = [self rectForRowAtIndexPath:indexPath];
    CGRect rectInSuperview = [self convertRect:rectInTableView toView:[self superview]];
    doInvokeResult* invokeResult1 = [[doInvokeResult alloc]init:_model.UniqueKey];
    NSMutableDictionary *touch1Node = [NSMutableDictionary dictionary];
    [touch1Node setObject:@(indexPath.row) forKey:@"position"];
    [touch1Node setObject:@((int)(rectInSuperview.origin.y - _model.RealY) / _model.YZoom) forKey:@"y"];
    [invokeResult1 SetResultNode:touch1Node];
    [_model.EventCenter FireEvent:eventName :invokeResult1];
}
#pragma mark - tableView sourcedelegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (_cellTemplatesArray.count>0) {
        return [_dataArrays GetCount];
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self tableView:tableView getHeightForRowAtIndexPath:indexPath];
}
- (void)changeSelectColor:(UITableViewCell *)cell
{
    const CGFloat *components = CGColorGetComponents(_selectColor.CGColor);
    if (components[3] == 0) {
        return;
    }
    cell.backgroundColor = _selectColor;
    [UIView animateWithDuration:0.1 animations:^{
        cell.backgroundColor = [UIColor clearColor];
    }];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    doInvokeResult* invokeResult = [[doInvokeResult alloc]init:_model.UniqueKey];
    [invokeResult SetResultInteger:(int)indexPath.row];
    [_model.EventCenter FireEvent:@"touch":invokeResult];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [self fireTouch1:@"touch1" withIndexPath:indexPath];
    [self changeSelectColor:cell];
}
- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSNumber *h = [heights objectForKey:@(indexPath.row)];
    if (!h) {
        h = @(estimateHeight?estimateHeight:100);
    }
    return [h floatValue];
}

- (UITableViewCell *)tableView:(UITableView *)tableView getHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id jsonValue  = [NSDictionary dictionary];
    if ([_dataArrays GetCount]>0 && [_dataArrays GetCount]>(int)indexPath.row) {
        jsonValue = [_dataArrays GetData:(int)indexPath.row];
    }
    NSDictionary *dataNode = [doJsonHelper GetNode:jsonValue];
    int cellIndex = [doJsonHelper GetOneInteger: dataNode :@"template" :0];
    @try {
        if (cellIndex < 0 || cellIndex >= _cellTemplatesArray.count) {
            [NSException raise:@"listView" format:@"下标为%i的模板下标越界",(int)indexPath.row];
        }
    }
    @catch (NSException *exception) {
        [[doServiceContainer Instance].LogEngine WriteError:exception : @"模板为空或者下标越界"];
        doInvokeResult* _result = [[doInvokeResult alloc]init];
        [_result SetException:exception];
        
    }
    @finally{
    }
    
    if(cellIndex>=_cellTemplatesArray.count)cellIndex=0;
    NSString* indentify = @"";
    if (_cellTemplatesArray.count>0) {
        indentify = _cellTemplatesArray[cellIndex];
    }
    doUIModule *showCellMode;
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:indentify];
    if(!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:indentify];
        @try{
            showCellMode = [[doServiceContainer Instance].UIModuleFactory CreateUIModuleBySourceFile: indentify :_model.CurrentPage :YES];
        }@catch(NSException* err)
        {
            [[doServiceContainer Instance].LogEngine WriteError:err : @"模板不存在"];
            doInvokeResult* _result = [[doInvokeResult alloc]init];
            [_result SetException:err];
            
            return cell;
        }
        [cellModes addObject:showCellMode];//记录新建mode;
        UIView *insertView = (UIView*)showCellMode.CurrentUIModuleView;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        [[cell contentView] addSubview:insertView];
    }
    else
    {
        if (cell.contentView.subviews.count>0) {
            showCellMode = [(id<doIUIModuleView>)[cell.contentView.subviews objectAtIndex:0] GetModel];
        }
    }
    if (cell.contentView.subviews.count>0) {
        [showCellMode SetModelData:jsonValue];
        id<doIUIModuleView> modelView = showCellMode.CurrentUIModuleView;
        [modelView OnRedraw];
        
        UIView *cellView = (UIView*)showCellMode.CurrentUIModuleView;
        CGRect r = cellView.frame;
        CGFloat h = r.size.height;
        if (h<2) {
            h=2;
        }
        estimateHeight = h;
        [heights setObject:@(h) forKey:@(indexPath.row)];
    }
    return cell;
}

#pragma mark - tableView delegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSNumber *h = [heights objectForKey:@(indexPath.row)];
    if (!h) {
        [self tableView:tableView getHeightForRowAtIndexPath:indexPath];
        h = [heights objectForKey:@(indexPath.row)];
    }
    return [h floatValue];
}

#pragma mark - All GestureRecognizer Method
- (void)longPress:(UILongPressGestureRecognizer *)longPress
{
    if(longPress.state == UIGestureRecognizerStateBegan)
    {
        NSLog(@"%s",__func__);
        CGPoint tmpPointTouch = [longPress locationInView:self];
        if (longPress.state ==UIGestureRecognizerStateBegan) {
            NSIndexPath *indexPath = [self indexPathForRowAtPoint:tmpPointTouch];
            if (indexPath == nil) {
                NSLog(@"不是listView");
            }
            else
            {
                UITableViewCell *cell = [self cellForRowAtIndexPath:indexPath];
                [self changeSelectColor:cell];
                doInvokeResult* invokeResult = [[doInvokeResult alloc]init:_model.UniqueKey];
                [invokeResult SetResultInteger:(int)indexPath.row];
                [_model.EventCenter FireEvent:@"longTouch":invokeResult];
                [self fireTouch1:@"longTouch1" withIndexPath:indexPath];
            }
        }
    }
}
- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
}

-(void)tableView:(UITableView*)tableView  willDisplayCell:(UITableViewCell*) cell forRowAtIndexPath:(NSIndexPath*)indexPath
{
    [cell setBackgroundColor:[UIColor clearColor]];
}
#pragma mark - scrollView delegate
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    _endDrag = NO;
    _isPosition = YES;
    if (_isHeaderFirstLoad && _isHeaderVisible) {
        [self addSubview:self.doEGOHeaderView];
    }
    if (_isFooterVisible && !_footerView) {
        [self addSubview:[self getFooterView]];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    _endDrag = YES;
    _currentHeadViewMoveDownOffset = 0;
    _currentFooterViewMoveUpOffset = 0;
}

- (void)headViewDidScroll:(UIScrollView *) scrollView
{
    if (_isHeaderVisible) {
        if (!_headView) {
            [self.doEGOHeaderView egoRefreshScrollViewDidScroll:scrollView];
            [self dealWithHeadViewPullEventWithScrollView:scrollView];
        }
        else
        {
            [self dealWithHeadViewPullEventWithScrollView:scrollView];
        }
    }
    
}

/// 处理自定义headView/默认headView下拉手势pull事件0,1触发相关逻辑
- (void)dealWithHeadViewPullEventWithScrollView:(UIScrollView*)scrollView {
    int movedownOffset = fabs(self.contentOffset.y);
    int headHeight = _headView == nil ? 65 : CGRectGetHeight(((UIView*)_headView).frame);
    if (movedownOffset > headHeight) {
        if (!_pullStatus) {
            _pullStatus = true;
            [self fireEvent:1 withOffsetY:scrollView.contentOffset.y withEventName:@"pull"];
        }
    }else if (movedownOffset > 3 && movedownOffset <= headHeight) { // 数据有误差 范围 [0,3]
        if (movedownOffset > _currentHeadViewMoveDownOffset) {
            if (!_endDrag) {
                _pullStatus = NO;
                _currentHeadViewMoveDownOffset = movedownOffset;
                [self fireEvent:0 withOffsetY:scrollView.contentOffset.y withEventName:@"pull"];
            }
            
        }
    }
}


/// 处理自定义footView/默认footView下拉手势push事件0,1触发相关逻辑
- (void)dealWithFootViewPushEventWithScrollView:(UIScrollView*)scrollView {
    
    int footHeight = 0;
    if (_footerView) {
        footHeight = CGRectGetHeight(_footerView.frame);
    }else{
        footHeight = 80;
    }
    
    int heightDif = (int)(scrollView.contentSize.height) - (int)(self.frame.size.height);
    if ((int)(self.contentOffset.y) >= heightDif) {
        int footerViewMoveUpOffset = (int)self.contentOffset.y - heightDif;
        if (footerViewMoveUpOffset >= footHeight && !_pushStatus) {
            _pushStatus = YES;
            [self fireEvent:1 withOffsetY:footerViewMoveUpOffset  withEventName:@"push"];
        }else if (footerViewMoveUpOffset > 3 && footerViewMoveUpOffset < footHeight) { // 数据有误差 范围 [0,3]
            if (footerViewMoveUpOffset > _currentFooterViewMoveUpOffset) {
                if (!_endDrag) {
                    _currentFooterViewMoveUpOffset = footerViewMoveUpOffset;
                    _pushStatus = NO;
                    [self fireEvent:0 withOffsetY:footerViewMoveUpOffset  withEventName:@"push"];
                }
            }
        }
    }
}

- (void)footViewDidScroll:(UIScrollView *) scrollView
{
    if (_isFooterVisible) {
        if (_cellTemplatesArray.count > 0) { // 当前ListView有内容
            [self dealWithFootViewPushEventWithScrollView:scrollView];
        }else { // 当期listView无内容
            int footHeight = 0;
            if (_footerView) {
                footHeight = CGRectGetHeight(_footerView.frame);
            }else{
                footHeight = 80;
            }
            int footerViewMoveUpOffset = self.contentOffset.y;
            if (footerViewMoveUpOffset >= footHeight && !_pushStatus) {
                _pushStatus = YES;
                [self fireEvent:1 withOffsetY:footerViewMoveUpOffset  withEventName:@"push"];
            }else if (footerViewMoveUpOffset > 0 && footerViewMoveUpOffset < footHeight) {
                if (footerViewMoveUpOffset > _currentFooterViewMoveUpOffset) {
                    if (!_endDrag) {
                        _currentFooterViewMoveUpOffset = footerViewMoveUpOffset;
                        _pushStatus = NO;
                        [self fireEvent:0 withOffsetY:footerViewMoveUpOffset  withEventName:@"push"];
                    }
                }
            }
        }
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (_isPosition) {
        [self fireScrollEvent];
    }
    if (!_isRefreshing) {
        if (self.contentOffset.y<=0) {
            if (!_headView && !_isHeaderVisible) {
                return;
            }
            [self headViewDidScroll:scrollView];
        }else{
            if (!_footerView && !_isFooterVisible) {
                return;
            }
            [self footViewDidScroll:scrollView];
        }
    }
}


- (void)headViewEndDragging:(UIScrollView *)scrollView
{
    if (_isHeaderVisible) {
        UIEdgeInsets edgeInsets;
        if (_headView) {
            edgeInsets = UIEdgeInsetsMake(((UIView *)_headView).frame.size.height, 0, 0, 0);
        }
        else
        {
            edgeInsets = UIEdgeInsetsMake(60, 0, 0, 0);
        }
        if(scrollView.contentOffset.y <= edgeInsets.top*(-1))
        {
            if (_headView) {
                [UIView animateWithDuration:0.2 animations:^{
                    self.contentInset = edgeInsets;
                }];
                _isRefreshing = YES;
            }
            _pushStatus = NO;
            [self fireEvent:2 withOffsetY:scrollView.contentOffset.y withEventName:@"pull"];
        }
        
    }
}

- (void)footerViewEndDragging:(UIScrollView *)scrollView
{
    if (_isFooterVisible) {
        CGFloat diffVisibleHeight = (scrollView.bounds.size.height - MIN(scrollView.bounds.size.height, scrollView.contentSize.height));
        CGFloat defaultDiffHeight = scrollView.bounds.size.height - scrollView.contentSize.height;
        
        if((fabs(scrollView.contentOffset.y)+ defaultDiffHeight - diffVisibleHeight)>CGRectGetHeight(self.footerView.frame))
        {
            if (_isRefreshing == YES) {
                return;
            }
            _isRefreshing = YES;
            self.activityView.hidden = NO;
            [self.activityView startAnimating];
            [UIView animateWithDuration:0.2 animations:^{
                if ([_dataArrays GetCount]<=0) {
                    self.contentInset = UIEdgeInsetsMake(0, 0, self.frame.size.height + _footerView.frame.size.height, 0);
                }
                else
                {
                    self.contentInset = UIEdgeInsetsMake(0, 0, diffVisibleHeight+_footerView.frame.size.height, 0);
                }
            }];
            float value = scrollView.contentOffset.y -( scrollView.contentSize.height - scrollView.frame.size.height);
            [self fireEvent:2 withOffsetY:value withEventName:@"push"];
            _pushStatus = NO;
        }else
            [self.activityView stopAnimating];
    }
    
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!_isRefreshing) {
        if (self.contentOffset.y<=0) {
            if (!_headView && !_isHeaderVisible) {
                return;
            }
            [self headViewEndDragging:scrollView];
        }
        if (self.contentOffset.y>0) {
            if (!_footerView && !_isFooterVisible) {
                return;
            }
            [self footerViewEndDragging:scrollView];
        }
        if (!_headView && _isHeaderVisible) {
            if (self.contentOffset.y<=0) {
                [self.doEGOHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
                if(scrollView.contentOffset.y <= -60)
                    _isRefreshing = YES;
            }
        }
    }
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    _pullStatus = NO;
    _pushStatus = NO;
}
#pragma mark -
#pragma mark ego代理
- (void)egoRefreshTableDidTriggerRefresh:(EGORefreshPos)aRefreshPos
{
    _isRefreshing = NO;
}
-(BOOL)egoRefreshTableDataSourceIsLoading:(UIView *)view
{
    return _isRefreshing;
}
-(NSDate *)egoRefreshTableDataSourceLastUpdated:(UIView *)view
{
    return [NSDate date];
}
#pragma mark - doIUIModuleView协议方法（必须）<大部分情况不需修改>
- (BOOL) OnPropertiesChanging: (NSMutableDictionary *) _changedValues
{
    //属性改变时,返回NO，将不会执行Changed方法
    return YES;
}
- (void) OnPropertiesChanged: (NSMutableDictionary*) _changedValues
{
    //_model的属性进行修改，同时调用self的对应的属性方法，修改视图
    [doUIModuleHelper HandleViewProperChanged: self :_model : _changedValues ];
}
- (BOOL) InvokeSyncMethod: (NSString *) _methodName : (NSDictionary *)_dicParas :(id<doIScriptEngine>)_scriptEngine : (doInvokeResult *) _invokeResult
{
    //同步消息
    return [doScriptEngineHelper InvokeSyncSelector:self : _methodName :_dicParas :_scriptEngine :_invokeResult];
}
- (BOOL) InvokeAsyncMethod: (NSString *) _methodName : (NSDictionary *) _dicParas :(id<doIScriptEngine>) _scriptEngine : (NSString *) _callbackFuncName
{
    //异步消息
    return [doScriptEngineHelper InvokeASyncSelector:self : _methodName :_dicParas :_scriptEngine: _callbackFuncName];
}
- (doUIModule *) GetModel
{
    //获取model对象
    return _model;
}
- (void)eventName:(NSString *)event :(NSString *)type
{
    if ([event hasPrefix:@"longTouch"]) {
        if ([type isEqualToString:@"on"]) {
            [self addGestureRecognizer:_longPress];
        }
        else
        {
            [self removeGestureRecognizer:_longPress];
        }
    }else if ([event hasPrefix:@"sizeChanged"]) {
        if ([type isEqualToString:@"on"]) {
            _isEventOn = YES;
        }
        else
        {
            _isEventOn = NO;
        }
    }
}

- (void)setFrame:(CGRect)frame
{
    if (_isEventOn) {
        CGRect oldFrame = self.frame;
        if (!_invokeResults) {
            _invokeResults = [[doInvokeResult alloc] init:_model.UniqueKey];
        }
        CGFloat oldWidth = CGRectGetWidth(oldFrame)/_model.XZoom;
        CGFloat oldHeight = CGRectGetHeight(oldFrame)/_model.YZoom;
        
        CGFloat width = CGRectGetWidth(frame)/_model.XZoom;
        CGFloat height = CGRectGetHeight(frame)/_model.YZoom;
        
        NSMutableDictionary *node = [NSMutableDictionary dictionary];
        [node setObject:@(width) forKey:@"width"];
        [node setObject:@(height) forKey:@"height"];
        [node setObject:@(oldWidth) forKey:@"oldWidth"];
        [node setObject:@(oldHeight) forKey:@"oldHeight"];
        
        [_invokeResults SetResultNode:node];
        [_model.EventCenter FireEvent:@"sizeChanged" :_invokeResults];
        
    }
    [super setFrame:frame];
}

@end
