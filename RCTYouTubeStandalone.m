#import "RCTYouTubeStandalone.h"
#if __has_include(<XCDYouTubeKit/XCDYouTubeKit.h>)
#import <XCDYouTubeKit/XCDYouTubeKit.h>
#define XCD_YOUTUBE_KIT_INSTALLED
#endif

@implementation RCTYouTubeStandalone {
    RCTPromiseResolveBlock resolver;
    RCTPromiseRejectBlock rejecter;
};

RCT_EXPORT_MODULE();

RCT_REMAP_METHOD(playVideo,
                 playVideoWithResolver:(NSString*)videoId resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    #ifndef XCD_YOUTUBE_KIT_INSTALLED
        reject(@"error", @"XCDYouTubeKit is not installed", nil);
    #else
        dispatch_async(dispatch_get_main_queue(), ^{
            XCDYouTubeVideoPlayerViewController *videoPlayerViewController =
                [[XCDYouTubeVideoPlayerViewController alloc] initWithVideoIdentifier:videoId];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(moviePlayerPlaybackDidFinish:)
                                                         name:MPMoviePlayerPlaybackDidFinishNotification
                                                       object:videoPlayerViewController.moviePlayer];

            resolver = resolve;
            rejecter = reject;

            UIViewController *root = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
            RCTRootView *rootView = (RCTRootView*) root.view;
            NSMutableDictionary *props = [rootView.appProperties mutableCopy];

            [props setValue:@YES forKey:@"allowRotation"];
            rootView.appProperties = props;
            [root presentMoviePlayerViewControllerAnimated:videoPlayerViewController];
        });
    #endif
}

#ifdef XCD_YOUTUBE_KIT_INSTALLED
    - (void) moviePlayerPlaybackDidFinish:(NSNotification *)notification
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:MPMoviePlayerPlaybackDidFinishNotification
                                                      object:notification.object];

        UIViewController *root = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
        RCTRootView *rootView = (RCTRootView*) root.view;
        NSMutableDictionary *props = [rootView.appProperties mutableCopy];

        if ([props valueForKey:@"allowRotation"]) {
            [props setValue:@NO forKey:@"allowRotation"];
            rootView.appProperties = props;
        }

        if ([props valueForKey:@"lockOrientation"]) {
            NSInteger lockOrientation = [[props valueForKey:@"lockOrientation"] integerValue];
            [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
                [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger: lockOrientation] forKey:@"orientation"];
            }];
        }

        MPMovieFinishReason finishReason = [notification.userInfo[MPMoviePlayerPlaybackDidFinishReasonUserInfoKey] integerValue];

        if (finishReason == MPMovieFinishReasonPlaybackError)
        {
            NSError *error = notification.userInfo[XCDMoviePlayerPlaybackDidFinishErrorUserInfoKey];
            // Handle error
            rejecter(@"error", @"YTError", error);
        } else {
            resolver(@"success");
        }

        rejecter = nil;
        resolver = nil;
    }
#endif

@end
