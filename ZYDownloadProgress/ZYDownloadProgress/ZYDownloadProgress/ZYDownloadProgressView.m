
//
//  ZYDownloadProgressView.m
//  ZYDownloadProgress
//
//  Created by zY on 16/12/30.
//  Copyright © 2016年 zY. All rights reserved.
//

#import "ZYDownloadProgressView.h"

static CGFloat const kLineWidth = 2.5f;
static CGFloat const kArrowOffset = 100.f; // 箭头向上跳动的距离
static CGFloat const kRotationAngle = M_PI_4/3;

static NSString *const kCircleToProgressAnimationKey = @"kCircleToProgressAnimationKey";
static NSString *const kArrowSpringAnimationKey = @"kArrowSpringAnimationKey";
static NSString *const kReadyForDownloadAnimationKey = @"kReadyForDownloadAnimationKey";
static NSString *const kDownloadingAnimationKey = @"kDownloadingAnimationKey";
static NSString *const kProgressFadeAnimationKey = @"kProgressFadeAnimationKey";
static NSString *const kCompleteAnimationKey = @"kCompleteAnimationKey";

@interface ZYDownloadProgressView ()<CAAnimationDelegate>
{
    CGFloat _arrowPointOffset; // 箭头左右起点距离中心的偏移量
    CGFloat _arrowLineLength; // 箭头单边的长度
    CGFloat _verticalLineLength;
    
    CGPoint _centerXY; // 界面中心点
    CGPoint _arrowPoint; // 箭头顶点
    
    CGFloat _progressY; // 变为直线后的Y值
    
    BOOL _isAnimating; // 是否正在动画
    BOOL _isOriginal;
    
    UIColor *_progressColor;
}
@property (nonatomic, strong) CAShapeLayer *circleLayer; // 圆圈 -> 进度条
@property (nonatomic, strong) CAShapeLayer *arrowLayer; // 箭头 -> 笔
@property (nonatomic, strong) CAShapeLayer *progressLayer; //进度条
@property (nonatomic, assign, readwrite) BOOL isDownloading; // 是否正在下载
@property (nonatomic, assign, readwrite) BOOL isSuccess; // 是否正在下载完成

@end

@implementation ZYDownloadProgressView

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
    _centerXY = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);
    _progressY = (CGRectGetHeight(self.frame)/3)*2;
    
    _arrowPointOffset = (CGRectGetHeight(self.frame)/3)/2;
    _arrowLineLength = _arrowPointOffset/sin(M_PI_4);
    _verticalLineLength = CGRectGetHeight(self.frame)*5/9;
    
    _arrowPoint = CGPointMake(_centerXY.x,(CGRectGetHeight(self.frame)-_verticalLineLength)/2+_verticalLineLength);
    
    _isAnimating = YES;
    _isOriginal = YES;
    
    _progressColor = [UIColor colorWithRed:66/255. green:204/255. blue:118/255. alpha:1];
    
    self.arrowLayer.path = [self arrowPath].CGPath;
    
    [self.layer addSublayer:self.circleLayer];
    [self.layer addSublayer:self.arrowLayer];
    [self.layer addSublayer:self.progressLayer];
}

#pragma mark ------------- Public Method ------------------
- (void)resume
{
    [self.circleLayer removeFromSuperlayer];
    [self.arrowLayer removeFromSuperlayer];
    [self.progressLayer removeFromSuperlayer];
    self.circleLayer = nil;
    self.arrowLayer = nil;
    self.progressLayer = nil;
    _isDownloading = NO;
    _isSuccess = NO;
    [self configure];
}

- (void)setProgress:(CGFloat)progress
{
    _progress = progress;
    /*
     if (!_isDownloading){
     [self startDownload];
     }
     */
    if (!_isAnimating&&!self.isSuccess) {
        [self downloadingWithProgress:progress];
    }
}

