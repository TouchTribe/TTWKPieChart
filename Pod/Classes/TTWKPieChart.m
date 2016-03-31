//
// TTWKPieChart
// Copyright (c) 2015, TouchTribe B.V. All rights reserved.
//
// This source code is available under the MIT license. See the LICENSE file for more info.
//

#import "TTWKPieChart.h"

#import <UIKit/NSStringDrawing.h>

/** Rounds to the neares half of a point, handy for 2x-retina used on Apple Watch. */
static inline CGFloat TTWKRetinaRound(x) {
	return roundf(x * 2) / 2;
}

@implementation TTWKPieChart {
	// These constants determine between which two points of the band (by angles) the linear gradient is drawn,
	// it seems that there is no much sense in making these public at this point
	CGFloat _gradientStartAngle;
	CGFloat _gradientEndAngle;
}

- (id)init {

	if (self = [super init]) {

		//
		// Let's set some defaults
		//
		_radius = 75;
		_bandWidth = 16;
		_bandSpacing = 1;
		_animationDuration = 1.5;
		_captionPadding = 2;
		_autoHideCaptions = YES;

		// TODO: this should be just a constant instead, the gradient starting at the beginning of the band
		// and ending at 6 o'clock (with the rest of the band always using the highlight color) seems reasonable
		_gradientStartAngle = 0 * (2 * M_PI);
		_gradientEndAngle = 0.5 * (2 * M_PI);

		// Well, this font might be not accessible in regular apps, but let's try at least
		_captionFont = [UIFont fontWithName:@"SanFranciscoText-Regular" size:13];

		// Let's keep a few default bands here as well just in case
		_bands = @[
			[[TTWKPieChartBand alloc] init],
			[[TTWKPieChartBand alloc] init],
			[[TTWKPieChartBand alloc] init],
		];
	}

	return self;
}

- (CGSize)size {

	// Have to take captions into account. This means we never truncate them, so be careful
	CGFloat maxCaptionWidth = 0;
	for (TTWKPieChartBand *band in _bands) {
		if (band.caption) {
			CGSize s = [band.caption sizeWithAttributes:@{ NSFontAttributeName : [self effectiveCaptionFont] }];
			CGFloat w = ceilf(s.width + _captionPadding + _bandWidth * 0.5);
			if (w > maxCaptionWidth) {
				maxCaptionWidth = w;
			}
		}
	}
	return CGSizeMake(2 * MAX(_radius, maxCaptionWidth), 2 * _radius);
}

- (UIImage *)image {
	return [self imageForTime:-1];
}

- (UIImage *)animatedImage {
	return [self animatedImageWithFrameRate:30];
}

- (UIImage *)animatedImageWithFrameRate:(CGFloat)frameRate {

	NSAssert(frameRate > 1, @"");

	NSInteger numberOfFrames = _animationDuration * frameRate;
	NSMutableArray *images = [[NSMutableArray alloc] initWithCapacity:numberOfFrames];

	for (NSInteger frameIndex = 0; frameIndex <= numberOfFrames; frameIndex++) {
		NSTimeInterval time = frameIndex * _animationDuration / numberOfFrames;
		[images addObject:[self imageForTime:time]];
	}

	return [UIImage animatedImageWithImages:images duration:_animationDuration];
}

- (CGFloat)outerRadiusForBandWithIndex:(NSInteger)bandIndex {
	return _radius - bandIndex * (_bandWidth + _bandSpacing);
}

- (CGFloat)centerRadiusForBandWithIndex:(NSInteger)bandIndex {
	return [self outerRadiusForBandWithIndex:bandIndex] - _bandWidth * 0.5;
}

- (CGFloat)innerRadiusForBandWithIndex:(NSInteger)bandIndex {
	return [self outerRadiusForBandWithIndex:bandIndex] - _bandWidth;
}

