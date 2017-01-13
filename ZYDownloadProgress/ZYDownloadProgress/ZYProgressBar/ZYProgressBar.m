//
//  ZYProgressBar.m
//  ZYDownloadProgress
//
//  Created by zY on 17/1/9.
//  Copyright © 2017年 zY. All rights reserved.
//

#import "ZYProgressBar.h"
#import "ZYProgressIndicator.h"

static NSString *const kIndicatorToStartAnimationKey = @"kIndicatorToStartAnimationKey";
static NSString *const kReadyForDownloadAnimationKey = @"kReadyForDownloadAnimationKey";

static CGFloat const kHighSpeedAngle = M_PI_4/3;
static CGFloat const kLowSpeedAngle = M_PI_4/4;
static CGFloat const kProgressWidth = 4.f;

@interface ZYProgressBar () <CAAnimationDelegate>
{
    BOOL _isAnimaiting;
    BOOL _hasDisplayLink;
    CGFloat _lastProgress;
}
@property (nonatomic, strong) ZYProgressIndicator *indicator;
@property (nonatomic, strong) CAShapeLayer *containerLayer;
@property (nonatomic, strong) CAShapeLayer *progressLayer;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign, readwrite) BOOL isSuccess; // 是否正在下载完成
@property (nonatomic, assign, readwrite) BOOL isDownloading; // 是否正在下载
@property (nonatomic, assign, readwrite) BOOL isOriginal; // 是否是初始状态
@end

@implementation ZYProgressBar

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self configure];
    }
    return self;
}

- (void)configure
{
    _hasDisplayLink = NO;
    _isSuccess = NO;
    _isAnimaiting = NO;
    _isDownloading = NO;
    _isOriginal = YES;
    
    _lastProgress = 0;
    [self.layer addSublayer:self.containerLayer];
    [self.layer addSublayer:self.progressLayer];
    
    self.indicator = [[ZYProgressIndicator alloc] initWithFrame:(CGRect){(self.bounds.size.width-self.bounds.size.height)/2,0,self.bounds.size.height,self.bounds.size.height}];
    __weak typeof(self) weakSelf = self;
    self.indicator.completeBlock = ^(BOOL flag){
        weakSelf.isDownloading = NO;
        if (weakSelf.completeBlock) {
            weakSelf.completeBlock(flag);
        }
    };
    [self addSubview:self.indicator];
}

#pragma mark -------------- public method ---------------
- (void)setProgress:(CGFloat)progress
{
    progress = MIN(MAX(progress, 0.0), 1.0);
    _progress = progress;
    
    if (!_isAnimaiting&&!_isSuccess) {
        //        NSLog(@"%f",progress);
        [self.indicator setProgress:progress];
    }
    
    if (_progress == 1&&_hasDisplayLink) {
        
        // 防止最后一次刷新无法进行
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.displayLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        });
        _hasDisplayLink = NO;
        _isSuccess = YES;
    }
}

- (void)startDownload
{
    if (!_isOriginal) {
        return;
    }
    _isAnimaiting = YES;
    _isDownloading = YES;
    _isOriginal = NO;
    [self.indicator readyForDownload];
    [self readyForDownload];
}

- (void)resume
{
    if (_isAnimaiting) {
        return;
    }
    
    [self.indicator resume];
    [self resumeAnimation];
    if (_hasDisplayLink) {
        [self.displayLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    }
    self.indicator.transform = CGAffineTransformIdentity;
    [self.displayLink invalidate];
    self.displayLink = nil; // 若不置为nil resume后不会调用refresh方法
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.progressLayer removeFromSuperlayer];
        [self.containerLayer removeFromSuperlayer];
        [self.indicator removeFromSuperview];
        self.progressLayer = nil;
        [self configure];
    });
}

- (void)downloadFailed
{
    if (_isOriginal) {
        return;
    }
    [self downloadFailedAnimation];
}

#pragma mark -------------- private method ---------------
- (void)resumeAnimation
{
    CABasicAnimation *transformAnim = [CABasicAnimation animationWithKeyPath:@"transform"];
    transformAnim.toValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
    transformAnim.fillMode = kCAFillModeForwards;
    transformAnim.removedOnCompletion = NO;
    transformAnim.duration = 0.3;
    [self.containerLayer addAnimation:transformAnim forKey:@"ContainerOriginAnimationKey"];
    
    UIBezierPath *movePath = [UIBezierPath bezierPath];
    CGPoint pathPoint = [self indicatorMoveToReadyPath].currentPoint;
    CGPoint startPoint = (CGPoint){CGRectGetWidth(self.frame)*_progress,pathPoint.y};
    CGPoint ctrlPoint = (CGPoint){CGRectGetWidth(self.frame)/2,CGRectGetHeight(self.frame)/2-100};
    CGPoint endPoint = self.indicator.center;
    [movePath moveToPoint:startPoint];
    [movePath addQuadCurveToPoint:endPoint controlPoint:ctrlPoint];
    
    CAKeyframeAnimation *moveAnim = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    moveAnim.path = movePath.CGPath;
    moveAnim.duration = 0.3;
    moveAnim.fillMode = kCAFillModeForwards;
    moveAnim.removedOnCompletion = NO;
    [self.indicator.layer addAnimation:moveAnim forKey:@"resumeAnimaitonKey"];
    
    CABasicAnimation *opacityAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnim.fillMode = kCAFillModeForwards;
    opacityAnim.removedOnCompletion = NO;
    opacityAnim.toValue = @(0);
    opacityAnim.duration = 0.05;
    [self.progressLayer addAnimation:opacityAnim forKey:@"progressHiddenAnim"];
}

