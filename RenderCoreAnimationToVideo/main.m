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

CGPoint CGPointOffset(CGPoint p, CGFloat dx, CGFloat dy)
{
	return CGPointMake(p.x + dx, p.y + dy);
}


int main(int argc, const char * argv[])
{

	@autoreleasepool {

		// Based on http://stackoverflow.com/questions/6988950/avvideocompositioncoreanimationtool-on-export-only-sends-the-image-and-audio-but
		
		// Composition setup.
		AVMutableComposition *composition = [AVMutableComposition composition];
		// ...
		// NOTE: composition is an AVMutableComposition containing a single video
		//		 track (30s of black in 1280 x 720).
		
		// Create the animated layer
		CALayer *renderAnimLayer = [CALayer layer];
		renderAnimLayer.frame = CGRectMake(0, 0, 1280, 720);
		
		renderAnimLayer.backgroundColor = CGColorCreateGenericRGB(0.3, 0.0, 0.0, 0.5);
		
		CALayer *square = [CALayer layer];
		square.backgroundColor = CGColorCreateGenericRGB(0, 0, 1, 0.8);
		square.frame = CGRectMake(100, 100, 100, 100);
		
		[CATransaction begin];
		[CATransaction setDisableActions:YES];
		[CATransaction setAnimationDuration:30.0];
		
		CABasicAnimation *animation = [CABasicAnimation animation];
		animation.fromValue = [NSValue valueWithPoint:square.position];
		animation.toValue = [NSValue valueWithPoint:CGPointOffset(square.position, 800, 400)];
		animation.removedOnCompletion = NO;
		animation.beginTime = AVCoreAnimationBeginTimeAtZero;
		animation.duration = 30.0;
		
		[CATransaction commit];
		
		[square addAnimation:animation forKey:@"position"];
		[renderAnimLayer addSublayer:square];
		
		// Create a composition
		AVMutableVideoCompositionLayerInstruction *layerInstr1 =
		[AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstruction];
		layerInstr1.trackID = 2;
		
		AVMutableVideoCompositionInstruction *instr = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
		instr.timeRange = CMTimeRangeMake(kCMTimeZero, composition.duration);
		instr.layerInstructions = [NSArray arrayWithObject:layerInstr1];
		
		AVMutableVideoComposition *renderComp = [AVMutableVideoComposition videoComposition];
		renderComp.renderSize	 = renderAnimLayer.frame.size;
		renderComp.frameDuration = CMTimeMake(1, 30); // Normally 1,30
		renderComp.instructions	 = [NSArray arrayWithObject:instr];
		renderComp.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithAdditionalLayer:renderAnimLayer asTrackID:2];
		
		// Create an export session and export
		AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:composition presetName:@"AVAssetExportPreset1280x720"];
		exportSession.outputURL = [NSURL URLWithString:@"file:///Users/eric/Desktop/toto.mov"];
		exportSession.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMake(30, 1));
		exportSession.shouldOptimizeForNetworkUse = YES;
		exportSession.videoComposition = renderComp;
		
		// Just see how things have finished.
		[exportSession exportAsynchronouslyWithCompletionHandler:^() {
			NSLog(@"Export completed with status: %ld", exportSession.status);
		}];
		
		// TODO: remove once everything works and objects have been retained.
		while (exportSession.progress < 1.0)
			usleep(200000);
	    
	}
	
    return EXIT_SUCCESS;
}