- (void)addPathForBandBackgroundWithIndex:(NSInteger)bandIndex
	center:(CGPoint)center
{
	CGFloat outerRadius = [self outerRadiusForBandWithIndex:bandIndex];
	CGFloat innerRadius = [self innerRadiusForBandWithIndex:bandIndex];

	//
	// Let's add the band's path
	//
	
	CGContextRef c = UIGraphicsGetCurrentContext();
	CGContextAddEllipseInRect(c, CGRectMake(center.x - outerRadius, center.y - outerRadius, outerRadius * 2, outerRadius * 2));
	CGContextAddEllipseInRect(c, CGRectMake(center.x - innerRadius, center.y - innerRadius, innerRadius * 2, innerRadius * 2));
}

- (CGPoint)pointForBandWithIndex:(NSInteger)bandIndex center:(CGPoint)center angle:(CGFloat)angle {
	CGFloat centerRadius = [self centerRadiusForBandWithIndex:bandIndex];
	return CGPointMake(center.x + centerRadius * cos(angle), center.y + centerRadius * sin(angle));
}

- (void)addPathForBandWithIndex:(NSInteger)bandIndex
	center:(CGPoint)center
	startAngle:(CGFloat)startAngle
	endAngle:(CGFloat)endAngle
{
	CGFloat outerRadius = [self outerRadiusForBandWithIndex:bandIndex];
	CGFloat innerRadius = [self innerRadiusForBandWithIndex:bandIndex];
	
	CGPoint startPoint = [self pointForBandWithIndex:bandIndex center:center angle:startAngle];
	CGPoint endPoint = [self pointForBandWithIndex:bandIndex center:center angle:endAngle];
	
	//
	// Let's add the band's path
	//
	
	CGContextRef c = UIGraphicsGetCurrentContext();

	CGContextMoveToPoint(c, center.x, center.y - outerRadius + _bandWidth);
	// Rounded start
	CGContextAddArc(c, startPoint.x, startPoint.y, _bandWidth * 0.5, startAngle - M_PI, startAngle, NO);
	// Outer arc
	CGContextAddArc(c, center.x, center.y, outerRadius, startAngle, endAngle, NO);
	// Rounded end
	CGContextAddArc(c, endPoint.x, endPoint.y, _bandWidth * 0.5, endAngle, endAngle + M_PI, NO);
	// Inner Arc
	CGContextAddArc(c, center.x, center.y, innerRadius, endAngle, startAngle, YES);
}

- (CGFloat)easeOut:(CGFloat)t {
	return (t * t - 3 * t + 3) * t;
	// return - t * t + 2 * t;
}

- (NSTimeInterval)normalizedTimeForTime:(NSTimeInterval)time
	start:(NSTimeInterval)start
	duration:(NSTimeInterval)duration
{
	// Well, this is quite an exception, we assume time is always positive and negative means 'past the end of all animations'
	if (time < 0)
		return 1;

	if (time <= start)
		return 0;
	else if (time >= start + duration)
		return 1;
	else
		return (time - start) / duration;
}

- (UIColor *)colorFromColor:(UIColor *)color withAlpha:(CGFloat)alpha {
	CGColorRef result = CGColorCreateCopyWithAlpha(color.CGColor, alpha);
	return [UIColor colorWithCGColor:result];
}

- (UIColor *)colorFromColor:(UIColor *)color withAlphaMultipliedBy:(CGFloat)t {
	CGColorRef result = CGColorCreateCopyWithAlpha(color.CGColor, CGColorGetAlpha(color.CGColor) * t);
	return [UIColor colorWithCGColor:result];
}

- (CGPoint)chartCenter {
	CGSize size = [self size];
	return CGPointMake(size.width * 0.5, size.height * 0.5);
}

