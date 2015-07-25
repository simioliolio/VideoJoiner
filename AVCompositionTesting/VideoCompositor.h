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
#define kErrorImageAssetWriterNotValid 107
#define kErrorImageAssetWriterInputNotValid 108
#define kErrorImageAssetWriterCannotAddInput 109
#define kErrorImageAssetWriterNotCompleted 110


@interface VideoCompositor : NSObject

-(void)createNewComposition;

-(NSError*)appendCompositionWithVideoAtURL:(NSURL*)inFileURL;
-(NSError*)appendCompositionWithImageAtURL:(NSURL*)inImageURL; // currently assumes 12 fps frame rate. need to work this out

-(NSError*)writeCompositionToURL:(NSURL*)outFileURL;

@end
