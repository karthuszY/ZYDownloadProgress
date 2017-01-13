//
//  ZYProgressIndicator.h
//  ZYDownloadProgress
//
//  Created by zY on 17/1/9.
//  Copyright © 2017年 zY. All rights reserved.
//

#import <UIKit/UIKit.h>
typedef void(^CompleteBlock)(BOOL success);
@interface ZYProgressIndicator : UIView
@property (nonatomic, assign) CGFloat progress; // [0,1]
@property (nonatomic, copy) CompleteBlock completeBlock;
- (void)readyForDownload;
- (void)resume;
- (void)downloadFailed;
@end