- (UIImage *)imageForTime:(NSTimeInterval)time {

	CGSize size = [self size];
	CGRect b = CGRectMake(0, 0, size.width, size.height);
	CGPoint center = [self chartCenter];

	UIGraphicsBeginImageContextWithOptions(b.size, NO, 2);

	CGContextRef c = UIGraphicsGetCurrentContext();

	NSTimeInterval t = [self easeOut:[self normalizedTimeForTime:time start:0 duration:_animationDuration]];

	for (NSInteger bandIndex = 0; bandIndex < [_bands count]; bandIndex++) {

		TTWKPieChartBand *band = [_bands objectAtIndex:bandIndex];

		// The bands start at 12 o'clock
		CGFloat startAngle = -M_PI / 2;

		CGFloat value = band.value;

		// The angle corresponding to the value and time
		CGFloat angle = (2 * M_PI * value) * t;

		CGFloat endAngle = startAngle + angle;

		//
		// Band's background
		//
		if (band.backgroundColor) {
			[self addPathForBandBackgroundWithIndex:bandIndex center:center];
			[band.backgroundColor setFill];
			CGContextDrawPath(c, kCGPathEOFill);
		}

		// Only render the backgrounds at time 0, so the very first frame can be shown longer than the rest
		// and serve as a placeholder image (i.e. if we would draw the band for time 0, then it would be a starting
		// circle, which is not good to have on the placeholder image)
		if (time == 0)
			continue;

		//
		// The band
		//

		NSAssert(band.startColor, @"At least band's startColor must be set");
		if (band.endColor) {

			// Not sure how the gradient is drawn originally, but here we use simple linear gradient
			// between two points on the band

			// First part of the band in solid color
			[self
				addPathForBandWithIndex:bandIndex
				center:center
				startAngle:startAngle
				endAngle:startAngle + MIN(angle, _gradientStartAngle)
			];
			[band.startColor setFill];
			CGContextDrawPath(c, kCGPathFill);

			// The gradient part of the band
			if (_gradientStartAngle < angle) {

				CGContextSaveGState(c);

				[self
					addPathForBandWithIndex:bandIndex
					center:center
					startAngle:startAngle + _gradientStartAngle
					endAngle:startAngle + MIN(_gradientEndAngle, angle - _gradientStartAngle)
				];

				CGContextClip(c);

				CFArrayRef colors = (__bridge_retained CFArrayRef)@[ (id)band.startColor.CGColor, (id)band.endColor.CGColor];
				CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
				CGGradientRef gradient = CGGradientCreateWithColors(rgb, colors, NULL);
				CGColorSpaceRelease(rgb);
				CFRelease(colors);

				CGContextDrawLinearGradient(
					c,
					gradient,
					[self pointForBandWithIndex:bandIndex center:center angle:startAngle + _gradientStartAngle],
					[self pointForBandWithIndex:bandIndex center:center angle:startAngle + _gradientEndAngle],
					kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation
				);

				CFRelease(gradient);

				CGContextRestoreGState(c);
			}

			// The plain final solid color part of the band
			if (_gradientEndAngle < angle) {
				[self
					addPathForBandWithIndex:bandIndex
					center:center
					startAngle:startAngle + _gradientEndAngle
					endAngle:endAngle
				];
				[band.endColor setFill];
				CGContextDrawPath(c, kCGPathFill);
			}

		} else {
			//
			// Normal solid fill
			//
			[self addPathForBandWithIndex:bandIndex center:center startAngle:startAngle endAngle:endAngle];
			[band.startColor setFill];
			CGContextDrawPath(c, kCGPathFill);
		}

		//
		// Icon
		//
		UIImage *icon = band.icon;
		if (icon) {

			// We do only simple fade in animation here

			NSTimeInterval t = [self easeOut:[self normalizedTimeForTime:time start:0 duration:.5 * _animationDuration]];

			CGSize size = icon.size;
			size.width *= t;
			size.height *= t;

			CGPoint startPoint = [self pointForBandWithIndex:bandIndex center:center angle:startAngle];
			startPoint.x = TTWKRetinaRound(startPoint.x);
			startPoint.y = TTWKRetinaRound(startPoint.y);
			[icon
				drawInRect:CGRectMake(
					startPoint.x - size.width * 0.5,
					startPoint.y - size.height * 0.5,
					size.width,
					size.height
				)
				blendMode:kCGBlendModeNormal
				alpha:[self easeOut:[self normalizedTimeForTime:time
					start:0.1 * _animationDuration
					duration:0.5 * _animationDuration]
				]
			];
		}

		//
		// Text
		//
		if (band.caption) {

			UIColor *captionColor = band.captionColor ?: band.startColor;

			// Must be right aligned to avoid characters being moved too much
			NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
			ps.alignment = NSTextAlignmentRight;

			NSMutableAttributedString *caption = [[NSMutableAttributedString alloc]
				initWithString:band.caption
				attributes:@{
					NSFontAttributeName : [self effectiveCaptionFont],
					NSForegroundColorAttributeName : captionColor,
					NSParagraphStyleAttributeName : ps
				}
			];

			if (_autoHideCaptions) {

				CGFloat t = 1 - [self easeOut:[self normalizedTimeForTime:time start:_animationDuration * 0.6 duration:_animationDuration * 0.4]];
				NSInteger numberOfVisibleCharacters = floor(caption.length * t);
				NSInteger numberOfInvisibleCharacters = caption.length - numberOfVisibleCharacters;

				[caption
					setAttributes:@{ NSForegroundColorAttributeName : [UIColor colorWithWhite:1 alpha:0] }
					range:NSMakeRange(0, numberOfInvisibleCharacters)
				];

				if (numberOfInvisibleCharacters > 0 && numberOfVisibleCharacters >= 1) {
					CGFloat maxKerningAdjustement = [self captionFont].xHeight / 2;
					CGFloat characterTime = (1 - (caption.length * t - numberOfVisibleCharacters));
					[caption
						addAttributes:@{
							NSKernAttributeName : @(-maxKerningAdjustement * characterTime),
							NSForegroundColorAttributeName : [self colorFromColor:captionColor withAlpha:1 - characterTime]
						}
						range:NSMakeRange(numberOfInvisibleCharacters, 1)
					];
				}
			}

			CGPoint startPoint = [self pointForBandWithIndex:bandIndex center:center angle:startAngle];
			startPoint.x = TTWKRetinaRound(startPoint.x - (_captionPadding + _bandWidth * 0.5));
			startPoint.y = TTWKRetinaRound(startPoint.y + _captionBaselineAdjustment);

			CGSize size = [caption size];
			[caption
				drawAtPoint:CGPointMake(
					startPoint.x - size.width,
					roundf(startPoint.y - size.height * 0.5)
				)
			];
		}
	}

	[self drawCenterTextForTime:time];
	[self drawGuidelineForTime:time];

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();

	UIGraphicsEndImageContext();

	return image;
}

