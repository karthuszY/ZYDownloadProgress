//
//  ZYDownloadProgressView.h
//  ZYDownloadProgress
//
//  Created by zY on 16/12/30.
//  Copyright © 2016年 zY. All rights reserved.
//

#import <UIKit/UIKit.h>
typedef void(^CompleteBlock)(BOOL success);
typedef void(^ReadyBlock)(BOOL ready);

/**
 使用initWithFrame初始化
 frame.width为进度条长度 frame.height为圆直径
 调用startAnimation开始动画
 设置prgress值进度条开始移动，progress == 1时动画结束 completeBlock回调 值为YES
 */
@interface ZYDownloadProgressView : UIView

@property (nonatomic, assign, readonly) BOOL isDownloading; // 是否正在下载
@property (nonatomic, assign, readonly) BOOL isSuccess; // 是否正在下载完成
@property (nonatomic, assign) CGFloat progress; // [0,1]
@property (nonatomic, copy) CompleteBlock completeBlock;
@property (nonatomic, copy) ReadyBlock readyBlock; // 准备动画完成 可以开始下载动画

- (void)startDownload;
- (void)resume; // 重置为初始状态

@end
