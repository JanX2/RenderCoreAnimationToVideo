//
//  CCBlankMovieAsset.h
//  RenderCoreAnimationToVideo
//
//  Created by Eric Methot.
//  Copyright (c) 2013 Eric Methot. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@interface CCBlankMovieAsset : AVURLAsset

- (id) initWithSize:(CGSize)size duration:(CMTime)duration andBackgroundColor:(CGColorRef)color;
+ (id) blankMovieWithSize:(CGSize)size duration:(CMTime)duration andBackgroundColor:(CGColorRef)color;

@end
