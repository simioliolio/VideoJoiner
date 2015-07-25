//
//  VideoCompositor.m
//  AVCompositionTesting
//
//  Created by Simon Haycock on 24/07/2015.
//  Copyright (c) 2015 oxygn. All rights reserved.
//

#import "VideoCompositor.h"
@import AppKit;

static NSString *VideoCompositorErrorDomain = @"VideoCompositorErrorDomain";

@implementation VideoCompositor {
    
    AVMutableComposition *mutableComposition;
    AVMutableCompositionTrack *mutableCompositionVideoTrack;
    CMTime currentEndTime;
    CGRect dimensionsOfLastVideoAdded;
    
    // image writing
    AVAssetWriter *videoWriter;
    
}

-(void)createNewComposition {
    mutableComposition = nil;
    mutableCompositionVideoTrack = nil;
    mutableComposition = [AVMutableComposition composition];
    mutableCompositionVideoTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    currentEndTime = kCMTimeZero;
}

-(NSError*)appendCompositionWithVideoAtURL:(NSURL*)inFileURL {
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

-(NSError*)appendCompositionWithImageAtURL:(NSURL*)inImageURL {
    NSError *error = nil;
    
    // get image
    NSImage *image = [[NSImage alloc] initWithContentsOfURL:inImageURL];
    
    // temp video file output URL
    NSURL *tempVideoPath = [NSURL fileURLWithPath:@"/tmp/testAssetWriter" isDirectory:NO];
    NSURL *tempVideoPathWithExtension = [tempVideoPath URLByAppendingPathExtension:CFBridgingRelease(UTTypeCopyPreferredTagWithClass((CFStringRef)AVFileTypeMPEG4, kUTTagClassFilenameExtension))];
    
    // ASSUMES 12 FPS.
    error = [self writeImage:image toVideoAtURL:tempVideoPathWithExtension withNumberOfFrames:12 frameTime:CMTimeMake(50, 600)];
    if (error) {
        return error;
    }
    
    // need to check if the status is completed using a while loop. also need protection against infinite loop
    BOOL statusknown = NO;
    while (statusknown == NO) {
        
        switch (videoWriter.status) {
            case AVAssetWriterStatusCompleted:
                statusknown = YES;
                break;
            case AVAssetWriterStatusFailed:
                statusknown = YES;
                break;
            case AVAssetWriterStatusCancelled:
                statusknown = YES;
                break;
            case AVAssetWriterStatusUnknown:
//                statusknown = YES;
                break;
            default:
                // INFINITE LOOP if AVAssetWriterStatusWriting
                break;
        }
    }
    
    if (videoWriter.status != AVAssetWriterStatusCompleted) {
        error = [NSError errorWithDomain:VideoCompositorErrorDomain code:kErrorImageAssetWriterNotCompleted userInfo:[self errorUserInfoForErrorCode:kErrorImageAssetWriterNotCompleted]];
        return error;
    }
    
    error = [self appendCompositionWithVideoAtURL:tempVideoPathWithExtension];
    
    
    
    return error;
}

-(NSError*)writeCompositionToURL:(NSURL*)outFileURL {
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
//    exporter.videoComposition not needed if there is no video manipulation
    
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


-(NSError*)writeImage:(NSImage*)image toVideoAtURL:(NSURL*)videoURL withNumberOfFrames:(NSUInteger)frames frameTime:(CMTime)frameTime {
    NSError *error = nil;
    
    // get CGImageRef from NSImage
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    CGRect imageCGRect = CGRectMake(0, 0, image.size.width, image.size.height);
    NSRect imageRect = NSRectFromCGRect(imageCGRect);
    CGImageRef imageRef = [image CGImageForProposedRect:&imageRect context:context hints:nil];
    
    // convert to CVPixelBufferReg
    CVPixelBufferRef pixelBufferRef = [self pixelBufferFromCGImage:imageRef];
    
    // set up asset writer
    videoWriter = nil;
    videoWriter = [[AVAssetWriter alloc] initWithURL:videoURL
                                            fileType:AVFileTypeQuickTimeMovie
                                               error:&error];
    if (!videoWriter) {
        error = [NSError errorWithDomain:VideoCompositorErrorDomain code:kErrorImageAssetWriterNotValid userInfo:[self errorUserInfoForErrorCode:kErrorImageAssetWriterNotValid]];
        return error;
    }
    
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:imageCGRect.size.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:imageCGRect.size.height], AVVideoHeightKey,
                                   nil];
    
    AVAssetWriterInput* writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                         outputSettings:videoSettings];
    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                                                                                     sourcePixelBufferAttributes:nil];
    if (!writerInput) {
        error = [NSError errorWithDomain:VideoCompositorErrorDomain code:kErrorImageAssetWriterInputNotValid userInfo:[self errorUserInfoForErrorCode:kErrorImageAssetWriterInputNotValid]];
        return error;
    }
    
    if (![videoWriter canAddInput:writerInput]) {
        error = [NSError errorWithDomain:VideoCompositorErrorDomain code:kErrorImageAssetWriterCannotAddInput userInfo:[self errorUserInfoForErrorCode:kErrorImageAssetWriterCannotAddInput]];
        return error;
    }
    [videoWriter addInput:writerInput];
    
    // start writing at the first frame
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    int i = 0;
    while (1)
    {
        // keep asking if ready
        if (writerInput.readyForMoreMediaData) {
            
            
            // CMTime frameTime = CMTimeMake(150, 600);
            // CMTime = Value and Timescale.
            // Timescale = the number of tics per second you want
            // Value is the number of tics
            // Apple recommend 600 tics per second for video because it is a
            // multiple of the standard video rates 24, 30, 60 fps etc.
            CMTime lastTime = CMTimeMake(i*(frameTime.value), frameTime.timescale);
            CMTime presentTime = CMTimeAdd(lastTime, frameTime);
            
            if (i >= frames)
            {
                CVPixelBufferRelease(pixelBufferRef);
                pixelBufferRef = NULL;
            }
            
            if (pixelBufferRef)
            {
                // Give the CGImage to the AVAssetWriter to add to your video
                [adaptor appendPixelBuffer:pixelBufferRef withPresentationTime:presentTime];
                i++;
            }
            else {
                
                // finish
                [writerInput markAsFinished];
                [videoWriter finishWritingWithCompletionHandler:^{
                    
                    // BLOCK
                    NSLog(@"Finished writing...checking completion status...");
                    if (videoWriter.status != AVAssetWriterStatusCompleted) {
                        NSLog(@"Video writing not sucessful.");
                    } else {
                        NSLog(@"Video writing succeeded.");
                    }
                    
                }];
                
                CVPixelBufferPoolRelease(adaptor.pixelBufferPool);
                
                NSLog (@"Done");
                break;
            }
            
        }
    }
    
    return error;
}

- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef) image
{

    int height = (int)CGImageGetHeight(image);
    int width = (int)CGImageGetWidth(image);
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width,
                                          height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    
    if (!(status == kCVReturnSuccess && pxbuffer != NULL)) {
        NSLog(@"problem creating pixel buffer");
        return NULL;
    }
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    if (pxdata == NULL) {
        NSLog(@"pxData is NULL");
        return NULL;
    }
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    
    
    CGContextRef context = CGBitmapContextCreate(pxdata, width,
                                                 height, 8, 4*width, rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
     /*
    CGContextRef context = CGBitmapContextCreate(pxdata, width,
                                                 height, 8, 4*width, rgbColorSpace,
                                                 kCGBitmapByteOrderDefault);
      */
    if (!context) {
        NSLog(@"no context");
        return NULL;
    }
    
    CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
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
        case kErrorExportNotCompleted: {
            returnDictionary = [NSDictionary dictionaryWithObject:@"Composition export was not completed sucessfully" forKey:NSLocalizedDescriptionKey];
            break;
        }
        case kErrorTrackNotCompatibleWithComposition: {
            returnDictionary = [NSDictionary dictionaryWithObject:@"Video track from video file is not compatible with the AVComposition" forKey:
                                NSLocalizedDescriptionKey];
            break;
        }
        case kErrorImageAssetWriterNotValid: {
            returnDictionary = [NSDictionary dictionaryWithObject:@"Asset writer created for image is not valid" forKey:NSLocalizedDescriptionKey];
            break;
        }
        case kErrorImageAssetWriterInputNotValid: {
            returnDictionary = [NSDictionary dictionaryWithObject:@"Asset writer input created for image is not valid" forKey:NSLocalizedDescriptionKey];
            break;
        }
        case kErrorImageAssetWriterCannotAddInput: {
            returnDictionary = [NSDictionary dictionaryWithObject:@"Asset writer input cannot be added to asset writer" forKey:NSLocalizedDescriptionKey];
            break;
        }
        case kErrorImageAssetWriterNotCompleted: {
            returnDictionary = [NSDictionary dictionaryWithObject:@"Asset writer for image did not complete sucessfully" forKey:NSLocalizedDescriptionKey];
            break;
        }
        default:
            returnDictionary = [NSDictionary dictionaryWithObject:@"Unknown error" forKey:NSLocalizedDescriptionKey];
            break;
    }
    return returnDictionary;
}
@end
