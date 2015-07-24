//
//  VideoCompositor.h
//  AVCompositionTesting
//
//  Created by Simon Haycock on 24/07/2015.
//  Copyright (c) 2015 oxygn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#define kErrorNotReadable 101
#define kErrorNotComposable 102
#define kErrorNotExportable 103
#define kErrorNoVideoToRender 104
#define kErrorExportNotCompleted 105
#define kErrorTrackNotCompatibleWithComposition 106

@interface VideoCompositor : NSObject

-(void)createNewComposition;
-(NSError*)appendVideoWithURL:(NSURL*)inFileURL;
-(NSError*)writeOutVideoToURL:(NSURL*)outFileURL;

@end