- (void)downloadFailedAnimation
{
    _isAnimaiting = YES;
    NSTimeInterval duration = 0.5*_progress;
    CAAnimationGroup *dismissAnim = [self progressDissmissAnimation];
    dismissAnim.duration = duration;
    [self.progressLayer addAnimation:dismissAnim forKey:@"progressDissmissAnimationKey"];
    
    CALayer *downLayer = [CALayer layer];
    downLayer.anchorPoint = CGPointMake(0, 0);
    downLayer.frame = (CGRect){CGRectGetWidth(self.frame)*_progress,CGRectGetHeight(self.frame)/2,2,0};
    downLayer.backgroundColor = [UIColor whiteColor].CGColor;
    downLayer.cornerRadius = 2.5f;
    [self.layer addSublayer:downLayer];
    
    CAAnimationGroup *downAnim = [self progressDownAnimation];
    downAnim.duration = duration;
    [downLayer addAnimation:downAnim forKey:@"progressDownAnimationKey"];
    
    CAAnimationGroup *fallAnim = [self progressFallingAnimation];
    fallAnim.duration = 0.7;
    fallAnim.beginTime = CACurrentMediaTime() +duration;
    [downLayer addAnimation:fallAnim forKey:@"progressFallAnimationKey"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        [self.indicator downloadFailed];
        [downLayer removeFromSuperlayer];
    });
    
    // fail动画完成后 resume才可响应
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _isAnimaiting = NO;
    });
}

- (void)readyForDownload
{
    CGFloat x_scale = CGRectGetWidth(self.frame)/CGRectGetHeight(self.frame);
    CGFloat y_scale = kProgressWidth/CGRectGetHeight(self.frame);
    CABasicAnimation *transformAnim = [CABasicAnimation animationWithKeyPath:@"transform"];
    transformAnim.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeScale(x_scale, y_scale, 1)];
    transformAnim.duration = 0.3;
    transformAnim.fillMode = kCAFillModeForwards;
    transformAnim.removedOnCompletion = NO;
    [self.containerLayer addAnimation:transformAnim forKey:@"kContainerReadyAnimationKey"];
    
    CAAnimationGroup *indicatorAnim = [self indicatorReadyAnimation];
    indicatorAnim.delegate = self;
    [self.indicator.layer addAnimation:indicatorAnim forKey:kIndicatorToStartAnimationKey];
}

- (void)beginDownloading
{
    CAKeyframeAnimation *rotationAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnim.values = @[@(-kLowSpeedAngle),@(0)];
    rotationAnim.keyTimes = @[@(0.5),@(1.0)];
    rotationAnim.duration = 0.2;
    rotationAnim.fillMode = kCAFillModeForwards;
    rotationAnim.removedOnCompletion = NO;
    rotationAnim.delegate = self;
    [self.indicator.layer addAnimation:rotationAnim forKey:kReadyForDownloadAnimationKey];
}

- (void)refreshUI
{
    //    NSLog(@"%f",_progress);
    self.indicator.transform = CGAffineTransformMakeTranslation(CGRectGetWidth(self.frame)*_progress, 0);
    self.progressLayer.path = [self progressPathWithProgress:_progress].CGPath;
    
    //    [self refreshVelocity];
}

- (void)refreshVelocity
{
    
}

#pragma mark -------------- Animation ---------------

- (CAAnimationGroup *)indicatorReadyAnimation
{
    CAKeyframeAnimation *moveAnim = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    moveAnim.path = [self indicatorMoveToReadyPath].CGPath;
    
    CAKeyframeAnimation *rotationAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnim.values = @[@(0),@(kHighSpeedAngle)];
    rotationAnim.keyTimes = @[@(0.4),@(0.7)];
    
    CAAnimationGroup *group =[CAAnimationGroup animation];
    group.duration = 0.9;
    group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    group.animations = @[rotationAnim,moveAnim];
    group.fillMode = kCAFillModeForwards;
    group.removedOnCompletion = NO;
    return group;
}