- (void)startDownload
{
    if (!_isOriginal) {
        return;
    }
    
    _isDownloading = YES;
    _isOriginal = NO;
    CAAnimationGroup *circleToLineAnimation = [self circleToProgressAnimation];
    circleToLineAnimation.delegate = self;
    [self.circleLayer addAnimation:circleToLineAnimation forKey:kCircleToProgressAnimationKey];
    
    CAAnimationGroup *arrowSpringAnim = [self arrowSpringAnimation];
    arrowSpringAnim.delegate = self;
    [self.arrowLayer addAnimation:arrowSpringAnim forKey:kArrowSpringAnimationKey];
}

#pragma mark ------------- Private Method ------------------
/**
 铅笔移动到起点  准备进度条下载动画
 */
- (void)readyForDownload
{
    /*
     CABasicAnimation *rotationAnim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
     rotationAnim.toValue = @(-kRotationAngle);
     rotationAnim.removedOnCompletion = NO;
     rotationAnim.duration = 0.2f;
     rotationAnim.fillMode = kCAFillModeForwards;
     [self.arrowLayer addAnimation:rotationAnim forKey:nil];
     
     CAAnimationGroup *moveAnim = [self pencilMoveAnimation];
     moveAnim.beginTime = CACurrentMediaTime() +0.2f;
     moveAnim.delegate = self;
     [self.arrowLayer addAnimation:moveAnim forKey:kReadyForDownloadAnimationKey];
     */
    
    /*
     若不使用transform而使用BasicAnimation改变rotation，铅笔会在进度条位移动画中抖动
     TODO  猜测为没有改变layer的实际rotation导致
     */
    [UIView animateWithDuration:0.2
                     animations:^{
                         self.arrowLayer.transform = CATransform3DMakeRotation(kRotationAngle, 0, 0, 1);
                     }
                     completion:^(BOOL finished) {
                         CAAnimationGroup *moveAnim = [self pencilMoveAnimation];
                         moveAnim.delegate = self;
                         [self.arrowLayer addAnimation:moveAnim forKey:kReadyForDownloadAnimationKey];
                     }];
    
}

- (void)downloadingWithProgress:(CGFloat)progress
{
    progress = MIN(MAX(progress, 0.0), 1.0);
    if (!self.isSuccess) {
        self.progressLayer.path = [self progressPathWithProgress:progress].CGPath;
        self.arrowLayer.transform = CATransform3DMakeTranslation(progress*self.frame.size.width, 0, 0);
        [UIView animateWithDuration:0.2 animations:^{
            self.arrowLayer.transform = CATransform3DRotate(self.arrowLayer.transform, -kRotationAngle, 0, 0, 1);
        }];
    }
    
    if (progress==1) {
        // 将铅笔调为垂直
        self.isSuccess = YES;
        [UIView animateWithDuration:0.2
                         animations:^{
                             self.arrowLayer.transform = CATransform3DRotate(self.arrowLayer.transform, kRotationAngle, 0, 0, 1);
                         }
                         completion:^(BOOL finished) {
                             [self downloadComplete];
                         }];
    }
    
}

- (void)downloadComplete
{
    CAAnimationGroup *pencilAnim = [self pencilCompleteAnimation];
    pencilAnim.beginTime = CACurrentMediaTime() + 0.1;
    pencilAnim.duration = 0.4;
    pencilAnim.delegate = self;
    [self.arrowLayer addAnimation:pencilAnim forKey:kCompleteAnimationKey];
    
    CAAnimationGroup *circleAnim = [self progressCompleteAnimationHidden:NO];
    circleAnim.duration = 0.5;
    [self.circleLayer addAnimation:circleAnim forKey:nil];
    
    CAAnimationGroup *progressAnim = [self progressCompleteAnimationHidden:YES];
    progressAnim.duration = circleAnim.duration;
    progressAnim.delegate = self;
    [self.progressLayer addAnimation:progressAnim forKey:kProgressFadeAnimationKey];
}

#pragma mark ------------- Animation ------------------

- (CAAnimationGroup *)circleToProgressAnimation
{
    CAKeyframeAnimation *waveAnim = [self waveAnimation];
    
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[waveAnim];
    group.duration = 0.6f;
    group.removedOnCompletion = NO;
    group.fillMode = kCAFillModeForwards;
    return group;
}

