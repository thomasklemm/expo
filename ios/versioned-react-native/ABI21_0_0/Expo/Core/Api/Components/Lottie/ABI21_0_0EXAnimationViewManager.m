//
//  ABI21_0_0EXAnimationViewManager.m
//  LottieReactABI21_0_0Native
//
//  Created by Leland Richardson on 12/12/16.
//  Copyright © 2016 Airbnb. All rights reserved.
//

#import "ABI21_0_0EXAnimationViewManager.h"

#import "ABI21_0_0EXContainerView.h"

// import ABI21_0_0RCTBridge.h
#if __has_include(<ReactABI21_0_0/ABI21_0_0RCTBridge.h>)
#import <ReactABI21_0_0/ABI21_0_0RCTBridge.h>
#elif __has_include("ABI21_0_0RCTBridge.h")
#import "ABI21_0_0RCTBridge.h"
#else
#import "ReactABI21_0_0/ABI21_0_0RCTBridge.h"
#endif

// import ABI21_0_0RCTUIManager.h
#if __has_include(<ReactABI21_0_0/ABI21_0_0RCTUIManager.h>)
#import <ReactABI21_0_0/ABI21_0_0RCTUIManager.h>
#elif __has_include("ABI21_0_0RCTUIManager.h")
#import "ABI21_0_0RCTUIManager.h"
#else
#import "ReactABI21_0_0/ABI21_0_0RCTUIManager.h"
#endif

#import <Lottie/Lottie.h>

@implementation ABI21_0_0EXAnimationViewManager

ABI21_0_0RCT_EXPORT_MODULE(LottieAnimationView)

- (UIView *)view
{
  return [ABI21_0_0EXContainerView new];
}

- (NSDictionary *)constantsToExport
{
  return @{
    @"VERSION": @1,
  };
}

ABI21_0_0RCT_EXPORT_VIEW_PROPERTY(sourceJson, NSDictionary);
ABI21_0_0RCT_EXPORT_VIEW_PROPERTY(sourceName, NSString);
ABI21_0_0RCT_EXPORT_VIEW_PROPERTY(progress, CGFloat);
ABI21_0_0RCT_EXPORT_VIEW_PROPERTY(loop, BOOL);
ABI21_0_0RCT_EXPORT_VIEW_PROPERTY(speed, CGFloat);

ABI21_0_0RCT_EXPORT_METHOD(play:(nonnull NSNumber *)ReactABI21_0_0Tag)
{
  [self.bridge.uiManager addUIBlock:^(__unused ABI21_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    id view = viewRegistry[ReactABI21_0_0Tag];
    if (![view isKindOfClass:[ABI21_0_0EXContainerView class]]) {
      ABI21_0_0RCTLogError(@"Invalid view returned from registry, expecting LottieContainerView, got: %@", view);
    } else {
      ABI21_0_0EXContainerView *lottieView = (ABI21_0_0EXContainerView *)view;
      [lottieView play];
    }
  }];
}

ABI21_0_0RCT_EXPORT_METHOD(reset:(nonnull NSNumber *)ReactABI21_0_0Tag)
{
  [self.bridge.uiManager addUIBlock:^(__unused ABI21_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    id view = viewRegistry[ReactABI21_0_0Tag];
    if (![view isKindOfClass:[ABI21_0_0EXContainerView class]]) {
      ABI21_0_0RCTLogError(@"Invalid view returned from registry, expecting LottieContainerView, got: %@", view);
    } else {
      ABI21_0_0EXContainerView *lottieView = (ABI21_0_0EXContainerView *)view;
      [lottieView reset];
    }
  }];
}

@end
