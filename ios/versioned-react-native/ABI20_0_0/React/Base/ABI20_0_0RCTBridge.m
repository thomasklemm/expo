/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI20_0_0RCTBridge.h"
#import "ABI20_0_0RCTBridge+Private.h"

#import <objc/runtime.h>

#import "ABI20_0_0RCTConvert.h"
#import "ABI20_0_0RCTEventDispatcher.h"
#import "ABI20_0_0RCTJSEnvironment.h"
#import "ABI20_0_0RCTLog.h"
#import "ABI20_0_0RCTModuleData.h"
#import "ABI20_0_0RCTPerformanceLogger.h"
#import "ABI20_0_0RCTProfile.h"
#import "ABI20_0_0RCTReloadCommand.h"
#import "ABI20_0_0RCTUtils.h"

NSString *const ABI20_0_0RCTJavaScriptWillStartLoadingNotification = @"ABI20_0_0RCTJavaScriptWillStartLoadingNotification";
NSString *const ABI20_0_0RCTJavaScriptDidLoadNotification = @"ABI20_0_0RCTJavaScriptDidLoadNotification";
NSString *const ABI20_0_0RCTJavaScriptDidFailToLoadNotification = @"ABI20_0_0RCTJavaScriptDidFailToLoadNotification";
NSString *const ABI20_0_0RCTDidInitializeModuleNotification = @"ABI20_0_0RCTDidInitializeModuleNotification";

static NSMutableArray<Class> *ABI20_0_0RCTModuleClasses;
NSArray<Class> *ABI20_0_0RCTGetModuleClasses(void)
{
  return ABI20_0_0RCTModuleClasses;
}

void ABI20_0_0RCTFBQuickPerformanceLoggerConfigureHooks(__unused JSGlobalContextRef ctx) { }

/**
 * Register the given class as a bridge module. All modules must be registered
 * prior to the first bridge initialization.
 */
void ABI20_0_0RCTRegisterModule(Class);
void ABI20_0_0RCTRegisterModule(Class moduleClass)
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    ABI20_0_0RCTModuleClasses = [NSMutableArray new];
  });

  ABI20_0_0RCTAssert([moduleClass conformsToProtocol:@protocol(ABI20_0_0RCTBridgeModule)],
            @"%@ does not conform to the ABI20_0_0RCTBridgeModule protocol",
            moduleClass);

  // Register module
  [ABI20_0_0RCTModuleClasses addObject:moduleClass];
}

/**
 * This function returns the module name for a given class.
 */
NSString *ABI20_0_0RCTBridgeModuleNameForClass(Class cls)
{
#if ABI20_0_0RCT_DEBUG
  ABI20_0_0RCTAssert([cls conformsToProtocol:@protocol(ABI20_0_0RCTBridgeModule)],
            @"Bridge module `%@` does not conform to ABI20_0_0RCTBridgeModule", cls);
#endif

  NSString *name = [cls moduleName];
  if (name.length == 0) {
    name = NSStringFromClass(cls);
  }

  name = ABI20_0_0EX_REMOVE_VERSION(name);

  if ([name hasPrefix:@"RK"]) {
    name = [name substringFromIndex:2];
  } else if ([name hasPrefix:@"RCT"]) {
    name = [name substringFromIndex:3];
  }

  return name;
}

#if ABI20_0_0RCT_DEBUG
void ABI20_0_0RCTVerifyAllModulesExported(NSArray *extraModules)
{
  // Check for unexported modules
  unsigned int classCount;
  Class *classes = objc_copyClassList(&classCount);

  NSMutableSet *moduleClasses = [NSMutableSet new];
  [moduleClasses addObjectsFromArray:ABI20_0_0RCTGetModuleClasses()];
  [moduleClasses addObjectsFromArray:[extraModules valueForKeyPath:@"class"]];

  for (unsigned int i = 0; i < classCount; i++) {
    Class cls = classes[i];
    Class superclass = cls;
    while (superclass) {
      if (class_conformsToProtocol(superclass, @protocol(ABI20_0_0RCTBridgeModule))) {
        if ([moduleClasses containsObject:cls]) {
          break;
        }

        // Verify it's not a super-class of one of our moduleClasses
        BOOL isModuleSuperClass = NO;
        for (Class moduleClass in moduleClasses) {
          if ([moduleClass isSubclassOfClass:cls]) {
            isModuleSuperClass = YES;
            break;
          }
        }
        if (isModuleSuperClass) {
          break;
        }

        ABI20_0_0RCTLogWarn(@"Class %@ was not exported. Did you forget to use ABI20_0_0RCT_EXPORT_MODULE()?", cls);
        break;
      }
      superclass = class_getSuperclass(superclass);
    }
  }

  free(classes);
}
#endif

