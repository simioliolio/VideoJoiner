//
//  AVCompositionTestingTests.m
//  AVCompositionTestingTests
//
//  Created by Simon Haycock on 24/07/2015.
//  Copyright (c) 2015 oxygn. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <AVFoundation/AVFoundation.h>
#include "VideoCompositor.h"

@interface AVCompositionTestingTests : XCTestCase

@end

@implementation AVCompositionTestingTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    
    XCTAssert(YES, @"Pass");
}

-(void)testCompositing {
    
    NSError *error = nil;
    
    // input file URLs
    NSURL *videoOnePath = [NSURL fileURLWithPath:@"/Users/simioliolio/Movies/wiggle left.mov" isDirectory:NO];
    NSURL *videoTwoPath = [NSURL fileURLWithPath:@"/Users/simioliolio/Movies/wiggle right.mov" isDirectory:NO];
    
    NSURL *imageOnePath = [NSURL fileURLWithPath:@"/Users/simioliolio/Pictures/Test Images/numbers/1.png" isDirectory:NO];
    
    // output file URL is based on date / time
    static NSDateFormatter *kDateFormatter;
    if (!kDateFormatter) {
        kDateFormatter = [[NSDateFormatter alloc] init];
        kDateFormatter.dateStyle = NSDateFormatterMediumStyle;
        kDateFormatter.timeStyle = NSDateFormatterShortStyle;
    }
    NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                 inDomain:NSUserDomainMask
                                                        appropriateForURL:nil
                                                                   create:@YES
                                                                    error:nil];
    NSURL *filePathWithoutExtension = [directoryURL URLByAppendingPathComponent:[kDateFormatter stringFromDate:[NSDate date]]];
    NSURL *filePathWithExtension = [filePathWithoutExtension URLByAppendingPathExtension:CFBridgingRelease(UTTypeCopyPreferredTagWithClass((CFStringRef)AVFileTypeMPEG4, kUTTagClassFilenameExtension))];
    
    // compose!
    VideoCompositor *compositor = [[VideoCompositor alloc] init];
    [compositor createNewComposition];
    
    error = [compositor appendCompositionWithVideoAtURL:videoOnePath];
    if (error) {
        NSLog([error localizedDescription]);
        XCTAssert(NO, @"error adding first video");
    }
    
    error = [compositor appendCompositionWithImageAtURL:imageOnePath];
    if (error) {
        NSLog([error localizedDescription]);
        XCTAssert(NO, @"error adding first image");
    }
    
    error = [compositor appendCompositionWithVideoAtURL:videoTwoPath];
    if (error) {
        NSLog([error localizedDescription]);
        XCTAssert(NO, @"error adding second video");
    }
    
    error = [compositor writeCompositionToURL:filePathWithExtension];
    if (error) {
        NSLog([error localizedDescription]);
        XCTAssert(NO, @"error writing out video");
    }
    XCTAssert(YES, @"Pass");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
