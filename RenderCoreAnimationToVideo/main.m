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

CALayer *animationLayerWithFrame(CGRect renderFrame);

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
            NSLog(@"\n\nSuccess: \n%@", [exportURL path]);
            break;
        case AVAssetExportSessionStatusFailed:
            NSLog(@"\n\nFailed: \n%@", assetExportError);
            break;
        case AVAssetExportSessionStatusCancelled:
            NSLog(@"\n\nCanceled: \n%@", assetExportError);
            break;
        default:
            break;
    }
}

CALayer *animationLayerWithFrame(CGRect renderFrame) {
	CALayer *renderAnimLayer = [CALayer layer];
	
	CFTimeInterval animationDuration = 30.0;
	
	CGRect animationFrame = CGRectMake(0, 0, 1280, 720);
	renderAnimLayer.frame = animationFrame;
	
	CGColorRef backgroundColor = CGColorCreateGenericRGB(0.3, 0.0, 0.0, 0.5);
	renderAnimLayer.backgroundColor = backgroundColor;
	CGColorRelease(backgroundColor);
	
	CALayer *square = [CALayer layer];
	CGColorRef squareBackgroundColor = CGColorCreateGenericRGB(0, 0, 1, 0.8);
	square.backgroundColor = squareBackgroundColor;
	CGColorRelease(squareBackgroundColor);
	
	square.frame = CGRectMake(100, 100, 100, 100);
	
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	[CATransaction setAnimationDuration:animationDuration];
	
	CABasicAnimation *animation = [CABasicAnimation animation];
	animation.fromValue = [NSValue valueWithPoint:square.position];
	animation.toValue = [NSValue valueWithPoint:CGPointOffset(square.position, 800, 400)];
	animation.removedOnCompletion = NO;
	animation.duration = animationDuration;
	// beginTime needs to be set to AVCoreAnimationBeginTimeAtZero for all animations when used with AVVideoCompositionCoreAnimationTool.
	animation.beginTime = AVCoreAnimationBeginTimeAtZero;
	
	[CATransaction commit];
	
	[square addAnimation:animation forKey:@"position"];
	[renderAnimLayer addSublayer:square];
	
	// Create the wrapper layer for scaling to match the renderFrame
	CALayer *wrapperLayer = [CALayer layer];
	wrapperLayer.frame = animationFrame;
	
	CGFloat animationScale = MIN(renderFrame.size.width / animationFrame.size.width,
								 renderFrame.size.height / animationFrame.size.height);
	
	CGAffineTransform translation = CGAffineTransformMakeTranslation(CGRectGetMidX(renderFrame) - CGRectGetMidX(animationFrame),
																	 CGRectGetMidY(renderFrame) - CGRectGetMidY(animationFrame));
	wrapperLayer.affineTransform = CGAffineTransformScale(translation, animationScale, animationScale);
	
	[wrapperLayer addSublayer:renderAnimLayer];
	return wrapperLayer;
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
		
		CMTimeScale targetTimescale = FRAMES_PER_SECOND; // Please make sure you know what you are doing when not using integral framerates (NTSC)!
		CMTime frameDuration = CMTimeMake(1, targetTimescale);
		
		CGRect renderFrame
#if ENABLE_FAST_TEST
		= CGRectMake(0, 0, 640, 360);
#else
		= CGRectMake(0, 0, 1280, 720);
#endif
		
		CMTime durationTime = CMTimeMakeWithSeconds(duration, targetTimescale);
		
		// Create the animated layer
		CALayer *animationLayer = animationLayerWithFrame(renderFrame);

		CGColorRef bgColor = CGColorCreateGenericGray(0.0, 1.0);
		
		// Composition setup.
		AVMutableComposition *composition = [AVMutableComposition composition];
		
		AVURLAsset *asset;
		if (sourceFileURL != nil) {
			asset = [AVURLAsset URLAssetWithURL:sourceFileURL
										options:nil];
		} else {
			asset = [CCBlankMovieAsset blankMovieWithSize:renderFrame.size
												 duration:durationTime
									   andBackgroundColor:bgColor
													error:&error];
		}
		
		if (asset == nil) {
			NSLog(@"Missing movie file:\n%@\n\n%@", sourceFileURL, error);
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

		// Create a composition
		AVMutableVideoCompositionLayerInstruction *layerInstruction =
		[AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstruction];
		CMPersistentTrackID trackID = [composition unusedTrackID];
		layerInstruction.trackID = trackID;
		
		AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
		instruction.timeRange = CMTimeRangeMake(kCMTimeZero, durationTime);
		instruction.layerInstructions = @[layerInstruction];
		
		AVMutableVideoComposition *renderComp = [AVMutableVideoComposition videoComposition];
		renderComp.renderSize    = renderFrame.size;
		renderComp.frameDuration = frameDuration;
		renderComp.instructions  = @[instruction];

		CMPersistentTrackID renderTrackID = [composition unusedTrackID];
		renderComp.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithAdditionalLayer:animationLayer
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
		
		CFRelease(bgColor);

#if 0
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
		if (exportSession.status != AVAssetExportSessionStatusCompleted) {
			reportForExportSessionAndURL(exportSession, exportURL);
		}
		
#else
		dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
		
		__block NSString *errorString = nil;
		__block BOOL didSucceed = NO;
		[exportSession exportAsynchronouslyWithCompletionHandler:^{
			if (AVAssetExportSessionStatusCompleted == exportSession.status) {
				didSucceed = YES;
			}
			else {
				didSucceed = NO;
				if (exportSession.error)
					errorString = [exportSession.error localizedDescription];
				else
					errorString = @"unknown";
			}
			dispatch_semaphore_signal(semaphore);
		}];
		
		printf("\n0--------------------100%%\n");
		float nextTick = 0.0;
		long semaphoreResult = 0;
		BOOL isFirst = YES;
		
		// Monitor the progress.
		do {
			semaphoreResult = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC)); // Every 100 ms.
			
			if (isFirst) {
				fprintf(stderr, " "); // Indent line.
				isFirst = NO;
			}
			
			float currentProgress = exportSession.progress;
			while (currentProgress > nextTick) {
				// Print an asterisk for every 5%.
				fprintf(stderr, "*"); // Force to be flush without end of line.
				nextTick += 0.05;
			}
		} while (semaphoreResult);
		
		fprintf(stderr, "\n"); // End line.
		
		reportForExportSessionAndURL(exportSession, exportURL);
		dispatch_release(semaphore);
		
		return didSucceed ? EXIT_SUCCESS : EXIT_FAILURE;
#endif
	}
	
    return EXIT_FAILURE;
}

