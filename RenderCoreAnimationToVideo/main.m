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

#define ENABLE_COMPOSITING_OVER_SOURCE_FILE	0

CGPoint CGPointOffset(CGPoint p, CGFloat dx, CGFloat dy)
{
	return CGPointMake(p.x + dx, p.y + dy);
}


int main(int argc, const char * argv[])
{

	@autoreleasepool {

		// Based on http://stackoverflow.com/questions/6988950/avvideocompositioncoreanimationtool-on-export-only-sends-the-image-and-audio-but
		
#if ENABLE_COMPOSITING_OVER_SOURCE_FILE
		NSError *error = nil;
		NSString *inFileName = @"in.mov";
#endif

#define FRAMES_PER_SECOND	25

		NSString *outFileName = @"out.mov";
		CFTimeInterval duration = 30.0;
		
		CMTimeScale targetTimescale = FRAMES_PER_SECOND;
		CMTime frameDuration = CMTimeMakeWithSeconds(1, targetTimescale);
		
		CGRect renderFrame = CGRectMake(0, 0, 1280, 720);
		
		CMTime durationTime = CMTimeMakeWithSeconds(duration, 1);
		
		// Composition setup.
		AVMutableComposition *composition = [AVMutableComposition composition];
#if ENABLE_COMPOSITING_OVER_SOURCE_FILE
		NSURL *sourceFileURL = [NSURL fileURLWithPath:inFileName];
		AVURLAsset *asset = [AVURLAsset URLAssetWithURL:sourceFileURL
												options:nil];
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
#endif
		
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
		CMPersistentTrackID trackID = [composition unusedTrackID];
		AVMutableVideoCompositionLayerInstruction *layerInstr1 =
#if ENABLE_COMPOSITING_OVER_SOURCE_FILE
		[AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:trackA];
#else
		[AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstruction];
#endif
		layerInstr1.trackID = trackID;
		
		AVMutableVideoCompositionInstruction *instr = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
		instr.timeRange = CMTimeRangeMake(kCMTimeZero, durationTime);
		instr.layerInstructions = @[layerInstr1];
		
		CMPersistentTrackID renderTrackID = [composition unusedTrackID];
		AVMutableVideoComposition *renderComp = [AVMutableVideoComposition videoComposition];
		renderComp.renderSize    = renderAnimLayer.frame.size;
		renderComp.frameDuration = frameDuration;
		renderComp.instructions  = @[instr];
		renderComp.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithAdditionalLayer:renderAnimLayer
																												   asTrackID:renderTrackID];
	
		// Create an export session and export
		AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:composition
																				presetName:AVAssetExportPresetAppleProRes422LPCM];
		exportSession.outputURL = [NSURL URLWithString:outFileName];
		exportSession.timeRange = CMTimeRangeMake(kCMTimeZero, durationTime);
		exportSession.shouldOptimizeForNetworkUse = YES;
		exportSession.videoComposition = renderComp;
		exportSession.outputFileType = AVFileTypeQuickTimeMovie;
		
		// Just see how things have turned out.
		[exportSession exportAsynchronouslyWithCompletionHandler:^() {
			NSLog(@"Export completed with status: %ld\nError message: %@", exportSession.status, exportSession.error);
			int returnCode = (exportSession.status == AVAssetExportSessionStatusCompleted) ? EXIT_SUCCESS : EXIT_FAILURE;
			exit(returnCode);
		}];
		
		NSTimeInterval resolution = 0.2;
		NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
		while (exportSession.status == AVAssetExportSessionStatusExporting &&
			   exportSession.progress < 1.0) {
			NSDate *next = [NSDate dateWithTimeIntervalSinceNow:resolution];
			[currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:next];
		}
	}
	
    return EXIT_SUCCESS;
}