// 圆圈变为线状进度条动画
- (CAKeyframeAnimation *)circleToLineAnimation
{
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"path"];
    
    return animation;
}

#warning TODO 变为直线进度条时会有一帧右凹动画 猜测为：绘制直线path时造成
// 进度条波动动画
- (CAKeyframeAnimation *)waveAnimation
{
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"path"];
    
    CGFloat offset = 15.f;
    
    UIBezierPath *firConcavePath = [self concaveLinePathWithOffset:offset*2];
    UIBezierPath *secConcavePath = [self concaveLinePathWithOffset:offset];
    UIBezierPath *firConvexPath = [self convexLinePathWithOffset:offset];
    UIBezierPath *secConvexPath = [self convexLinePathWithOffset:offset*2];
    UIBezierPath *thrConvexPath = [self convexLinePathWithOffset:offset];
    UIBezierPath *horizonPath = [self horizontalLinePath];
    
    // 将圆进行凹凸动画最终变为直线
    animation.values = @[
                         (__bridge id)firConcavePath.CGPath,
                         (__bridge id)secConcavePath.CGPath,
                         (__bridge id)firConvexPath.CGPath,
                         (__bridge id)secConvexPath.CGPath,
                         (__bridge id)thrConvexPath.CGPath,
                         (__bridge id)horizonPath.CGPath
                         ];
    
    //    animation.keyTimes = @[@(0),@(0.2),@(0.4),@(0.6),@(0.8),@(1.0)];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    animation.fillMode = kCAFillModeForwards;
    animation.removedOnCompletion = NO;
    return animation;
}

// 箭头跳动->变成铅笔 动画
- (CAAnimationGroup *)arrowSpringAnimation
{
    CABasicAnimation *arrowAnim = [CABasicAnimation animationWithKeyPath:@"position.y"];
    arrowAnim.toValue = @(self.arrowLayer.position.y-kArrowOffset);
    arrowAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    arrowAnim.removedOnCompletion = NO;
    arrowAnim.fillMode = kCAFillModeForwards;
    arrowAnim.delegate = self;
    
    CAKeyframeAnimation *pencilAnim = [CAKeyframeAnimation animationWithKeyPath:@"path"];
    UIBezierPath *pencilPath = [self pencilPath];
    pencilAnim.removedOnCompletion = NO;
    pencilAnim.fillMode = kCAFillModeForwards;
    pencilAnim.values = @[(__bridge id)pencilPath.CGPath];
    pencilAnim.keyTimes = @[@(1.0)];
    
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[arrowAnim,pencilAnim];
    group.removedOnCompletion = NO;
    group.fillMode = kCAFillModeForwards;
    
    return group;
}

// 笔移动到起点
- (CAAnimationGroup *)pencilMoveAnimation
{
    /*
     CABasicAnimation *rotationAnim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
     rotationAnim.toValue = @(kRotationAngle);
     rotationAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
     rotationAnim.removedOnCompletion = NO;
     rotationAnim.fillMode = kCAFillModeForwards;
     */
    
    CAKeyframeAnimation *moveAnim = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    moveAnim.path = [self pencilMoveToStartPath].CGPath;
    moveAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    moveAnim.removedOnCompletion = NO;
    moveAnim.fillMode = kCAFillModeForwards;
    
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[moveAnim];
    group.fillMode = kCAFillModeForwards;
    group.removedOnCompletion = NO;
    group.duration = 0.5f;
    return group;
}


/**
 progress形变、颜色渐变动画
 
 @param hidden 是否有opacity变化
 @return progress形变、颜色渐变动画组
 */
