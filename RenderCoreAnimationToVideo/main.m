//
//  main.m
//  RenderCoreAnimationToVideo
//
//  Created by Jan on 04.02.13.
//  Copyright (c) 2013 Jan. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <QuartzCore/QuartzCore.h>

#import "CCBlankMovieAsset.h"

#define ENABLE_COMPOSITING_OVER_SOURCE_FILE	0
#define ENABLE_FAST_TEST					1

CGPoint CGPointOffset(CGPoint p, CGFloat dx, CGFloat dy)
{
	return CGPointMake(p.x + dx, p.y + dy);
}


void reportForExportSessionAndURL(AVAssetExportSession *exportSession, NSURL *exportURL)
{
    // Just see how things have turned out.
    NSError *assetExportError = exportSession.error;
    
    switch (exportSession.status) {
        case AVAssetExportSessionStatusCompleted:
            NSLog(@"\nDone: \n%@", [exportURL path]);
            break;
        case AVAssetExportSessionStatusFailed:
            NSLog(@"\nFailed: \n%@", assetExportError);
            break;
        case AVAssetExportSessionStatusCancelled:
            NSLog(@"\nCanceled: \n%@", assetExportError);
            break;
        default:
            break;
    }
}

int main(int argc, const char * argv[])
{

	@autoreleasepool {

		// Based on http://stackoverflow.com/questions/6988950/avvideocompositioncoreanimationtool-on-export-only-sends-the-image-and-audio-but
		
		NSError *error = nil;
#if ENABLE_COMPOSITING_OVER_SOURCE_FILE
		NSString *inFileName = @"in.mp4";
		NSURL *sourceFileURL = [NSURL fileURLWithPath:inFileName];
#else
		NSURL *sourceFileURL = nil;
#endif

#define FRAMES_PER_SECOND	25

		NSString *outFileName = @"out.mov";
		NSURL *exportURL = [NSURL fileURLWithPath:outFileName];
		
		CFTimeInterval duration
#if ENABLE_FAST_TEST
		= 1.0;
#else
		= 30.0;
#endif
		
		CMTimeScale targetTimescale = FRAMES_PER_SECOND;
		CMTime frameDuration = CMTimeMakeWithSeconds(1, targetTimescale);
		
		CGRect renderFrame
#if ENABLE_FAST_TEST
		= CGRectMake(0, 0, 640, 360);
#else
		= CGRectMake(0, 0, 1280, 720);
#endif
		
		CMTime durationTime = CMTimeMakeWithSeconds(duration, 1);
		
		// Composition setup.
		AVMutableComposition *composition = [AVMutableComposition composition];
#if ENABLE_COMPOSITING_OVER_SOURCE_FILE
		AVURLAsset *asset = [AVURLAsset URLAssetWithURL:sourceFileURL
												options:nil];
#else
		CGColorRef bgColor = CGColorCreateGenericGray(0.75, 1.0);
		CCBlankMovieAsset *asset = [CCBlankMovieAsset blankMovieWithSize:renderFrame.size
																duration:durationTime
													  andBackgroundColor:bgColor];
		CFRelease(bgColor);
#endif
		if (asset == nil) {
			NSLog(@"Missing movie file:\n%@", sourceFileURL);
			return EXIT_FAILURE;
		}
		
		AVMutableCompositionTrack *trackA = [composition addMutableTrackWithMediaType:AVMediaTypeVideo
																	 preferredTrackID:kCMPersistentTrackID_Invalid];
		
		NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
		if (videoTracks.count == 0) {
			NSLog(@"No video tracks in file:\n%@", sourceFileURL);
			return EXIT_FAILURE;
		}
		
		AVAssetTrack *sourceVideoTrack = videoTracks[0];
		if ([trackA insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration])
						ofTrack:sourceVideoTrack
						 atTime:kCMTimeZero
							  error:&error] == NO) {
			NSLog(@"%@", error);
			return EXIT_FAILURE;
		}
		
		// Create the animated layer
		CALayer *renderAnimLayer = [CALayer layer];
		renderAnimLayer.frame = renderFrame;
		
		renderAnimLayer.backgroundColor = CGColorCreateGenericRGB(0.3, 0.0, 0.0, 0.5);
		
		CALayer *square = [CALayer layer];
		square.backgroundColor = CGColorCreateGenericRGB(0, 0, 1, 0.8);
		square.frame = CGRectMake(100, 100, 100, 100);
		
		[CATransaction begin];
		[CATransaction setDisableActions:YES];
		[CATransaction setAnimationDuration:duration];
		
		CABasicAnimation *animation = [CABasicAnimation animation];
		animation.fromValue = [NSValue valueWithPoint:square.position];
		animation.toValue = [NSValue valueWithPoint:CGPointOffset(square.position, 800, 400)];
		animation.removedOnCompletion = NO;
		animation.beginTime = AVCoreAnimationBeginTimeAtZero;
		animation.duration = duration;
		
		[CATransaction commit];
		
		[square addAnimation:animation forKey:@"position"];
		[renderAnimLayer addSublayer:square];
		
		// Create a composition
		AVMutableVideoCompositionLayerInstruction *layerInstruction =
#if 1
		[AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:trackA];
#else
		[AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstruction];
		CMPersistentTrackID trackID = [composition unusedTrackID];
		layerInstruction.trackID = trackID;
#endif
		
		AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
		instruction.timeRange = CMTimeRangeMake(kCMTimeZero, durationTime);
		instruction.layerInstructions = @[layerInstruction];
		
		CMPersistentTrackID renderTrackID = [composition unusedTrackID];
		AVMutableVideoComposition *renderComp = [AVMutableVideoComposition videoComposition];
		renderComp.renderSize    = renderFrame.size;
		renderComp.frameDuration = frameDuration;
		renderComp.instructions  = @[instruction];
		renderComp.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithAdditionalLayer:renderAnimLayer
																												   asTrackID:renderTrackID];

		// Remove the file at exportURL if it exists.
		if ([exportURL checkResourceIsReachableAndReturnError:NULL] == YES) {
			NSFileManager *fileManager = [NSFileManager defaultManager];
			if ([fileManager removeItemAtURL:exportURL error:&error] == NO) {
				NSLog(@"\n%@", error);
				return EXIT_FAILURE;
			}
		}
		
		// Create an export session and export
		AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:composition
																				presetName:AVAssetExportPresetAppleProRes422LPCM];
		exportSession.outputURL = exportURL;
		exportSession.timeRange = CMTimeRangeMake(kCMTimeZero, durationTime);
		exportSession.shouldOptimizeForNetworkUse = YES;
		exportSession.videoComposition = renderComp;
		exportSession.outputFileType = AVFileTypeQuickTimeMovie;
		
		[exportSession exportAsynchronouslyWithCompletionHandler:^() {
			// Just see how things have turned out.
			reportForExportSessionAndURL(exportSession, exportURL);
			
			int returnCode = (exportSession.status == AVAssetExportSessionStatusCompleted) ? EXIT_SUCCESS : EXIT_FAILURE;
			exit(returnCode);
		}];
		
		NSTimeInterval resolution = 0.2;
		NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
		while (exportSession.status == AVAssetExportSessionStatusExporting ||
			   exportSession.status == AVAssetExportSessionStatusWaiting) {
			NSDate *next = [NSDate dateWithTimeIntervalSinceNow:resolution];
			[currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:next];
		}
		
		// In case exportSession fails immediately.
		reportForExportSessionAndURL(exportSession, exportURL);
	}
	
    return EXIT_FAILURE;
}