- (void)drawCenterTextForTime:(NSTimeInterval)time {

	if ((!_largeText && !_smallText) || time == 0) {
		return;
	}

	CGContextRef c = UIGraphicsGetCurrentContext();

	CGPoint center = [self chartCenter];

	CGFloat innerRadius = [self innerRadiusForBandWithIndex:_bands.count - 1];

	// Side of the square full fitting the inner circle
	CGFloat squareSize = floorf(2 * innerRadius / M_SQRT2);

	CGRect squareRect = CGRectMake(
		TTWKRetinaRound(center.x - squareSize * 0.5),
		TTWKRetinaRound(center.y - squareSize * 0.5),
		squareSize, squareSize
	);

	CGSize largeTextSize;
	if (_largeText) {
		largeTextSize = [_largeText size];
		largeTextSize.height += _largeSmallTextPadding;
	} else {
		largeTextSize = CGSizeZero;
	}

	CGSize smallTextSize;
	if (_smallText) {
		smallTextSize = [_smallText size];
	} else {
		smallTextSize = CGSizeZero;
	}

	CGSize textSize = CGSizeMake(
		MAX(largeTextSize.width, smallTextSize.width),
		largeTextSize.height + smallTextSize.height
	);

	CGRect textRect = CGRectMake(
		TTWKRetinaRound(squareRect.origin.x + (squareRect.size.width - textSize.width) * 0.5),
		TTWKRetinaRound(squareRect.origin.y + (squareRect.size.height - textSize.height) * 0.5),
		textSize.width, textSize.height
	);

	if (_largeText) {

		CGRect r = CGRectMake(
			TTWKRetinaRound(textRect.origin.x + (textRect.size.width - largeTextSize.width) * 0.5),
			textRect.origin.y,
			textRect.size.width,
			largeTextSize.height
		);

		// Let's try to animate the characters of the large text.
		NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithAttributedString:_largeText];
		for (NSInteger i = 0; i < s.length; i++) {
			NSTimeInterval t = [self easeOut:
				[self normalizedTimeForTime:time
					// We want to start animation for each character with a bit of a delay
					start:_animationDuration * 0.05 * (1 + i)
					duration:_animationDuration * 0.5
				]
			];
			[s
				addAttribute:NSBaselineOffsetAttributeName
				value:@(-largeTextSize.height * (1 - t))
				range:NSMakeRange(i, 1)
			];
		}

		CGContextSaveGState(c);
		CGContextClipToRect(c, r);
		[s drawInRect:r];
		CGContextRestoreGState(c);
	}

	if (_smallText) {

		// We need to animate the small text a little bit too by shifting it a bit
		NSTimeInterval t = [self easeOut:[self normalizedTimeForTime:time start:0 duration:0.3 * _animationDuration]];
		CGFloat smallTextShift = smallTextSize.height * 0.5;
		
		[_smallText
			drawInRect:CGRectMake(
				TTWKRetinaRound(textRect.origin.x + (textRect.size.width - smallTextSize.width) * 0.5),
				TTWKRetinaRound(textRect.origin.y + largeTextSize.height) - smallTextShift * (1 - t),
				textRect.size.width,
				textRect.size.height - largeTextSize.height
			)
		];
	}
}