- (CAAnimationGroup *)progressCompleteAnimationHidden:(BOOL)hidden
{
    CGFloat maxRadius = self.frame.size.height;
    UIBezierPath *firPath = [self concaveLinePathWithOffset:30];
    UIBezierPath *secPath = [self arcWithRadius:maxRadius*4/5 angle:M_PI*3/4];
    UIBezierPath *thrPath = [self arcWithRadius:maxRadius*2/3 angle:2*M_PI*3/4];
    UIBezierPath *fourPath = [self arcWithRadius:maxRadius/2 angle:M_PI*2-M_PI_4];
    UIBezierPath *fivePath = [self arcWithRadius:maxRadius/2 angle:M_PI*2];
    
    CAKeyframeAnimation *transformAnim = [CAKeyframeAnimation animationWithKeyPath:@"path"];
    transformAnim.removedOnCompletion = NO;
    transformAnim.fillMode = kCAFillModeForwards;
    transformAnim.values = @[(__bridge id)firPath.CGPath,
                             (__bridge id)secPath.CGPath,
                             (__bridge id)thrPath.CGPath,
                             (__bridge id)fourPath.CGPath,
                             (__bridge id)fivePath.CGPath
                             ];
    //    transformAnim.keyTimes = @[@(0.2),@(0.4),@(0.6),@(0.8),@(1.0)];
    //    transformAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    
    CABasicAnimation *opacityAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnim.removedOnCompletion = NO;
    opacityAnim.fillMode = kCAFillModeForwards;
    opacityAnim.fromValue = @(1.0);
    opacityAnim.toValue = @(0);
    
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.removedOnCompletion = NO;
    group.fillMode = kCAFillModeForwards;
    if (hidden) {
        group.animations = @[transformAnim,opacityAnim];
    }else{
        group.animations = @[transformAnim];
    }
    return group;
}

/**
 铅笔-> ✔️
 铅笔旋转、位移、形变
 @return 下载完成铅笔动画
 */
- (CAAnimationGroup *)pencilCompleteAnimation
{
    CABasicAnimation *rotationAnim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnim.toValue = @(M_PI*2);
    //    rotationAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    rotationAnim.removedOnCompletion = NO;
    rotationAnim.fillMode = kCAFillModeForwards;
    
    CAKeyframeAnimation *moveAnim = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    moveAnim.path = [self pencilMoveToEndPath].CGPath;
    moveAnim.removedOnCompletion = NO;
    moveAnim.fillMode = kCAFillModeForwards;
    
    CAKeyframeAnimation *pathAnim = [CAKeyframeAnimation animationWithKeyPath:@"path"];
    pathAnim.values = @[(__bridge id)[self pencilPath].CGPath,
                        (__bridge id)[self pencilPath].CGPath,
                        (__bridge id)[self successPath].CGPath];
    pathAnim.keyTimes = @[@(0.2),@(0.4),@(0.8)];
    
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[rotationAnim,moveAnim,pathAnim];
    group.removedOnCompletion = NO;
    group.fillMode = kCAFillModeForwards;
    group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    return group;
}


#pragma mark ------------- BezierPath ------------------
- (UIBezierPath *)arrowPath
{
    UIBezierPath *arrowPath = [UIBezierPath bezierPath];
    
    CGFloat y_offset = _verticalLineLength/2-_arrowLineLength;
    
    CGPoint startPoint = CGPointMake(_centerXY.x-_arrowPointOffset, _centerXY.y+y_offset);
    CGPoint bottomPoint = _arrowPoint;
    CGPoint rightPoint = CGPointMake(_centerXY.x+_arrowPointOffset, startPoint.y);
    CGPoint endPoint = CGPointMake(_arrowPoint.x, _arrowPoint.y-_verticalLineLength);
    
    [arrowPath moveToPoint:startPoint];
    [arrowPath addLineToPoint:bottomPoint];
    [arrowPath addLineToPoint:rightPoint];
    [arrowPath moveToPoint:bottomPoint];
    [arrowPath addLineToPoint:endPoint];
    
    return arrowPath;
}

- (UIBezierPath *)circlePath
{
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    CGRect rect = (CGRect){(width-height)/2,0,height,height};
    return [UIBezierPath bezierPathWithOvalInRect:rect];
}

