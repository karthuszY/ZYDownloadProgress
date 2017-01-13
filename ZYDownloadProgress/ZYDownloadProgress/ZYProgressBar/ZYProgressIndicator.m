//
//  ZYProgressIndicator.m
//  ZYDownloadProgress
//
//  Created by zY on 17/1/9.
//  Copyright © 2017年 zY. All rights reserved.
//

#import "ZYProgressIndicator.h"

static NSTimeInterval const duration = 0.3;
static NSString *const kTriangleOriginAnimationKey = @"kTriangleOriginAnimationKey";
static NSString *const kTriangleReadyAnimationKey = @"kTriangleReadyAnimationKey";
static NSString *const kRectangleOriginAnimationKey = @"kRectangleOriginAnimationKey";
static NSString *const kRectangleReadyAnimationKey = @"kRectangleReadyAnimationKey";

@interface ZYProgressIndicator ()
{
    CGFloat _beginX;
    CGFloat _beginY;
}
@property (nonatomic, strong) CAShapeLayer *triangleLayer;
@property (nonatomic, strong) CAShapeLayer *rectangleLayer;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, assign) BOOL isSuccess;
@end

@implementation ZYProgressIndicator

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
    self.triangleLayer = [self defaultLayer];
    self.rectangleLayer = [self defaultLayer];
    [self.layer addSublayer:self.triangleLayer];
    [self.layer addSublayer:self.rectangleLayer];
    
    self.progressLabel = [[UILabel alloc] init];
    self.progressLabel.frame = (CGRect){0,CGRectGetHeight(self.frame)/2-17,CGRectGetWidth(self.frame),15};
    self.progressLabel.textAlignment = NSTextAlignmentCenter;
    self.progressLabel.font = [UIFont systemFontOfSize:10];
    [self addSubview:self.progressLabel];
    [self orginalState];
}

- (void)setProgress:(CGFloat)progress
{
    _progress = progress;
    self.progressLabel.text = [NSString stringWithFormat:@"%d%%",(int)(100*progress)];
    if (progress==1) {
        [self downloadSuccess];
        _isSuccess = YES;
    }
}

- (CAShapeLayer *)defaultLayer
{
    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.fillColor = [UIColor whiteColor].CGColor;
    layer.strokeColor = [UIColor whiteColor].CGColor;
    layer.lineCap = kCALineCapRound;
    layer.lineJoin = kCALineJoinRound;
    layer.frame = self.bounds;
    return layer;
}

- (void)orginalState
{
    CGFloat width = CGRectGetWidth(self.frame);
    CGFloat height = CGRectGetHeight(self.frame);
    
    CGFloat triangle_height = height/4;
    CGFloat triangle_width = width/2;
    CGFloat rectangle_width = triangle_width/2;
    CGFloat rectangle_height = triangle_height;
    
    CGRect rectangleRect = (CGRect){(width-rectangle_width)/2,triangle_height,rectangle_width,rectangle_height};
    
    UIBezierPath *rectanglePath = [UIBezierPath bezierPathWithRoundedRect:rectangleRect cornerRadius:1];
    
    self.rectangleLayer.path = rectanglePath.CGPath;
    
    CGPoint startPoint = (CGPoint){(width-triangle_width)/2,height/2};
    CGPoint bottomPoint = (CGPoint){width/2,height-triangle_height};
    CGPoint endPoint = (CGPoint){startPoint.x+triangle_width,startPoint.y};
    UIBezierPath *triganlePath = [UIBezierPath bezierPath];
    [triganlePath moveToPoint:startPoint];
    [triganlePath addLineToPoint:bottomPoint];
    [triganlePath addLineToPoint:endPoint];
    [triganlePath closePath];
    self.triangleLayer.path = triganlePath.CGPath;
}

- (void)readyForDownload
{
    self.progressLabel.hidden = NO;
    
    CABasicAnimation *triAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
    triAnimation.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeScale(0.3, 0.3, 1)];
    triAnimation.duration = duration;
    triAnimation.fillMode = kCAFillModeForwards;
    triAnimation.removedOnCompletion = NO;
    [self.triangleLayer addAnimation:triAnimation forKey:kTriangleReadyAnimationKey];
    
    CABasicAnimation *recAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
    recAnimation.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeScale(1.5, 0.9, 1)];
    recAnimation.duration = duration;
    recAnimation.fillMode = kCAFillModeForwards;
    recAnimation.removedOnCompletion = NO;
    [self.rectangleLayer addAnimation:recAnimation forKey:kRectangleReadyAnimationKey];
    
}

- (void)resume
{
    self.progressLabel.hidden = YES;
    
    CABasicAnimation *triAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
    triAnimation.toValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
    triAnimation.duration = duration;
    triAnimation.fillMode = kCAFillModeForwards;
    triAnimation.removedOnCompletion = NO;
    [self.triangleLayer addAnimation:triAnimation forKey:kTriangleOriginAnimationKey];
    
    CABasicAnimation *recAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
    recAnimation.toValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
    recAnimation.duration = duration;
    recAnimation.fillMode = kCAFillModeForwards;
    recAnimation.removedOnCompletion = NO;
    [self.rectangleLayer addAnimation:recAnimation forKey:kRectangleOriginAnimationKey];
    
    if (!_isSuccess) {
        CABasicAnimation *rotationAnim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotationAnim.toValue = @(0);
        rotationAnim.fillMode = kCAFillModeForwards;
        rotationAnim.removedOnCompletion = NO;
        rotationAnim.duration = 0.1;
        [self.layer addAnimation:rotationAnim forKey:@"downloadFailedAnim"];
    }
}

- (void)downloadSuccess
{
    if (self.completeBlock) {
        self.completeBlock(YES);
    }
    
    self.progressLabel.text = @"done";
    self.progressLabel.textColor = [UIColor greenColor];
    
    CABasicAnimation *rotationAnim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.y"];
    rotationAnim.toValue = @(M_PI);
    //    rotationAnim.fillMode = kCAFillModeForwards;
    //    rotationAnim.removedOnCompletion = NO;
    // 视觉误差移除动画 否则文字会反转
    rotationAnim.duration = 0.2;
    /*
     单独加在self.layer上在某种进度条速度时会出现BUG ZYPogressBar中的progressLayer残缺 ？？？？
     */
    //    [self.layer addAnimation:rotationAnim forKey:@"downloadSuccessAnim"];
    
    [self.rectangleLayer addAnimation:rotationAnim forKey:nil];
    [self.triangleLayer addAnimation:rotationAnim forKey:nil];
    [self.progressLabel.layer addAnimation:rotationAnim forKey:nil];
    
}

- (void)downloadFailed
{
    _isSuccess = NO;
    
    self.progressLabel.text = @"failed";
    self.progressLabel.textColor = [UIColor redColor];
    
    CABasicAnimation *rotationAnim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnim.toValue = @(M_PI_4/3);
    rotationAnim.fillMode = kCAFillModeForwards;
    rotationAnim.removedOnCompletion = NO;
    rotationAnim.duration = 0.2;
    [self.layer addAnimation:rotationAnim forKey:@"downloadFailedAnim"];
}
@end
