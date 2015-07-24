//
//  VideoCompositor.m
//  AVCompositionTesting
//
//  Created by Simon Haycock on 24/07/2015.
//  Copyright (c) 2015 oxygn. All rights reserved.
//

#import "VideoCompositor.h"

static NSString *VideoCompositorErrorDomain = @"VideoCompositorErrorDomain";

@implementation VideoCompositor {
    
    AVMutableComposition *mutableComposition;
    AVMutableCompositionTrack *mutableCompositionVideoTrack;
    CMTime currentEndTime;
    CGRect dimensionsOfLastVideoAdded;
    
}

-(void)createNewComposition {
    mutableComposition = nil;
    mutableCompositionVideoTrack = nil;
    mutableComposition = [AVMutableComposition composition];
    mutableCompositionVideoTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    currentEndTime = kCMTimeZero;
}

-(NSError*)appendVideoWithURL:(NSURL*)inFileURL {
    NSError *error = nil;
    
    // load asset
    AVAsset *videoAsset = [AVAsset assetWithURL:inFileURL];
    
    // check
    if (![videoAsset isReadable]) {
        error = [NSError errorWithDomain:VideoCompositorErrorDomain code:kErrorNotReadable userInfo:[self errorUserInfoForErrorCode:kErrorNotReadable]];
        return error;
    }
    if (![videoAsset isComposable]) {
        error = [NSError errorWithDomain:VideoCompositorErrorDomain code:kErrorNotComposable userInfo:[self errorUserInfoForErrorCode:kErrorNotComposable]];
        return error;
    }
    if (![videoAsset isExportable]) {
        error = [NSError errorWithDomain:VideoCompositorErrorDomain code:kErrorNotExportable userInfo:[self errorUserInfoForErrorCode:kErrorNotExportable]];
        return error;
    }
    
    // get video track from asset
    AVAssetTrack *videoAssetTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    // perform test to see if composition and track are compatible
    AVMutableCompositionTrack *compatibleCompositionTrack = [mutableComposition mutableTrackCompatibleWithTrack:videoAssetTrack];
    if (!compatibleCompositionTrack) {
        error = [NSError errorWithDomain:VideoCompositorErrorDomain code:kErrorTrackNotCompatibleWithComposition userInfo:[self errorUserInfoForErrorCode:kErrorTrackNotCompatibleWithComposition]];
        return error;
    }
    
    // add track from asset into composition, at the current end time
    [mutableCompositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero,videoAssetTrack.timeRange.duration) ofTrack:videoAssetTrack atTime:currentEndTime error:nil];
    
    // increase current end time by duration of track being added
    currentEndTime = CMTimeAdd(currentEndTime, videoAssetTrack.timeRange.duration);
    
    return error;
}

-(NSError*)writeOutVideoToURL:(NSURL*)outFileURL {
    NSError *error = nil;
    
    // check if there is anything to export
    if (currentEndTime.value == kCMTimeZero.value) {
        error = [NSError errorWithDomain:VideoCompositorErrorDomain code:kErrorNoVideoToRender userInfo:[self errorUserInfoForErrorCode:kErrorNoVideoToRender]];
        return error;
    }
    
    // create export session, using passthrough preset.
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mutableComposition presetName:AVAssetExportPresetPassthrough];
    
    // output url with appropriate file extension,
    
    exporter.outputURL = outFileURL;
    
    // set file type
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = NO;
//    exporter.videoComposition = mutableComposition;
    
    // asyncronous export
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (exporter.status == AVAssetExportSessionStatusCompleted) {
                NSLog(@"export complete");
            } else {
                NSLog(@"export not completed.");
            }
        });
    }];
    
    return error;
}


-(NSDictionary*)errorUserInfoForErrorCode:(NSInteger)errorCode {
    
    NSDictionary *returnDictionary = nil;
    
    switch (errorCode) {
        case kErrorNotReadable: {
            returnDictionary = [NSDictionary dictionaryWithObject:@"Asset not readable" forKey:NSLocalizedDescriptionKey];
            break;
        }
        case kErrorNotComposable: {
            returnDictionary = [NSDictionary dictionaryWithObject:@"Asset not composable" forKey:NSLocalizedDescriptionKey];
            break;
        }
        case kErrorNotExportable: {
            returnDictionary = [NSDictionary dictionaryWithObject:@"Asset not exportable" forKey:NSLocalizedDescriptionKey];
            break;
        }
        case kErrorNoVideoToRender: {
            returnDictionary = [NSDictionary dictionaryWithObject:@"No video to export" forKey:NSLocalizedDescriptionKey];
            break;
        }
            
        default:
            break;
    }
    return returnDictionary;
}
@end
