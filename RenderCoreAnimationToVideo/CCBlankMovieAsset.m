//
//  CCBlankMovieAsset.m
//  RenderCoreAnimationToVideo
//
//  Created by Eric Methot.
//  Copyright (c) 2013 Eric Methot. All rights reserved.
//

#import "CCBlankMovieAsset.h"

@implementation CCBlankMovieAsset

- (id) initWithURL:(NSURL *)URL options:(NSDictionary *)options
{
	if ((self = [super initWithURL:URL options:options])) {
		// Nothing for now.
	}
	return self;
}

- (id) initWithSize:(CGSize)size duration:(CMTime)duration andBackgroundColor:(CGColorRef)color
{
	AVAssetWriter *avAssetWriter = nil;
	AVAssetWriterInput *avVideoFrameInput = nil;
	AVAssetWriterInputPixelBufferAdaptor *avVideoFrameAdaptor = nil;
	NSDictionary  *videoSettings = nil;
	NSDictionary  *pixelAttributes = nil;
	CVPixelBufferRef pixelBuffer = NULL;
	CGContextRef context = NULL;
	CGColorSpaceRef colorSpace = NULL;
	CVReturn result;
	
	NSError	 *error	   = nil;
	
	NSString *fileName = [@"CCBlankMovieAsset" stringByAppendingPathExtension:@"mov"];
	NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
	NSURL     *tempURL = [NSURL fileURLWithPath:filePath];
	
	@try {
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:tempURL.path])
			[[NSFileManager defaultManager] removeItemAtURL:tempURL error:nil]; // COV_NF_LINE
		
		avAssetWriter = [AVAssetWriter assetWriterWithURL:tempURL
												 fileType:AVFileTypeQuickTimeMovie
													error:&error];
		
		if (avAssetWriter == nil)
			return nil; // COV_NF_LINE
		
		videoSettings = @{AVVideoCodecKey: AVVideoCodecAppleProRes422, // On iOS, we would have to use AVVideoCodecH264
					AVVideoWidthKey: @(size.width),
					AVVideoHeightKey: @(size.height)};
		
		avVideoFrameInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
															   outputSettings:videoSettings];
		avVideoFrameInput.expectsMediaDataInRealTime = NO;
		
		if (avVideoFrameInput == nil)
			return nil; // COV_NF_LINE
		
		pixelAttributes = @{(id)kCVPixelBufferWidthKey: @(size.width),
					  (id)kCVPixelBufferHeightKey: @(size.height),
					  (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB),
					  (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES};
		
		avVideoFrameAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:avVideoFrameInput sourcePixelBufferAttributes:pixelAttributes];
		
		if ((avVideoFrameAdaptor == nil) || ![avAssetWriter canAddInput:avVideoFrameInput])
			return nil; // COV_NF_LINE
		
		[avAssetWriter addInput:avVideoFrameInput];
		[avAssetWriter setShouldOptimizeForNetworkUse:YES];
		[avAssetWriter startWriting];
		[avAssetWriter startSessionAtSourceTime:kCMTimeZero];
		
		result = CVPixelBufferPoolCreatePixelBuffer(NULL, avVideoFrameAdaptor.pixelBufferPool, &pixelBuffer);
		
		if (result != kCVReturnSuccess)
			return nil; // COV_NF_LINE
		
		CVPixelBufferLockBaseAddress(pixelBuffer, 0);
		colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
		
		if (colorSpace == NULL)
			return nil; // COV_NF_LINE
		
		context = CGBitmapContextCreate(
										CVPixelBufferGetBaseAddress(pixelBuffer),
										CVPixelBufferGetWidth(pixelBuffer),
										CVPixelBufferGetHeight(pixelBuffer),
										8,
										CVPixelBufferGetBytesPerRow(pixelBuffer),
										colorSpace,
										kCGImageAlphaPremultipliedFirst
										);
		
		
		if (context == NULL)
			return nil; // COV_NF_LINE
		
		CGContextSetFillColorWithColor(context, color);
		CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
		
		NSTimeInterval resolution = 0.050;
		NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
		
		// Wait until avVideoFrameInput is ready for more data.
		// See http://stackoverflow.com/questions/5877149/avassetwriterinput-and-readyformoremediadata
		while (avVideoFrameInput.readyForMoreMediaData == NO) {
			NSDate *next = [NSDate dateWithTimeIntervalSinceNow:resolution];
			[currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:next];
		}

		if (![avVideoFrameAdaptor appendPixelBuffer:pixelBuffer
							   withPresentationTime:kCMTimeZero]) {
			return nil; // COV_NF_LINE
		}
		
		// Wait until avVideoFrameInput is ready for more data.
		while (avVideoFrameInput.readyForMoreMediaData == NO) {
			NSDate *next = [NSDate dateWithTimeIntervalSinceNow:resolution];
			[currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:next];
		}
		
		if (![avVideoFrameAdaptor appendPixelBuffer:pixelBuffer
							   withPresentationTime:duration]) {
			return nil; // COV_NF_LINE
		}
		
		[avVideoFrameInput markAsFinished];
		[avAssetWriter endSessionAtSourceTime:duration];
		[avAssetWriter finishWriting];
	}
	@finally {
		if (context)
			CGContextRelease(context);
		
		if (colorSpace)
			CGColorSpaceRelease(colorSpace);
		
		if (pixelBuffer) {
			CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
			CVPixelBufferRelease(pixelBuffer);
		}
	}
	
	return [self initWithURL:tempURL options:nil];
}

+ (id) blankMovieWithSize:(CGSize)size duration:(CMTime)duration andBackgroundColor:(CGColorRef)color
{
	return [[self alloc] initWithSize:size duration:duration andBackgroundColor:color];
}


- (void) dealloc
{
	[[NSFileManager defaultManager] removeItemAtURL:self.URL error:nil];
}


@end