- (void)drawGuidelineForTime:(NSTimeInterval)time {

	if (!_guideline || time == 0)
		return;

	// TODO: might make the start/duration of the animation as a parameter
	NSTimeInterval t = [self easeOut:[self normalizedTimeForTime:time start:_animationDuration * 0.5 duration:_animationDuration * 0.5]];

	CGContextRef c = UIGraphicsGetCurrentContext();

	// TODO: adjust a bit, so the line sticks out a little

	CGFloat innerRadius = [self innerRadiusForBandWithIndex:_bands.count - 1] - _guideline.extraBefore;
	CGFloat outerRadius = [self outerRadiusForBandWithIndex:0] + _guideline.extraAfter;

	// Let's animate it as well
	outerRadius = innerRadius * (1 - t) + outerRadius * t;

	CGFloat angle = _guideline.position * 2 * M_PI - M_PI_2;

	CGPoint center = [self chartCenter];

	CGPoint startPoint = CGPointMake(center.x + innerRadius * cos(angle), center.y + innerRadius * sin(angle));
	CGPoint endPoint = CGPointMake(center.x + outerRadius * cos(angle), center.y + outerRadius * sin(angle));

	CGContextMoveToPoint(c, startPoint.x, startPoint.y);
	CGContextAddLineToPoint(c, endPoint.x, endPoint.y);

	CGContextSetLineWidth(c, _guideline.lineWidth);
	CGContextSetLineCap(c, _guideline.lineCap);

	if (_guideline.lineDash) {
		NSInteger count = _guideline.lineDash.count;
		CGFloat *dash = calloc(count, sizeof(CGFloat));
		if (!dash)
			return;
		for (NSInteger i = 0; i < count; i++) {
			NSNumber *d = _guideline.lineDash[i];
			NSAssert([d isKindOfClass:[NSNumber class]], @"");
			dash[i] = [d floatValue];
		}
		CGContextSetLineDash(c, 0, dash, count);
		free(dash);
	}

	UIColor *color = [self colorFromColor:_guideline.color withAlphaMultipliedBy:t];
	[color setStroke];
	CGContextDrawPath(c, kCGPathStroke);
}

- (UIFont *)effectiveCaptionFont {
	return _captionFont ?: [UIFont systemFontOfSize:13];
}

@end

//
//
//
@implementation TTWKPieChartBand

- (id)init {

	if (self = [super init]) {
		_startColor = [UIColor colorWithRed:1.0000 green:0.0902 blue:0.0588 alpha:1.0];
	}

	return self;
}

@end


@implementation TTWKPieChartGuideline

- (id)init {
	if (self = [super init]) {
		_position = 0.3;
		_color = [UIColor whiteColor];
		_lineWidth = 1;
		_lineCap = kCGLineCapButt;
		_lineDash = @[ @(1), @(1) ];
		_extraAfter = 2;
		_extraBefore = 2;
	}
	return self;
}

@end