@interface ABI20_0_0RCTBridge () <ABI20_0_0RCTReloadListener>
@end

@implementation ABI20_0_0RCTBridge
{
  NSURL *_delegateBundleURL;
}

dispatch_queue_t ABI20_0_0RCTJSThread;

+ (void)initialize
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{

    // Set up JS thread
    ABI20_0_0RCTJSThread = (id)kCFNull;
  });
}

static ABI20_0_0RCTBridge *ABI20_0_0RCTCurrentBridgeInstance = nil;

/**
 * The last current active bridge instance. This is set automatically whenever
 * the bridge is accessed. It can be useful for static functions or singletons
 * that need to access the bridge for purposes such as logging, but should not
 * be relied upon to return any particular instance, due to race conditions.
 */
+ (instancetype)currentBridge
{
  return ABI20_0_0RCTCurrentBridgeInstance;
}

+ (void)setCurrentBridge:(ABI20_0_0RCTBridge *)currentBridge
{
  ABI20_0_0RCTCurrentBridgeInstance = currentBridge;
}

- (instancetype)initWithDelegate:(id<ABI20_0_0RCTBridgeDelegate>)delegate
                   launchOptions:(NSDictionary *)launchOptions
{
  return [self initWithDelegate:delegate
                      bundleURL:nil
                 moduleProvider:nil
                  launchOptions:launchOptions];
}

- (instancetype)initWithBundleURL:(NSURL *)bundleURL
                   moduleProvider:(ABI20_0_0RCTBridgeModuleListProvider)block
                    launchOptions:(NSDictionary *)launchOptions
{
  return [self initWithDelegate:nil
                      bundleURL:bundleURL
                 moduleProvider:block
                  launchOptions:launchOptions];
}

- (instancetype)initWithDelegate:(id<ABI20_0_0RCTBridgeDelegate>)delegate
                       bundleURL:(NSURL *)bundleURL
                  moduleProvider:(ABI20_0_0RCTBridgeModuleListProvider)block
                   launchOptions:(NSDictionary *)launchOptions
{
  if (self = [super init]) {
    _delegate = delegate;
    _bundleURL = bundleURL;
    _moduleProvider = block;
    _launchOptions = [launchOptions copy];

    [self setUp];
  }
  return self;
}

ABI20_0_0RCT_NOT_IMPLEMENTED(- (instancetype)init)

- (void)dealloc
{
  /**
   * This runs only on the main thread, but crashes the subclass
   * ABI20_0_0RCTAssertMainQueue();
   */
  [self invalidate];
}

- (void)didReceiveReloadCommand
{
  [self reload];
}

- (NSArray<Class> *)moduleClasses
{
  return self.batchedBridge.moduleClasses;
}

- (id)moduleForName:(NSString *)moduleName
{
  return [self.batchedBridge moduleForName:moduleName];
}

- (id)moduleForClass:(Class)moduleClass
{
  return [self moduleForName:ABI20_0_0RCTBridgeModuleNameForClass(moduleClass)];
}

- (NSArray *)modulesConformingToProtocol:(Protocol *)protocol
{
  NSMutableArray *modules = [NSMutableArray new];
  for (Class moduleClass in self.moduleClasses) {
    if ([moduleClass conformsToProtocol:protocol]) {
      id module = [self moduleForClass:moduleClass];
      if (module) {
        [modules addObject:module];
      }
    }
  }
  return [modules copy];
}

- (BOOL)moduleIsInitialized:(Class)moduleClass
{
  return [self.batchedBridge moduleIsInitialized:moduleClass];
}

- (void)whitelistedModulesDidChange
{
  [self.batchedBridge whitelistedModulesDidChange];
}

- (void)reload
{
  /**
   * Any thread
   */
  dispatch_async(dispatch_get_main_queue(), ^{
    [self invalidate];
    [self setUp];
  });
}

- (void)requestReload
{
  [self reload];
}