- (CAAnimationGroup *)progressDissmissAnimation
{
    CABasicAnimation *scaleAnim = [CABasicAnimation animationWithKeyPath:@"transform"];
    scaleAnim.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeScale(1, 0, 1)];
    
    CABasicAnimation *downAnim = [CABasicAnimation animationWithKeyPath:@"position.y"];
    downAnim.toValue = @(self.progressLayer.position.y+kProgressWidth/2);
    
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.fillMode = kCAFillModeForwards;
    group.removedOnCompletion = NO;
    group.animations = @[scaleAnim,downAnim];
    return group;
}


/**
 progress持续延长  由于延长是由中心点到上下两边延长
 因此添加向下位移动画 使其看起来向单向下延伸
 @return 动画组
 */
- (CAAnimationGroup *)progressDownAnimation
{
    CABasicAnimation *scaleAnim = [CABasicAnimation animationWithKeyPath:@"bounds.size"];
    scaleAnim.toValue = [NSValue valueWithCGSize:(CGSize){1,CGRectGetWidth(self.frame)*_progress}];
    
    //进度条水面下降时 长度随之一起改变 并向下移
    CABasicAnimation *downAnim = [CABasicAnimation animationWithKeyPath:@"position.y"];
    downAnim.toValue = @((CGRectGetWidth(self.frame)*_progress)/2+3);
    downAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.fillMode = kCAFillModeForwards;
    group.removedOnCompletion = NO;
    group.animations = @[scaleAnim,downAnim];
    return group;
}


- (CAAnimationGroup *)progressFallingAnimation
{
    CABasicAnimation *moveAnim = [CABasicAnimation animationWithKeyPath:@"position.y"];
    moveAnim.toValue = @(200);
    
    CABasicAnimation *opacityAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnim.toValue = @(0);
    
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[moveAnim,opacityAnim];
    group.fillMode = kCAFillModeForwards;
    group.removedOnCompletion = NO;
    return group;
}

#pragma mark -------------- Animation Delegate ---------------
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    if ([self.indicator.layer animationForKey:kIndicatorToStartAnimationKey] == anim) {
        if (flag) {
            [self beginDownloading];
        }
    }
    
    if ([self.indicator.layer animationForKey:kReadyForDownloadAnimationKey] == anim) {
        if (flag) {
            [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            _isAnimaiting = NO;
            _hasDisplayLink = YES;
        }
    }
}

#pragma mark -------------- UIBezierPath ---------------
/**
 indicator移动路径：先向上->落下->右移一小段->左移至起点
 
 @return indicator移动路径
 */
- (UIBezierPath *)indicatorMoveToReadyPath
{
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint startPoint = self.indicator.layer.position;
    CGPoint topPoint = (CGPoint){startPoint.x,startPoint.y-40};
    CGPoint horizentalPoint = (CGPoint){startPoint.x,startPoint.y-7.5};
    CGPoint rightPoint = (CGPoint){startPoint.x+20,horizentalPoint.y};
    CGPoint leftPoint = (CGPoint){0,horizentalPoint.y};
    [path moveToPoint:startPoint];
    [path addLineToPoint:topPoint];
    [path addLineToPoint:horizentalPoint];
    [path addLineToPoint:rightPoint];
    [path addLineToPoint:leftPoint];
    return path;
}

- (UIBezierPath *)progressPathWithProgress:(CGFloat)progress
{
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint startPoint = (CGPoint){0,CGRectGetHeight(self.frame)/2};
    CGPoint endPoint = (CGPoint){CGRectGetWidth(self.frame)*progress,startPoint.y};
    [path moveToPoint:startPoint];
    [path addLineToPoint:endPoint];
    [path closePath];
    return path;
}

- (CAShapeLayer *)containerLayer
{
    if (!_containerLayer) {
        _containerLayer = [self defaultLayer];
        CGRect rect = (CGRect){(self.bounds.size.width-self.bounds.size.height)/2,0,self.bounds.size.height,self.bounds.size.height};
        _containerLayer.path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:5].CGPath;
    }
    return _containerLayer;
}

- (CAShapeLayer *)progressLayer
{
    if (!_progressLayer) {
        _progressLayer = [self defaultLayer];
        _progressLayer.lineWidth = kProgressWidth;
        _progressLayer.strokeColor = [UIColor whiteColor].CGColor;
    }
    return _progressLayer;
}

- (CAShapeLayer *)defaultLayer
{
    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.fillColor = [UIColor grayColor].CGColor;
    layer.strokeColor = [UIColor grayColor].CGColor;
    layer.lineCap = kCALineCapRound;
    layer.lineJoin = kCALineJoinRound;
    layer.frame = self.bounds;
    return layer;
}

- (CADisplayLink *)displayLink
{
    if (!_displayLink) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(refreshUI)];
    }
    return _displayLink;
}

- (void)dealloc
{
    NSLog(@"ZYProgressBar");
}

@end