- (UIBezierPath *)horizontalLinePath
{
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint startPoint = CGPointMake(0, _progressY);
    CGPoint endPoint = CGPointMake(CGRectGetWidth(self.frame), startPoint.y);
    [path moveToPoint:startPoint];
    [path addLineToPoint:endPoint];
    return path;
}

- (UIBezierPath *)pencilPath
{
    CGFloat width = 8.f;
    CGFloat height = 35.f;
    UIBezierPath *path = [UIBezierPath bezierPath];
    /*
     画铅笔路径
     _    _    _    _
     _   _|  _|  |_|  |_|  |_|
     \     \/
     */
    CGPoint startPoint = CGPointMake(self.arrowLayer.position.x-width/2, self.arrowLayer.position.y);
    CGPoint point1 = CGPointMake(startPoint.x+width, startPoint.y);
    CGPoint point2 = CGPointMake(point1.x, point1.y-height);
    CGPoint point3 = CGPointMake(startPoint.x, point2.y);
    CGPoint point4 = CGPointMake(self.arrowLayer.position.x, startPoint.y+7);
    
    [path moveToPoint:startPoint];
    [path addLineToPoint:point1];
    [path addLineToPoint:point2];
    [path addLineToPoint:point3];
    [path addLineToPoint:startPoint];
    [path addLineToPoint:point4];
    [path addLineToPoint:point1];
    [path closePath];
    return path;
}


/**
 下载完成的勾✔️
 
 @return 完成的勾path
 */
- (UIBezierPath *)successPath
{
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint startPoint = (CGPoint){_centerXY.x-self.frame.size.height*1/4,_centerXY.y+4};
    CGPoint endPoint = (CGPoint){_centerXY.x+(self.frame.size.height)*2/7,(self.frame.size.height)*1/3};
    [path moveToPoint:startPoint];
    [path addLineToPoint:_arrowPoint];
    [path addLineToPoint:endPoint];
    return path;
}

/**
 进度条路径
 
 @return 进度条
 */
- (UIBezierPath *)progressPathWithProgress:(CGFloat)progress
{
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint startPoint = CGPointMake(0, _progressY);
    CGPoint endPoint = CGPointMake(self.frame.size.width*progress, _progressY);
    //    NSLog(@"%f",progress);
    [path moveToPoint:startPoint];
    [path addLineToPoint:endPoint];
    return path;
}

/**
 pencil移动到进度条起点动画
 
 @return 动画路径
 */
- (UIBezierPath *)pencilMoveToStartPath
{
    UIBezierPath *movePath = [UIBezierPath bezierPath];
    CGPoint startPoint = (CGPoint){self.arrowLayer.position.x,self.arrowLayer.position.y-kArrowOffset}; // 上移之后的pencil position
    CGPoint ctrlPoint = CGPointMake(startPoint.x/2, startPoint.y+20);
    CGPoint endPoint = CGPointMake(2, _progressY-9); // 微调箭头
    
    [movePath moveToPoint:startPoint];
    [movePath addQuadCurveToPoint:endPoint controlPoint:ctrlPoint];
    return movePath;
}

/**
 pencil从progress终点移动到圆圈
 
 @return 动画路径
 */
- (UIBezierPath *)pencilMoveToEndPath
{
    UIBezierPath *movePath = [UIBezierPath bezierPath];
    CGPoint startPoint = (CGPoint){0,_progressY-9}; // 因为有transform关于x的位移 会影响动画 此处减去位移
    CGPoint ctrlPoint = CGPointMake(startPoint.x+self.frame.size.width/4, startPoint.y+100);
    CGPoint endPoint = (CGPoint){self.arrowLayer.position.x-self.frame.size.width,self.arrowLayer.position.y};
    
    [movePath moveToPoint:startPoint];
    [movePath addQuadCurveToPoint:endPoint controlPoint:ctrlPoint];
    return movePath;
}


/**
 根据offset来生成不同曲度的凹线
 
 @param offset offset越大 曲度越大
 @return 下凹曲线
 */