- (Class)bridgeClass
{
  // In order to facilitate switching between bridges with only build
  // file changes, this uses reflection to check which bridges are
  // available.  This is a short-term hack until ABI20_0_0RCTBatchedBridge is
  // removed.

  Class batchedBridgeClass = objc_lookUpClass("ABI20_0_0RCTBatchedBridge");
  Class cxxBridgeClass = objc_lookUpClass("ABI20_0_0RCTCxxBridge");

  Class implClass = nil;

  if ([self.delegate respondsToSelector:@selector(shouldBridgeUseCxxBridge:)]) {
    if ([self.delegate shouldBridgeUseCxxBridge:self]) {
      implClass = cxxBridgeClass;
    } else {
      implClass = batchedBridgeClass;
    }
  } else if (cxxBridgeClass != nil) {
    implClass = cxxBridgeClass;
  } else if (batchedBridgeClass != nil) {
    implClass = batchedBridgeClass;
  }

  ABI20_0_0RCTAssert(implClass != nil, @"No bridge implementation is available, giving up.");
  return implClass;
}

- (void)setUp
{
  ABI20_0_0RCT_PROFILE_BEGIN_EVENT(0, @"-[ABI20_0_0RCTBridge setUp]", nil);

  _performanceLogger = [ABI20_0_0RCTPerformanceLogger new];
  [_performanceLogger markStartForTag:ABI20_0_0RCTPLBridgeStartup];
  [_performanceLogger markStartForTag:ABI20_0_0RCTPLTTI];

  Class bridgeClass = self.bridgeClass;

  #if ABI20_0_0RCT_DEV
  ABI20_0_0RCTExecuteOnMainQueue(^{
    ABI20_0_0RCTRegisterReloadCommandListener(self);
  });
  #endif

  // Only update bundleURL from delegate if delegate bundleURL has changed
  NSURL *previousDelegateURL = _delegateBundleURL;
  _delegateBundleURL = [self.delegate sourceURLForBridge:self];
  if (_delegateBundleURL && ![_delegateBundleURL isEqual:previousDelegateURL]) {
    _bundleURL = _delegateBundleURL;
  }

  // Sanitize the bundle URL
  _bundleURL = [ABI20_0_0RCTConvert NSURL:_bundleURL.absoluteString];

  self.batchedBridge = [[bridgeClass alloc] initWithParentBridge:self];
  [self.batchedBridge start];

  ABI20_0_0RCT_PROFILE_END_EVENT(ABI20_0_0RCTProfileTagAlways, @"");
}

- (BOOL)isLoading
{
  return self.batchedBridge.loading;
}

- (BOOL)isValid
{
  return self.batchedBridge.valid;
}

- (BOOL)isBatchActive
{
  return [_batchedBridge isBatchActive];
}

- (void)invalidate
{
  ABI20_0_0RCTBridge *batchedBridge = self.batchedBridge;
  self.batchedBridge = nil;

  if (batchedBridge) {
    ABI20_0_0RCTExecuteOnMainQueue(^{
      [batchedBridge invalidate];
    });
  }
}

- (void)enqueueJSCall:(NSString *)moduleDotMethod args:(NSArray *)args
{
  NSArray<NSString *> *ids = [moduleDotMethod componentsSeparatedByString:@"."];
  NSString *module = ids[0];
  NSString *method = ids[1];
  [self enqueueJSCall:module method:method args:args completion:NULL];
}

- (void)enqueueJSCall:(NSString *)module method:(NSString *)method args:(NSArray *)args completion:(dispatch_block_t)completion
{
  [self.batchedBridge enqueueJSCall:module method:method args:args completion:completion];
}

- (void)enqueueCallback:(NSNumber *)cbID args:(NSArray *)args
{
  [self.batchedBridge enqueueCallback:cbID args:args];
}

- (JSValue *)callFunctionOnModule:(NSString *)module
                           method:(NSString *)method
                        arguments:(NSArray *)arguments
                            error:(NSError **)error
{
  return [self.batchedBridge callFunctionOnModule:module method:method arguments:arguments error:error];
}

@end

@implementation ABI20_0_0RCTBridge (JavaScriptCore)

- (JSContext *)jsContext
{
  return [self.batchedBridge jsContext];
}

- (JSGlobalContextRef)jsContextRef
{
  return [self.batchedBridge jsContextRef];
}

@end
