# ZYDownloadProgress
cool progress animation 酷炫的下载进度条
最近需要写个进度条动画，之前在github上看到[JSDownloadView](https://github.com/Josin22/JSDownloadView)时就想也自己实现一个，于是就去网上找了一下好看的进度条动画素材准备实现以下。
  
先把原图放一下：
![
![](http://upload-images.jianshu.io/upload_images/1249505-04140c363a414341.gif?imageMogr2/auto-orient/strip)
](http://upload-images.jianshu.io/upload_images/1249505-a143ba1e530ce372.gif?imageMogr2/auto-orient/strip)

第一个进度条出处是[这里](https://www.uplabs.com/posts/svg-pencil-download)，第二个进度条是正好在CocoaChina的一篇文章中看到保存下来的没有找到原出处；

一共做了两款进度条，但其实实现的都不是很完美。

这两个动画我完全用的是**CoreAimation**实现，由于对[POP](https://github.com/facebook/pop)不是很熟悉，不知道如何用POP实现类似**CAKeyFrameAnimation**的关键帧动画，所以没有采用POP。

具体的实现思路和上面所说的[JSDownloadView](https://github.com/Josin22/JSDownloadView)是类似的，简而言之就是分解组合动画。

**1.利用Mac自带的预览可以查看GIF中的一帧帧图像，可以具体观察GIF是如何一步步变化的，方便你拆解组合动画**

**2.取出几个关键帧方便我们回想动画实现**

![1.png](http://upload-images.jianshu.io/upload_images/1249505-c9a69d8e72b56b22.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![2.png](http://upload-images.jianshu.io/upload_images/1249505-9c17b39dcd88811e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![3.png](http://upload-images.jianshu.io/upload_images/1249505-aee247e374caaa95.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![4.png](http://upload-images.jianshu.io/upload_images/1249505-4fdbb0d7af261df2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

**3.首先我们需要把初始状态给画出来，先创建两个CAShapeLayer,此处还需要用UIBezierPath画出layer的path，如果不是很熟悉的可以看一下这个[文章](http://blog.csdn.net/u014286994/article/details/51316941)，写动画的过程中需要绘制大量的贝塞尔曲线**

我的想法是circleLayer经过动画后由圆圈变为横线进度条，箭头所用的arrowLayer变为笔，这样动画都在这两个layer上面进行，思路比较清晰

    @property (nonatomic, strong) CAShapeLayer *circleLayer; // 圆圈 -> 进度条
    @property (nonatomic, strong) CAShapeLayer *arrowLayer; // 箭头 -> 笔
    
    //绘制圆圈
    - (UIBezierPath *)circlePath
    {
        CGFloat width = self.bounds.size.width;
        CGFloat height = self.bounds.size.height;
        CGRect rect = (CGRect){(width-height)/2,0,height,height};
        return [UIBezierPath bezierPathWithOvalInRect:rect];
    }
**4.初始状态绘制好之后就需要开始动画，由上面的分解可知：** 
- 圆圈->曲线->横线;箭头->铅笔。这些都是形变只需设置**layer.path**属性即可

- 由于圆圈变为曲线这段动画需要画贝塞尔曲线比较多，而且我想到的实现方法只有利用CAKeyFrameAnimation的values设置path来实现，所以没有添加，显得这段过渡比较突兀(若有好的想法欢迎联系我)
- 可以看到箭头有一个先向上位移->然后再移动到起点的动画；
  使用CAAnimationGroup封装动画让箭头的向上跳动和变化为铅笔的动画同时进行

      // 箭头跳动->变成铅笔 动画
      - (CAAnimationGroup *)arrowSpringAnimation
      {
          //利用基本动画实现向上位移
          CABasicAnimation *arrowAnim = [CABasicAnimation animationWithKeyPath:@"position.y"];
          arrowAnim.toValue = @(self.arrowLayer.position.y-kArrowOffset);
          arrowAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
          arrowAnim.removedOnCompletion = NO;
          arrowAnim.fillMode = kCAFillModeForwards;
          arrowAnim.delegate = self;

          //其实此处使用关键帧动画  可以多写几个贝塞尔曲线加入values中使箭头变为铅笔的动画更加平滑，我此处偷懒就只写了最终状态所以变化状态不是很平滑
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

- 而圆圈则是变为曲线有一个波浪状的动画
<pre><code>
// 进度条波动动画
//实际上就是播放values中的那几帧画面造成一种波动的动画效果
- (CAKeyframeAnimation *)waveAnimation
{
    //使用关键帧动画变化circleLayer的path实现波动动画
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"path"];

    CGFloat offset = 15.f;
    //此处的方法是绘制凹凸曲线
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

//此处使用贝塞尔曲线中的方法绘制波浪曲线
//绘制出上下凹凸的曲线赋值给circleLayer来模拟波动效果
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
</code></pre>

关于此处用到的UIBezierPath还是提一下把(不熟悉的可以看一下我上面提到的那篇文章)：
调用下面这个方法绘制二次贝塞尔曲线，看下图就明白这个方法怎么使用了  
-(void)addQuadCurveToPoint:(CGPoint)endPoint controlPoint:(CGPoint)controlPoint;
![贝塞尔.png](http://upload-images.jianshu.io/upload_images/1249505-09c8770c3f9d1fed.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

- 此处动画结束后应该是箭头变为了铅笔 并且移动到了顶端，曲线也停止波动**此时需要连贯动画，继续让铅笔移动到进度条起点，并开始进度动画，**铅笔移动到起点的动画也就是绘一段移动曲线，只要能算出起点终点就没什么问题，此处不再赘述。

- 连贯动画使用的CoreAnimation的delegate，监听前一段动画结束后继续下一段动画。其实也可以使用CoreAnimation中的**beginTime**属性，只要你能将动画开始结束时间算的很清楚使用这个方法也很不错。若你使用**POP**实现动画的话，POP有动画完成的**completionBlock**则更方便

<pre><code>
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    if ([self.arrowLayer animationForKey:kArrowSpringAnimationKey] == anim) {
        if (flag) {
            // 铅笔弹起到进度条起点 准备progress动画
            [self readyForDownload];
        }
    }
}
</code></pre>

- 此时前期准备动画已经完成，铅笔移动到起点可以开始设置进度**移动铅笔**。移动铅笔我使用的方法是设置arrowLayer(铅笔)的transform，但是这样做的缺点就是你在之后算一些贝塞尔曲线的路径时，要注意**layer的transform属性**

- **改变进度条颜色**我的做法是创建一个新的layer然后通过不断设置其path来实现进度条的变化

<pre><code>
//通过不断设置transform和path来实现进度条变化
- (void)downloadingWithProgress:(CGFloat)progress
{
    progress = MIN(MAX(progress, 0.0), 1.0);
        self.progressLayer.path = [self progressPathWithProgress:progress].CGPath;
        self.arrowLayer.transform = CATransform3DMakeTranslation(progress*self.frame.size.width, 0, 0);
}
</code></pre>

**5.到此处大致的思路和主要的实现方法已经都说完了，收尾和开始的准备动画都是一样的类型，按照其中的动画组合实现即可，动画其中有很多小细节，小动画文章里都没有提到**

###总结一下：
**主要使用到的类：CABasicAnimation,CAKeyFrameAnimation,CAAnimationGroup,UIBezierPath**
**将动画通过Group，beginTime和delegate的方式按顺序组合播放即可完成一系列复杂动画**

关于animation的keypath不清楚的可以看[这里](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/CoreAnimation_guide/AnimatableProperties/AnimatableProperties.html#//apple_ref/doc/uid/TP40004514-CH11-SW1)

**相对来说第二个素材的动画更容易实现而且效果更平滑，有时间再写一下把**

**代码放在[github](https://github.com/Karthus1110/ZYDownloadProgress),喜欢的朋友欢迎star**

**写在最后：**看了代码的和实际效果的朋友若有什么改进意见 欢迎探讨，有几个效果实现起来实在差，特别第二个动画下载速度快慢时指示器角度的变化完全没有实现思路。


