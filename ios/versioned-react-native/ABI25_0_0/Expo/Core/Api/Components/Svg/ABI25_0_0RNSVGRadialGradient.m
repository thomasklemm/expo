/**
 * Copyright (c) 2015-present, Horcrux.
 * All rights reserved.
 *
 * This source code is licensed under the MIT-style license found in the
 * LICENSE file in the root directory of this source tree.
 */
#import "ABI25_0_0RNSVGRadialGradient.h"

@implementation ABI25_0_0RNSVGRadialGradient

- (void)setGradient:(NSArray<NSNumber *> *)gradient
{
    if (gradient == _gradient) {
        return;
    }
    
    _gradient = gradient;
    [self invalidate];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    return nil;
}

- (void)parseReference
{
    NSArray<NSString *> *points = @[self.fx, self.fy, self.rx, self.ry, self.cx, self.cy];
    ABI25_0_0RNSVGPainter *painter = [[ABI25_0_0RNSVGPainter alloc] initWithPointsArray:points];
    [painter setUnits:self.gradientUnits];
    [painter setTransform:self.gradientTransform];
    [painter setRadialGradientColors:self.gradient];
    
    ABI25_0_0RNSVGSvgView *svg = [self getSvgView];
    if (self.gradientUnits == kRNSVGUnitsUserSpaceOnUse) {
        [painter setUserSpaceBoundingBox:[svg getContextBounds]];
    }
    
    [svg definePainter:painter painterName:self.name];
}

@end

