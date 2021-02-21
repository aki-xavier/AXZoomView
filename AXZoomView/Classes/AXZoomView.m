//
//  AXZoomView.m
//
//  Created by Aki Xavier on 7/17/20.
//

#import "AXZoomView.h"

#if TARGET_OS_MACCATALYST
#import <AppKit/NSCursor.h>
#endif

@interface AXZoomView()

@property (atomic) BOOL isPinching;
@property (nonatomic) CGPoint ps1;
@property (nonatomic) CGPoint ps2;
@property (nonatomic) CGPoint vs;
@property (nonatomic) CGAffineTransform contentTransform;
@property (nonatomic) CGAffineTransform vsTransform;
@property (nonatomic) CGAffineTransform vsInverseTransform;

@end

@implementation AXZoomView

- (instancetype)init {
    self = [super init];
    self.clipsToBounds = YES;
    self.contentTransform = CGAffineTransformIdentity;
    #if !TARGET_OS_MACCATALYST
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(onPinch:)];
    [self addGestureRecognizer:pinch];
    #endif
    
    return self;
}

- (CGPoint)centerPoint {
    CGAffineTransform t = CGAffineTransformInvert(self.contentTransform);
    return CGPointApplyAffineTransform(self.center, t);
}

#pragma mark - gestures

static CGAffineTransform solve(double v0, double v1, double v2, double v3, double v4, double v5, double v6, double v7) {
    double c = (v3 - v7 - (v1 - v5) * (v2 - v6) / (v0 - v4)) / (v4 - v0 - pow(v1 - v5, 2) / (v0 - v4)); // used in x rotate, default to 0
    double a = (v2 - v6 - (v1 - v5) * c) / (v0 - v4); // x scale, default to 1

    double d = a; // y scale, default to 1
    double b = - c; // used in y rotate, default to 0

    double tx = v2 - v0 * a - v1 * c; // x translate, default to 0
    double ty = v3 - v0 * b - v1 * d; // y translate, default to 0
    return CGAffineTransformMake(a, b, c, d, tx, ty);
    
    // CGAffineTransformMakeRotation(CGFloat angle) => [cos(angle) sin(angle) -sin(angle) cos(angle) 0 0]
}

static CGPoint subtractPoint(CGPoint p1, CGPoint p2) {
    return CGPointMake(p1.x - p2.x, p1.y - p2.y);
}
                                       
- (void)onPinch:(UIPinchGestureRecognizer *)pinch {
    if (pinch.state == UIGestureRecognizerStateEnded || pinch.state == UIGestureRecognizerStateCancelled) {
        self.isPinching = NO;
        return;
    }
    if ([pinch numberOfTouches] < 2) {
        self.isPinching = NO;
        return;
    }
    // [AVDocument.sharedDocument cancelInput]; - to delegate
    self.isPinching = YES;
    CGPoint p1 = [pinch locationOfTouch:0 inView:self];
    CGPoint p2 = [pinch locationOfTouch:1 inView:self];
    if (pinch.state == UIGestureRecognizerStateBegan) {
        CGAffineTransform t = CGAffineTransformInvert(self.contentTransform);
        self.ps1 = CGPointApplyAffineTransform(p1, t);
        self.ps2 = CGPointApplyAffineTransform(p2, t);
    } else if (pinch.state == UIGestureRecognizerStateChanged) {
        CGAffineTransform transform = solve(self.ps1.x, self.ps1.y,
                                 p1.x, p1.y,
                                 self.ps2.x, self.ps2.y,
                                 p2.x, p2.y);
        
        self.contentTransform = transform;
        if (self.contentView != nil) {
            self.contentView.transform = self.contentTransform;
        }
    }
}



#pragma mark - touch events

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (touches.count != 1) {
        return;
    }
    if (self.isPinching) {
        return;
    }
    NSArray *mutableTouches = touches.allObjects;
    CGPoint p = [[mutableTouches objectAtIndex:0] locationInView:self];
    NSString *ts = NSStringFromCGAffineTransform(AVDocument.sharedDocument.transform);
    self.vs = p;
    self.vsTransform = CGAffineTransformFromString(ts);
    CGAffineTransform t = CGAffineTransformInvert(self.vsTransform);
    t.tx = 0;
    t.ty = 0;
    self.vsInverseTransform = t;
    #if TARGET_OS_MACCATALYST
    NSCursor *cursor = [NSCursor closedHandCursor];
    [cursor push];
    #endif
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (touches.count != 1) {
        return;
    }
    if (self.isPinching) {
        return;
    }
    NSArray *mutableTouches = touches.allObjects;
    
    CGPoint p = [[mutableTouches objectAtIndex:0] locationInView:self];
    CGPoint delta = subtractPoint(p, self.vs);
    delta = CGPointApplyAffineTransform(delta, self.vsInverseTransform);
    self.contentTransform =  CGAffineTransformTranslate(self.vsTransform, delta.x, delta.y);
    if (self.contentView != nil) {
        self.contentView.transform = self.contentTransform;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    #if TARGET_OS_MACCATALYST
    [NSCursor pop];
    #endif
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    #if TARGET_OS_MACCATALYST
    [NSCursor pop];
    #endif
}

@end