- (UIBezierPath *)concaveLinePathWithOffset:(CGFloat)offset
{
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint startPoint = CGPointMake(0,_progressY+offset/2);
    CGPoint ctrlPoint = CGPointMake(CGRectGetWidth(self.frame)/2,startPoint.y+offset);
    CGPoint endPoint = CGPointMake(CGRectGetWidth(self.frame),startPoint.y);
    
    [path moveToPoint:startPoint];
    [path addQuadCurveToPoint:endPoint controlPoint:ctrlPoint];
    return path;
}

/**
 根据offset来生成不同曲度的凸线
 
 @param offset offset越大 曲度越大
 @return 上凸曲线
 */
- (UIBezierPath *)convexLinePathWithOffset:(CGFloat)offset
{
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint startPoint = CGPointMake(0,_progressY-offset/2);
    CGPoint ctrlPoint = CGPointMake(CGRectGetWidth(self.frame)/2,startPoint.y-offset);
    CGPoint endPoint = CGPointMake(CGRectGetWidth(self.frame),startPoint.y);
    
    [path moveToPoint:startPoint];
    [path addQuadCurveToPoint:endPoint controlPoint:ctrlPoint];
    return path;
}

/**
 根据角度生成弧线
 
 @param radius 半径
 @param angle 角度
 @return 弧线path
 */
- (UIBezierPath *)arcWithRadius:(CGFloat)radius angle:(CGFloat)angle
{
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint center = (CGPoint){self.arrowLayer.position.x,self.arrowLayer.position.y+self.frame.size.height/2-radius};
    CGFloat startAngle = (M_PI-angle)/2;
    CGFloat endAngle = startAngle+angle;
    [path addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
    return path;
}

#pragma mark ------------- Layer ------------------
- (CAShapeLayer *)circleLayer
{
    if (!_circleLayer) {
        _circleLayer = [self defaultShapeLayer];
        _circleLayer.strokeColor = [UIColor whiteColor].CGColor;
        _circleLayer.path = [self circlePath].CGPath;
    }
    return _circleLayer;
}

- (CAShapeLayer *)arrowLayer
{
    if (!_arrowLayer) {
        _arrowLayer = [self defaultShapeLayer];
    }
    return _arrowLayer;
}

- (CAShapeLayer *)progressLayer
{
    if (!_progressLayer) {
        _progressLayer = [self defaultShapeLayer];
        _progressLayer.strokeColor = _progressColor.CGColor;
    }
    return _progressLayer;
}

- (CAShapeLayer *)defaultShapeLayer
{
    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.fillColor = [UIColor clearColor].CGColor;
    layer.strokeColor = [UIColor whiteColor].CGColor;
    layer.lineCap = kCALineCapRound;
    layer.lineJoin = kCALineJoinRound;
    layer.frame = self.bounds;
    layer.lineWidth = kLineWidth;
    return layer;
}

#pragma mark ----------------- animaiton delegate -------------------
// 一个动画会多次回调，移除会影响效果
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    if ([self.circleLayer animationForKey:kCircleToProgressAnimationKey] == anim) {
        if (flag) {
            _isAnimating = YES;
        }
    }
    
    if ([self.arrowLayer animationForKey:kArrowSpringAnimationKey] == anim) {
        if (flag) {
            // 铅笔弹起到进度条起点 准备progress动画
            [self readyForDownload];
        }
    }
    
    if ([self.arrowLayer animationForKey:kReadyForDownloadAnimationKey] == anim) {
        if (flag) {
            // 铅笔到达起点  可以开始进度条动画
            _isAnimating = NO;
        }
    }
    
    if ([self.progressLayer animationForKey:kProgressFadeAnimationKey] == anim) {
        if (flag) {
            self.progressLayer.opacity = 0;
        }
    }
    
    if ([self.arrowLayer animationForKey:kCompleteAnimationKey] == anim) {
        if (flag) {
            // 动画结束
            _isDownloading = NO;
            if (self.completeBlock) {
                self.completeBlock(flag);
            }
        }
    }
    
}

- (void)dealloc
{
    NSLog(@"PROGRESS");
}

@end
