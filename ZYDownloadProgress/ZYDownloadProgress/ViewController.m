//
//  ViewController.m
//  ZYDownloadProgress
//
//  Created by zY on 16/12/30.
//  Copyright © 2016年 zY. All rights reserved.
//

#import "ViewController.h"
#import "ZYDownloadProgressView.h"
#import "ZYProgressBar.h"

@interface ViewController ()
{
    ZYDownloadProgressView *_progressView;
    ZYProgressBar *_progressBar;
    CGFloat _progress;
}
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIColor *blueColor = [UIColor colorWithRed:142/255. green:206/255. blue:237/255. alpha:1];
    
    self.view.backgroundColor = blueColor;
    
    CGFloat width = 200.f;
    _progressView = [[ZYDownloadProgressView alloc] initWithFrame:(CGRect){(self.view.bounds.size.width-width)/2,200,width,80}];
    _progressView.backgroundColor = blueColor;
    [self.view addSubview:_progressView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(progressViewDownload)];
    [_progressView addGestureRecognizer:tap];
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = (CGRect){20,50,80,44};
    [button setTitle:@"resume" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(resumeProgressView) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    _progressBar = [[ZYProgressBar alloc] initWithFrame:(CGRect){(self.view.bounds.size.width-width)/2,400,width,80}];
    [self.view addSubview:_progressBar];
    
    UIButton *resumeBarBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    resumeBarBtn.frame = (CGRect){20,CGRectGetMaxY(_progressBar.frame)+20,80,44};
    [resumeBarBtn setTitle:@"resume" forState:UIControlStateNormal];
    [resumeBarBtn addTarget:self action:@selector(resumeProgressBar) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:resumeBarBtn];
    
    UIButton *failedBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    failedBtn.frame = (CGRect){120,CGRectGetMaxY(_progressBar.frame)+20,80,44};
    [failedBtn setTitle:@"failed" forState:UIControlStateNormal];
    [failedBtn addTarget:self action:@selector(downloadFailed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:failedBtn];
    
    UITapGestureRecognizer *tapBar = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(progressBarDownload)];
    [_progressBar addGestureRecognizer:tapBar];
}

#pragma mark ------------------ ZYDownloadProgress ---------------------

- (void)progressViewDownload
{
    if (!_progressView.isDownloading) {
        [_progressView startDownload];
        [self stopTimer];
        self.timer = [self timerWithSelector:@selector(getProgress)];
        
        __weak typeof(self) weakSelf = self;
        _progressView.readyBlock = ^(BOOL ready){
            if (ready) {
                [weakSelf.timer setFireDate:[NSDate date]];
            }
        };
    }
}
- (void)getProgress
{
    _progress += 0.01;
    _progressView.progress = _progress;
    _progressView.completeBlock = ^(BOOL success){
        if (success) {
            NSLog(@"download complete");
        }
    };
}

- (void)resumeProgressView
{
    _progress = 0;
    [_progressView resume];
}

- (void)stopTimer
{
    [_timer invalidate];
    _timer = nil;
}

- (NSTimer *)timerWithSelector:(SEL)selector
{
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:selector userInfo:nil repeats:YES];
    return timer;
}

#pragma mark ------------------ ZYProgressBar ---------------------

- (void)progressBarDownload
{
    if (!_progressBar.isOriginal) {
        return;
    }
    _progress = 0;
    [_progressBar startDownload];
    [self stopTimer];
    self.timer = [self timerWithSelector:@selector(setBarProgress)];    
    
    __weak typeof(self) weakSelf = self;
    _progressBar.readyBlock = ^(BOOL ready){
        if (ready) {
            [weakSelf.timer setFireDate:[NSDate date]];
        }
    };
}

- (void)setBarProgress
{
    _progress += 0.01;
    _progressBar.progress = _progress;
}

- (void)resumeProgressBar
{
    _progress = 0;
    [self stopTimer];
    [_progressBar resume];
}

- (void)downloadFailed
{
    [_progressBar downloadFailed];
    [self stopTimer];
}

@end
