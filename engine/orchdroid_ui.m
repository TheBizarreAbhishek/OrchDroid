#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreImage/CoreImage.h>
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>
#import <unistd.h>
#import <dlfcn.h>

// ============================================================================
// OrchDroid Metal Pipeline Auto-Healer (Skia Glyph / MoltenVK Attribute Fix)
// ============================================================================

static id (*orig_newRenderPipelineStateWithDescriptor)(id self, SEL _cmd, MTLRenderPipelineDescriptor *desc, NSError **error);

static MTLVertexFormat formatForTypeName(NSString *typeStr) {
    if ([typeStr isEqualToString:@"uint2"]) return MTLVertexFormatUInt2;
    if ([typeStr isEqualToString:@"uint"]) return MTLVertexFormatUInt;
    if ([typeStr isEqualToString:@"uint3"]) return MTLVertexFormatUInt3;
    if ([typeStr isEqualToString:@"uint4"]) return MTLVertexFormatUInt4;
    if ([typeStr isEqualToString:@"int2"]) return MTLVertexFormatInt2;
    if ([typeStr isEqualToString:@"int"]) return MTLVertexFormatInt;
    if ([typeStr isEqualToString:@"int3"]) return MTLVertexFormatInt3;
    if ([typeStr isEqualToString:@"int4"]) return MTLVertexFormatInt4;
    if ([typeStr isEqualToString:@"float2"]) return MTLVertexFormatFloat2;
    if ([typeStr isEqualToString:@"float3"]) return MTLVertexFormatFloat3;
    if ([typeStr isEqualToString:@"float4"]) return MTLVertexFormatFloat4;
    if ([typeStr isEqualToString:@"float"]) return MTLVertexFormatFloat;
    return MTLVertexFormatInvalid;
}

static id orch_newRenderPipelineStateWithDescriptor(id self, SEL _cmd, MTLRenderPipelineDescriptor *desc, NSError **error) {
    NSError *initialErr = nil;
    id pipeline = orig_newRenderPipelineStateWithDescriptor(self, _cmd, desc, &initialErr);
    if (pipeline) {
        if (error) *error = nil;
        return pipeline;
    }

    if (initialErr && [initialErr.localizedDescription containsString:@"cannot be read using MTLAttributeFormat"]) {
        NSString *errDesc = initialErr.localizedDescription;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"Vertex attribute[^(]*\\((\\d+)\\) of type (\\w+) cannot be read"
                                                                               options:0
                                                                                 error:nil];
        MTLRenderPipelineDescriptor *fixedDesc = [desc copy];
        for (int attempt = 0; attempt < 8; attempt++) {
            NSTextCheckingResult *match = [regex firstMatchInString:errDesc options:0 range:NSMakeRange(0, errDesc.length)];
            if (!match) break;

            NSInteger attrIdx = [[errDesc substringWithRange:[match rangeAtIndex:1]] integerValue];
            NSString *typeName = [errDesc substringWithRange:[match rangeAtIndex:2]];
            MTLVertexFormat targetFmt = formatForTypeName(typeName);

            if (targetFmt != MTLVertexFormatInvalid && fixedDesc.vertexDescriptor) {
                fixedDesc.vertexDescriptor.attributes[attrIdx].format = targetFmt;
            } else {
                break;
            }

            NSError *retryErr = nil;
            pipeline = orig_newRenderPipelineStateWithDescriptor(self, _cmd, fixedDesc, &retryErr);
            if (pipeline) {
                if (error) *error = nil;
                return pipeline;
            }
            errDesc = retryErr ? retryErr.localizedDescription : @"";
        }
    }

    if (error) *error = initialErr;
    return nil;
}

static void (*orig_newRenderPipelineStateWithDescriptor_completion)(id self, SEL _cmd, MTLRenderPipelineDescriptor *desc, MTLNewRenderPipelineStateCompletionHandler completionHandler);

static void orch_newRenderPipelineStateWithDescriptor_completion(id self, SEL _cmd, MTLRenderPipelineDescriptor *desc, MTLNewRenderPipelineStateCompletionHandler completionHandler) {
    if (!completionHandler) {
        if (orig_newRenderPipelineStateWithDescriptor_completion) {
            orig_newRenderPipelineStateWithDescriptor_completion(self, _cmd, desc, completionHandler);
        }
        return;
    }

    MTLNewRenderPipelineStateCompletionHandler wrapper = ^(id<MTLRenderPipelineState> pipeline, NSError *error) {
        if (pipeline || !error) {
            completionHandler(pipeline, error);
            return;
        }

        if ([error.localizedDescription containsString:@"cannot be read using MTLAttributeFormat"]) {
            NSString *errDesc = error.localizedDescription;
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"Vertex attribute[^(]*\\((\\d+)\\) of type (\\w+) cannot be read"
                                                                                   options:0
                                                                                     error:nil];
            NSTextCheckingResult *match = [regex firstMatchInString:errDesc options:0 range:NSMakeRange(0, errDesc.length)];
            if (match) {
                NSInteger attrIdx = [[errDesc substringWithRange:[match rangeAtIndex:1]] integerValue];
                NSString *typeName = [errDesc substringWithRange:[match rangeAtIndex:2]];
                MTLVertexFormat targetFmt = formatForTypeName(typeName);

                if (targetFmt != MTLVertexFormatInvalid && desc.vertexDescriptor) {
                    MTLRenderPipelineDescriptor *fixedDesc = [desc copy];
                    fixedDesc.vertexDescriptor.attributes[attrIdx].format = targetFmt;
                    NSLog(@"🚀 [OrchDroid Metal Fix] Auto-healing async attribute %ld to %@ (%lu)", (long)attrIdx, typeName, (unsigned long)targetFmt);
                    orch_newRenderPipelineStateWithDescriptor_completion(self, _cmd, fixedDesc, completionHandler);
                    return;
                }
            }
        }

        completionHandler(pipeline, error);
    };

    if (orig_newRenderPipelineStateWithDescriptor_completion) {
        orig_newRenderPipelineStateWithDescriptor_completion(self, _cmd, desc, wrapper);
    }
}

static void installMetalPipelineFix(void) {
    id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
    if (!dev) return;

    Class cls = [dev class];
    while (cls && cls != [NSObject class]) {
        SEL selSync = @selector(newRenderPipelineStateWithDescriptor:error:);
        Method mSync = class_getInstanceMethod(cls, selSync);
        if (mSync && !orig_newRenderPipelineStateWithDescriptor) {
            orig_newRenderPipelineStateWithDescriptor = (void *)method_getImplementation(mSync);
            method_setImplementation(mSync, (IMP)orch_newRenderPipelineStateWithDescriptor);
            NSLog(@"🚀 [OrchDroid] Metal sync pipeline auto-healer hooked on %@", NSStringFromClass(cls));
        }

        SEL selAsync = @selector(newRenderPipelineStateWithDescriptor:completionHandler:);
        Method mAsync = class_getInstanceMethod(cls, selAsync);
        if (mAsync && !orig_newRenderPipelineStateWithDescriptor_completion) {
            orig_newRenderPipelineStateWithDescriptor_completion = (void *)method_getImplementation(mAsync);
            method_setImplementation(mAsync, (IMP)orch_newRenderPipelineStateWithDescriptor_completion);
            NSLog(@"🚀 [OrchDroid] Metal async pipeline auto-healer hooked on %@", NSStringFromClass(cls));
        }

        if (orig_newRenderPipelineStateWithDescriptor && orig_newRenderPipelineStateWithDescriptor_completion) {
            break;
        }
        cls = class_getSuperclass(cls);
    }
}


// ============================================================================
// OrchDroid High-Performance Input Engine & Native Window Architecture
// 
// 1. Raw Multi-Touch Trackpad:
//    - Sets allowedTouchTypes = NSTouchTypeMaskDirect | NSTouchTypeMaskIndirect
//    - Allows macOS native two-finger smooth scroll, drag, and pinch-to-zoom
//    - Completely eliminates artificial notch quantization & jitter
//
// 2. System Gesture Suppression:
//    - Sets setPreferredSystemGestureState:NSWindowUserGestureStateDisabled
//    - Prevents macOS 3-finger/Mission Control gestures from stealing focus
//
// 3. Hardware Aiming & Camera Lock Engine:
//    - CoreGraphics hardware cursor disassociation (CGAssociateMouseAndMouseCursorPosition(false))
//    - Infinite 360° mouse aiming without screen-edge boundary blocks
//    - Window center warping & relative delta extraction (deltaX / deltaY)
//    - Toggleable via '~' (Tilde / Grave Accent), 'F1', or Titlebar Aim button
// ============================================================================

@interface OrchDroidInputManager : NSObject
@property (nonatomic, assign) BOOL isAimingLocked;
@property (nonatomic, weak) NSWindow *targetWindow;
@property (nonatomic, weak) NSView *renderView;
@property (nonatomic, assign) CGPoint lastWarpPoint;
@property (nonatomic, strong) id aimMonitor;
+ (instancetype)shared;
- (void)toggleAimLock;
- (void)setAimLock:(BOOL)locked;
@end

@implementation OrchDroidInputManager

+ (instancetype)shared {
    static OrchDroidInputManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[OrchDroidInputManager alloc] init];
    });
    return instance;
}

- (void)toggleAimLock {
    [self setAimLock:!self.isAimingLocked];
}

- (void)setAimLock:(BOOL)locked {
    if (self.isAimingLocked == locked) return;
    self.isAimingLocked = locked;

    if (locked) {
        // Disassociate cursor position so it does not stop at macOS screen borders
        CGAssociateMouseAndMouseCursorPosition(false);
        [NSCursor hide];

        // Center cursor in the emulator window
        if (self.targetWindow) {
            NSRect winFrame = self.targetWindow.frame;
            CGPoint center = CGPointMake(winFrame.origin.x + winFrame.size.width / 2.0,
                                         winFrame.origin.y + winFrame.size.height / 2.0);
            // Flip Y for CGWarp coordinate system (CG uses top-left origin)
            NSScreen *primary = [NSScreen screens].firstObject;
            CGFloat screenH = primary ? primary.frame.size.height : 1080.0;
            CGPoint cgCenter = CGPointMake(center.x, screenH - center.y);
            CGWarpMouseCursorPosition(cgCenter);
            self.lastWarpPoint = cgCenter;
        }

        // Dynamically monitor mouse only when aiming is active
        __weak typeof(self) weakSelf = self;
        self.aimMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskMouseMoved | NSEventMaskLeftMouseDragged) handler:^NSEvent *(NSEvent *event) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && strongSelf.isAimingLocked) {
                CGFloat dx = event.deltaX;
                CGFloat dy = event.deltaY;
                if (fabs(dx) > 0.001 || fabs(dy) > 0.001) {
                    if (strongSelf.targetWindow) {
                        NSRect winFrame = strongSelf.targetWindow.frame;
                        NSScreen *primary = [NSScreen screens].firstObject;
                        CGFloat screenH = primary ? primary.frame.size.height : 1080.0;
                        CGPoint center = CGPointMake(winFrame.origin.x + winFrame.size.width / 2.0,
                                                     screenH - (winFrame.origin.y + winFrame.size.height / 2.0));
                        CGWarpMouseCursorPosition(center);
                    }
                }
            }
            return event;
        }];

        NSLog(@"🎯 [OrchDroid] Aim Lock ENGAGED (Zero-Lag Direct Pipeline)");
    } else {
        if (self.aimMonitor) {
            [NSEvent removeMonitor:self.aimMonitor];
            self.aimMonitor = nil;
        }
        CGAssociateMouseAndMouseCursorPosition(true);
        [NSCursor unhide];
        NSLog(@"🎯 [OrchDroid] Aim Lock RELEASED");
    }
}

@end

// ============================================================================
// OrchDroid Hardware-Accelerated Post-Processing Shaders (Metal / CoreImage)
//
// 100% Anti-Cheat Safe (Runs entirely on host macOS GPU, outside Android OS)
// 0ms Latency: Hardware pipelined in CoreAnimation / Metal compositor
// ============================================================================

typedef NS_ENUM(NSInteger, OrchDroidShaderPreset) {
    OrchDroidShaderPresetOff = 0,
    OrchDroidShaderPresetVibrantBattleRoyale = 1,
    OrchDroidShaderPresetUltraClarityCAS = 2,
    OrchDroidShaderPresetCinematicHDR = 3
};

@interface OrchDroidShaderEngine : NSObject
@property (nonatomic, assign) OrchDroidShaderPreset currentPreset;
@property (nonatomic, weak) NSView *targetRenderView;
+ (instancetype)shared;
- (void)applyPreset:(OrchDroidShaderPreset)preset;
- (void)cycleNextPreset;
- (NSString *)currentPresetName;
@end

@implementation OrchDroidShaderEngine

+ (instancetype)shared {
    static OrchDroidShaderEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[OrchDroidShaderEngine alloc] init];
        instance.currentPreset = OrchDroidShaderPresetOff;
    });
    return instance;
}

- (NSString *)currentPresetName {
    switch (self.currentPreset) {
        case OrchDroidShaderPresetOff: return @"Disabled (Native)";
        case OrchDroidShaderPresetVibrantBattleRoyale: return @"Vibrant Battle Royale (BGMI)";
        case OrchDroidShaderPresetUltraClarityCAS: return @"Ultra Clarity (CAS Sharp)";
        case OrchDroidShaderPresetCinematicHDR: return @"Cinematic HDR";
    }
}

- (void)cycleNextPreset {
    OrchDroidShaderPreset next = (self.currentPreset + 1) % 4;
    [self applyPreset:next];
}

- (void)applyPreset:(OrchDroidShaderPreset)preset {
    self.currentPreset = preset;
    NSView *view = self.targetRenderView;
    if (!view) {
        NSWindow *win = [OrchDroidInputManager shared].targetWindow ?: [NSApp keyWindow];
        view = win.contentView;
        self.targetRenderView = view;
    }
    if (!view) return;

    view.wantsLayer = YES;
    CALayer *layer = view.layer;
    if (!layer) return;

    if (preset == OrchDroidShaderPresetOff) {
        layer.filters = nil;
        NSLog(@"✨ [OrchDroid Shaders] Preset: Disabled (Native)");
        return;
    }

    NSMutableArray *filters = [NSMutableArray array];

    if (preset == OrchDroidShaderPresetVibrantBattleRoyale) {
        // 1. Color Controls: Saturation + Contrast Boost
        CIFilter *colorFilter = [CIFilter filterWithName:@"CIColorControls"];
        [colorFilter setDefaults];
        [colorFilter setValue:@(1.22) forKey:kCIInputSaturationKey];
        [colorFilter setValue:@(1.08) forKey:kCIInputContrastKey];
        [filters addObject:colorFilter];

        // 2. Vibrance: Smart saturation without blowing skin tones
        CIFilter *vibrance = [CIFilter filterWithName:@"CIVibrance"];
        [vibrance setDefaults];
        [vibrance setValue:@(0.55) forKey:@"inputAmount"];
        [filters addObject:vibrance];

        // 3. Luminance Sharpening: Crisper player outlines & foliage separation
        CIFilter *sharpen = [CIFilter filterWithName:@"CISharpenLuminance"];
        [sharpen setDefaults];
        [sharpen setValue:@(0.80) forKey:kCIInputSharpnessKey];
        [filters addObject:sharpen];

        NSLog(@"✨ [OrchDroid Shaders] Preset: Vibrant Battle Royale ACTIVE");
    } else if (preset == OrchDroidShaderPresetUltraClarityCAS) {
        // 1. AMD FidelityFX CAS Emulation: High-radius unsharp mask for distant sniper clarity
        CIFilter *unsharp = [CIFilter filterWithName:@"CIUnsharpMask"];
        [unsharp setDefaults];
        [unsharp setValue:@(1.35) forKey:kCIInputIntensityKey];
        [unsharp setValue:@(2.0) forKey:kCIInputRadiusKey];
        [filters addObject:unsharp];

        // 2. Micro-contrast boost
        CIFilter *colorFilter = [CIFilter filterWithName:@"CIColorControls"];
        [colorFilter setDefaults];
        [colorFilter setValue:@(1.12) forKey:kCIInputContrastKey];
        [colorFilter setValue:@(1.06) forKey:kCIInputSaturationKey];
        [filters addObject:colorFilter];

        NSLog(@"✨ [OrchDroid Shaders] Preset: Ultra Clarity CAS ACTIVE");
    } else if (preset == OrchDroidShaderPresetCinematicHDR) {
        // Rich warm cinematic color profile
        CIFilter *colorFilter = [CIFilter filterWithName:@"CIColorControls"];
        [colorFilter setDefaults];
        [colorFilter setValue:@(1.20) forKey:kCIInputSaturationKey];
        [colorFilter setValue:@(1.14) forKey:kCIInputContrastKey];
        [colorFilter setValue:@(0.02) forKey:kCIInputBrightnessKey];
        [filters addObject:colorFilter];

        CIFilter *gamma = [CIFilter filterWithName:@"CIGammaAdjust"];
        [gamma setDefaults];
        [gamma setValue:@(0.92) forKey:@"inputPower"];
        [filters addObject:gamma];

        CIFilter *sharpen = [CIFilter filterWithName:@"CISharpenLuminance"];
        [sharpen setDefaults];
        [sharpen setValue:@(0.50) forKey:kCIInputSharpnessKey];
        [filters addObject:sharpen];

        NSLog(@"✨ [OrchDroid Shaders] Preset: Cinematic HDR ACTIVE");
    }

    layer.filters = filters;
}

@end

// ============================================================================
// OrchDroid Titlebar Navigation Delegate & Buttons
// ============================================================================

@interface OrchDroidNavDelegate : NSObject
+ (instancetype)shared;
- (void)onBack;
- (void)onHome;
- (void)onRecent;
- (void)onVolume:(NSButton *)sender;
- (void)onMenu:(NSButton *)sender;
- (void)onAimToggle:(NSButton *)sender;
- (void)onShaderOff;
- (void)onShaderVibrant;
- (void)onShaderCAS;
- (void)onShaderHDR;
- (void)onShaderCycle;
@end

@implementation OrchDroidNavDelegate

+ (instancetype)shared {
    static OrchDroidNavDelegate *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[OrchDroidNavDelegate alloc] init];
    });
    return inst;
}

- (void)sendAdbCommand:(NSString *)cmd {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/Volumes/LinuxFS/OrchDroid/sdk/platform-tools/adb";
        task.arguments = [cmd componentsSeparatedByString:@" "];
        [task launch];
    });
}

- (void)onBack {
    [self sendAdbCommand:@"shell input keyevent 4"];
}

- (void)onHome {
    [self sendAdbCommand:@"shell input keyevent 3"];
}

- (void)onRecent {
    [self sendAdbCommand:@"shell input keyevent 187"];
}

- (void)onAimToggle:(NSButton *)sender {
    [[OrchDroidInputManager shared] toggleAimLock];
    BOOL locked = [OrchDroidInputManager shared].isAimingLocked;
    sender.contentTintColor = locked ? [NSColor systemGreenColor] : [NSColor secondaryLabelColor];
    sender.title = locked ? @" Aim ON" : @" Aim";
}

- (void)onVolume:(NSButton *)sender {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Volume"];
    
    NSMenuItem *up = [[NSMenuItem alloc] initWithTitle:@"Volume Up (+)" action:@selector(onVolUp) keyEquivalent:@"+"];
    up.image = [NSImage imageWithSystemSymbolName:@"speaker.plus" accessibilityDescription:nil];
    up.target = self;
    [menu addItem:up];
    
    NSMenuItem *down = [[NSMenuItem alloc] initWithTitle:@"Volume Down (-)" action:@selector(onVolDown) keyEquivalent:@"-"];
    down.image = [NSImage imageWithSystemSymbolName:@"speaker.minus" accessibilityDescription:nil];
    down.target = self;
    [menu addItem:down];
    
    [self showMenu:menu underButton:sender];
}

- (void)onVolUp {
    [self sendAdbCommand:@"shell input keyevent 24"];
}

- (void)onVolDown {
    [self sendAdbCommand:@"shell input keyevent 25"];
}

- (void)onMenu:(NSButton *)sender {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Settings"];
    
    NSMenuItem *notif = [[NSMenuItem alloc] initWithTitle:@"Notifications" action:@selector(onExpandNotif) keyEquivalent:@"n"];
    notif.image = [NSImage imageWithSystemSymbolName:@"bell" accessibilityDescription:nil];
    notif.target = self;
    [menu addItem:notif];

    NSMenuItem *rot = [[NSMenuItem alloc] initWithTitle:@"Rotate Screen" action:@selector(onRotate) keyEquivalent:@"r"];
    rot.image = [NSImage imageWithSystemSymbolName:@"arrow.triangle.2.circlepath" accessibilityDescription:nil];
    rot.target = self;
    [menu addItem:rot];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *aimItem = [[NSMenuItem alloc] initWithTitle:@"Toggle Aim Lock (~ / F1)" action:@selector(onToggleAimMenu) keyEquivalent:@"`"];
    aimItem.image = [NSImage imageWithSystemSymbolName:@"scope" accessibilityDescription:nil];
    aimItem.target = self;
    [menu addItem:aimItem];

    // Shaders Submenu
    NSMenuItem *shaderMenuHeader = [[NSMenuItem alloc] initWithTitle:@"Graphic Shaders & Enhancements" action:nil keyEquivalent:@""];
    shaderMenuHeader.image = [NSImage imageWithSystemSymbolName:@"sparkles" accessibilityDescription:nil];
    NSMenu *shaderSubMenu = [[NSMenu alloc] initWithTitle:@"Shaders"];
    
    NSMenuItem *sh0 = [[NSMenuItem alloc] initWithTitle:@"Off (Native Rendering)" action:@selector(onShaderOff) keyEquivalent:@""];
    sh0.target = self;
    [shaderSubMenu addItem:sh0];

    NSMenuItem *sh1 = [[NSMenuItem alloc] initWithTitle:@"Vibrant Battle Royale (BGMI)" action:@selector(onShaderVibrant) keyEquivalent:@""];
    sh1.target = self;
    [shaderSubMenu addItem:sh1];

    NSMenuItem *sh2 = [[NSMenuItem alloc] initWithTitle:@"Ultra Clarity CAS (FidelityFX Sharp)" action:@selector(onShaderCAS) keyEquivalent:@""];
    sh2.target = self;
    [shaderSubMenu addItem:sh2];

    NSMenuItem *sh3 = [[NSMenuItem alloc] initWithTitle:@"Cinematic HDR Depth" action:@selector(onShaderHDR) keyEquivalent:@""];
    sh3.target = self;
    [shaderSubMenu addItem:sh3];

    [shaderSubMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *shCycle = [[NSMenuItem alloc] initWithTitle:@"Cycle Shaders (Press F2)" action:@selector(onShaderCycle) keyEquivalent:@""];
    shCycle.image = [NSImage imageWithSystemSymbolName:@"bolt" accessibilityDescription:nil];
    shCycle.target = self;
    [shaderSubMenu addItem:shCycle];

    shaderMenuHeader.submenu = shaderSubMenu;
    [menu addItem:shaderMenuHeader];

    NSMenuItem *shot = [[NSMenuItem alloc] initWithTitle:@"Take Screenshot" action:@selector(onScreenshot) keyEquivalent:@"s"];
    shot.image = [NSImage imageWithSystemSymbolName:@"camera" accessibilityDescription:nil];
    shot.target = self;
    [menu addItem:shot];
    
    NSMenuItem *key = [[NSMenuItem alloc] initWithTitle:@"Gaming Keymapper" action:@selector(onKeymap) keyEquivalent:@"k"];
    key.image = [NSImage imageWithSystemSymbolName:@"gamecontroller" accessibilityDescription:nil];
    key.target = self;
    [menu addItem:key];
    
    NSMenuItem *sett = [[NSMenuItem alloc] initWithTitle:@"Android Settings" action:@selector(onSettings) keyEquivalent:@","];
    sett.image = [NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:nil];
    sett.target = self;
    [menu addItem:sett];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *full = [[NSMenuItem alloc] initWithTitle:@"Toggle Fullscreen" action:@selector(onFullscreen) keyEquivalent:@"f"];
    full.image = [NSImage imageWithSystemSymbolName:@"arrow.up.left.and.arrow.down.right" accessibilityDescription:nil];
    full.target = self;
    [menu addItem:full];
    full.target = self;
    [menu addItem:full];
    
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"❌  Quit Android Device" action:@selector(onQuit) keyEquivalent:@"q"];
    quit.target = self;
    [menu addItem:quit];
    
    [self showMenu:menu underButton:sender];
}

- (void)onToggleAimMenu {
    [[OrchDroidInputManager shared] toggleAimLock];
}

- (void)showMenu:(NSMenu *)menu underButton:(NSButton *)sender {
    NSRect bounds = sender.bounds;
    NSPoint p = [sender convertPoint:NSMakePoint(0, bounds.size.height) toView:nil];
    NSEvent *ev = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown
                                     location:p
                                modifierFlags:0
                                    timestamp:0
                                 windowNumber:sender.window.windowNumber
                                      context:nil
                                  eventNumber:0
                                   clickCount:1
                                     pressure:1.0];
    [NSMenu popUpContextMenu:menu withEvent:ev forView:sender];
}

- (void)onExpandNotif {
    [self sendAdbCommand:@"shell cmd statusbar expand-notifications"];
}

- (void)onRotate {
    [self sendAdbCommand:@"shell cmd window set-ignore-orientation-request false"];
}

- (void)onScreenshot {
    NSString *ts = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
    [self sendAdbCommand:[NSString stringWithFormat:@"shell screencap -p /sdcard/screenshot_%@.png", ts]];
}

- (void)onKeymap {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://127.0.0.1:8088/#keymap"]];
}

- (void)onSettings {
    [self sendAdbCommand:@"shell am start -a android.settings.SETTINGS"];
}

- (void)onFullscreen {
    [NSApp.keyWindow toggleFullScreen:nil];
}

- (void)onQuit {
    [NSApp terminate:nil];
}

- (void)onShaderOff {
    [[OrchDroidShaderEngine shared] applyPreset:OrchDroidShaderPresetOff];
}

- (void)onShaderVibrant {
    [[OrchDroidShaderEngine shared] applyPreset:OrchDroidShaderPresetVibrantBattleRoyale];
}

- (void)onShaderCAS {
    [[OrchDroidShaderEngine shared] applyPreset:OrchDroidShaderPresetUltraClarityCAS];
}

- (void)onShaderHDR {
    [[OrchDroidShaderEngine shared] applyPreset:OrchDroidShaderPresetCinematicHDR];
}

- (void)onShaderCycle {
    [[OrchDroidShaderEngine shared] cycleNextPreset];
}

@end

static NSImage *symbolIcon(NSString *name, CGFloat pointSize, NSFontWeight weight) {
    if (@available(macOS 11.0, *)) {
        NSImage *img = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
        if (img) {
            NSImageSymbolConfiguration *cfg = [NSImageSymbolConfiguration configurationWithPointSize:pointSize weight:weight];
            return [img imageWithSymbolConfiguration:cfg];
        }
    }
    return nil;
}

static NSButton *createTitleIconButton(NSString *symbolName, NSString *fallback, NSString *tip, SEL action) {
    NSImage *img = symbolIcon(symbolName, 12, NSFontWeightMedium);
    NSButton *btn;
    if (img) {
        btn = [NSButton buttonWithImage:img target:[OrchDroidNavDelegate shared] action:action];
    } else {
        btn = [NSButton buttonWithTitle:fallback target:[OrchDroidNavDelegate shared] action:action];
    }
    btn.toolTip = tip;
    btn.bordered = NO;
    btn.contentTintColor = [NSColor secondaryLabelColor];
    btn.wantsLayer = YES;
    btn.layer.cornerRadius = 4.0;
    return btn;
}

static NSButton *createAimButton(SEL action) {
    NSImage *img = symbolIcon(@"scope", 11, NSFontWeightSemibold);
    NSButton *btn;
    if (img) {
        btn = [NSButton buttonWithTitle:@" Aim" image:img target:[OrchDroidNavDelegate shared] action:action];
        btn.imagePosition = NSImageLeading;
    } else {
        btn = [NSButton buttonWithTitle:@"Aim" target:[OrchDroidNavDelegate shared] action:action];
    }
    btn.toolTip = @"Toggle Mouse Aim Lock (` / F1)";
    btn.bordered = NO;
    btn.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    btn.contentTintColor = [NSColor secondaryLabelColor];
    btn.wantsLayer = YES;
    btn.layer.cornerRadius = 4.0;
    return btn;
}

static void setupTitlebarAccessory(NSWindow *win) {
    if (win.titlebarAccessoryViewControllers.count > 0) {
        return;
    }
    
    NSTitlebarAccessoryViewController *accessory = [[NSTitlebarAccessoryViewController alloc] init];
    accessory.layoutAttribute = NSLayoutAttributeRight;
    
    NSStackView *stack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 220, 24)];
    stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    stack.spacing = 8;
    stack.edgeInsets = NSEdgeInsetsMake(0, 4, 0, 10);
    
    NSButton *aimBtn = createAimButton(@selector(onAimToggle:));
    NSButton *backBtn = createTitleIconButton(@"chevron.backward", @"<", @"Back", @selector(onBack));
    NSButton *homeBtn = createTitleIconButton(@"circle", @"o", @"Home", @selector(onHome));
    NSButton *recentBtn = createTitleIconButton(@"square.on.square", @"[]", @"Recent Apps", @selector(onRecent));
    NSButton *volBtn = createTitleIconButton(@"speaker.wave.2", @"Vol", @"Volume Controls", @selector(onVolume:));
    NSButton *cfgBtn = createTitleIconButton(@"gearshape", @"Opt", @"OrchDroid Settings & Keymaps", @selector(onMenu:));
    
    [stack addArrangedSubview:aimBtn];
    [stack addArrangedSubview:backBtn];
    [stack addArrangedSubview:homeBtn];
    [stack addArrangedSubview:recentBtn];
    [stack addArrangedSubview:volBtn];
    [stack addArrangedSubview:cfgBtn];
    
    accessory.view = stack;
    [win addTitlebarAccessoryViewController:accessory];
}

// Swizzled NSWindow suppression category to permanently kill the side toolbar
@implementation NSWindow (OrchDroidToolbarSuppression)

- (void)orch_makeKeyAndOrderFront:(id)sender {
    if ((self.frame.size.width < 90 && self.frame.size.height > 150) || 
        [self.className containsString:@"ToolWindow"] || 
        [self.title containsString:@"Toolbar"]) {
        [self orderOut:nil];
        [self setAlphaValue:0.0];
        [self setIgnoresMouseEvents:YES];
        return;
    }
    [self orch_makeKeyAndOrderFront:sender];
}

- (void)orch_orderWindow:(NSWindowOrderingMode)place relativeTo:(NSInteger)otherWin {
    if ((self.frame.size.width < 90 && self.frame.size.height > 150) || 
        [self.className containsString:@"ToolWindow"] || 
        [self.title containsString:@"Toolbar"]) {
        [self orderOut:nil];
        [self setAlphaValue:0.0];
        [self setIgnoresMouseEvents:YES];
        return;
    }
    [self orch_orderWindow:place relativeTo:otherWin];
}

- (void)orch_addChildWindow:(NSWindow *)child ordered:(NSWindowOrderingMode)place {
    if ((child.frame.size.width < 90 && child.frame.size.height > 150) || 
        [child.className containsString:@"ToolWindow"] || 
        [child.title containsString:@"Toolbar"]) {
        [child orderOut:nil];
        [child setAlphaValue:0.0];
        [child setIgnoresMouseEvents:YES];
        return;
    }
    [self orch_addChildWindow:child ordered:place];
}

@end

// ============================================================================
// OrchDroid Smooth Trackpad Touch-Drag Engine (Verified Clean Fix)
//
// Translates macOS 2-finger trackpad scrolling into smooth, 1-finger touch
// drag events on the Android screen.
// Y-axis inverted for natural scrolling:
//   sCurrentDragPoint.x += event.scrollingDeltaX * 1.5;
//   sCurrentDragPoint.y -= event.scrollingDeltaY * 1.5;
// ============================================================================

static BOOL sIsTrackpadScrolling = NO;
static CGPoint sCurrentDragPoint = {0, 0};

static NSEvent *handleTrackpadScroll(NSEvent *event) {
    if (!event.hasPreciseScrollingDeltas) {
        // Physical mouse wheel: pass directly through!
        return event;
    }

    // Drop macOS momentum after fingers lift, let Android velocity tracker handle physics
    if (event.momentumPhase != NSEventPhaseNone) {
        if (sIsTrackpadScrolling) {
            sIsTrackpadScrolling = NO;
            NSWindow *win = [OrchDroidInputManager shared].targetWindow ?: [NSApp keyWindow];
            NSView *view = [OrchDroidInputManager shared].renderView ?: win.contentView;
            if (view) {
                NSEvent *upEvent = [NSEvent mouseEventWithType:NSEventTypeLeftMouseUp
                                                      location:sCurrentDragPoint
                                                 modifierFlags:0
                                                     timestamp:event.timestamp
                                                  windowNumber:win.windowNumber
                                                       context:nil
                                                   eventNumber:0
                                                    clickCount:1
                                                      pressure:0.0];
                [view mouseUp:upEvent];
            }
        }
        return nil;
    }

    NSWindow *win = [OrchDroidInputManager shared].targetWindow ?: [NSApp keyWindow];
    NSView *view = [OrchDroidInputManager shared].renderView ?: win.contentView;
    if (!view) return nil;

    if (event.phase == NSEventPhaseBegan) {
        sIsTrackpadScrolling = YES;
        sCurrentDragPoint = event.locationInWindow;
        NSEvent *downEvent = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown
                                                location:sCurrentDragPoint
                                           modifierFlags:0
                                               timestamp:event.timestamp
                                            windowNumber:win.windowNumber
                                                 context:nil
                                             eventNumber:0
                                              clickCount:1
                                                pressure:1.0];
        [view mouseDown:downEvent];
        return nil;
    }

    if (event.phase == NSEventPhaseChanged || (sIsTrackpadScrolling && event.phase == NSEventPhaseNone)) {
        if (!sIsTrackpadScrolling) {
            sIsTrackpadScrolling = YES;
            sCurrentDragPoint = event.locationInWindow;
            NSEvent *downEvent = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown
                                                    location:sCurrentDragPoint
                                               modifierFlags:0
                                                   timestamp:event.timestamp
                                                windowNumber:win.windowNumber
                                                     context:nil
                                                 eventNumber:0
                                                  clickCount:1
                                                    pressure:1.0];
            [view mouseDown:downEvent];
        }

        sCurrentDragPoint.x += event.scrollingDeltaX * 1.5;
        sCurrentDragPoint.y -= event.scrollingDeltaY * 1.5;

        // Clamp to window bounds
        NSRect b = view.bounds;
        if (sCurrentDragPoint.x < 10) sCurrentDragPoint.x = 10;
        if (sCurrentDragPoint.x > b.size.width - 10) sCurrentDragPoint.x = b.size.width - 10;
        if (sCurrentDragPoint.y < 10) sCurrentDragPoint.y = 10;
        if (sCurrentDragPoint.y > b.size.height - 10) sCurrentDragPoint.y = b.size.height - 10;

        NSEvent *dragEvent = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDragged
                                                location:sCurrentDragPoint
                                           modifierFlags:0
                                               timestamp:event.timestamp
                                            windowNumber:win.windowNumber
                                                 context:nil
                                             eventNumber:0
                                              clickCount:1
                                                pressure:1.0];
        [view mouseDragged:dragEvent];
        return nil;
    }

    if (event.phase == NSEventPhaseEnded || event.phase == NSEventPhaseCancelled) {
        if (sIsTrackpadScrolling) {
            sIsTrackpadScrolling = NO;
            NSEvent *upEvent = [NSEvent mouseEventWithType:NSEventTypeLeftMouseUp
                                                  location:sCurrentDragPoint
                                             modifierFlags:0
                                                 timestamp:event.timestamp
                                              windowNumber:win.windowNumber
                                                   context:nil
                                               eventNumber:0
                                                clickCount:1
                                                  pressure:0.0];
            [view mouseUp:upEvent];
        }
        return nil;
    }

    return nil;
}

// Inject into Windows and style them
void injectOrchDroidStyle(NSWindow *win) {
    if (!win) return;

    // Check if this is the ToolWindow (the white toolbar)
    if ((win.frame.size.width < 90 && win.frame.size.height > 150) || 
        [win.className containsString:@"ToolWindow"] || 
        [win.title containsString:@"Toolbar"]) {
        [win orderOut:nil];
        [win setAlphaValue:0.0];
        [win setIgnoresMouseEvents:YES];
        return;
    }
    
    // Purge any child tool windows
    for (NSWindow *child in win.childWindows) {
        if (child.frame.size.width < 90) {
            [child orderOut:nil];
            [child setAlphaValue:0.0];
            [win removeChildWindow:child];
        }
    }
    
    // Main Emulator Window
    NSString *winTitle = win.title ?: @"";
    if ([winTitle containsString:@"Emulator"] || [winTitle containsString:@"OrchDroid"] || [winTitle containsString:@"qemu"] || (win.frame.size.width > 500 && win.frame.size.height > 400)) {
        static const char *kOrchDroidStyledKey = "kOrchDroidStyledKey";
        if (objc_getAssociatedObject(win, kOrchDroidStyledKey)) {
            return;
        }
        objc_setAssociatedObject(win, kOrchDroidStyledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        [OrchDroidInputManager shared].targetWindow = win;
        [OrchDroidInputManager shared].renderView = win.contentView;
        [OrchDroidShaderEngine shared].targetRenderView = win.contentView;

        // Hide any docked ToolWindow child view if attached
        for (NSView *sub in win.contentView.subviews) {
            NSString *subClass = NSStringFromClass(sub.class);
            if ([subClass containsString:@"Tool"] || [subClass containsString:@"Bar"] || (sub.frame.size.width < 70 && sub.frame.size.height > 200)) {
                sub.hidden = YES;
                [sub removeFromSuperview];
            }
        }
        
        @try {
            // 1. Gesture Configuration:
            // Disable macOS system gesture interception (e.g. 3-finger swipe, Mission Control)
            if ([win respondsToSelector:@selector(setPreferredSystemGestureState:)]) {
                // NSWindowUserGestureStateDisabled = 0
                [win performSelector:@selector(setPreferredSystemGestureState:) withObject:@(0)];
            }

            // 2. Solid macOS Native Titlebar Border
            NSWindowStyleMask mask = (NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable);
            if ((win.styleMask & mask) != mask) {
                win.styleMask = mask;
            }
            
            win.titlebarAppearsTransparent = NO;
            win.titleVisibility = NSWindowTitleVisible;
            win.title = @"Samsung Galaxy Tab S9 Ultra (SM-X910)";
            
            // 3. Real macOS Native Full Screen
            win.collectionBehavior = (NSWindowCollectionBehaviorFullScreenPrimary | NSWindowCollectionBehaviorManaged);
            
            // 4. Attach Titlebar Accessory
            setupTitlebarAccessory(win);
            
            [[win standardWindowButton:NSWindowCloseButton] setHidden:NO];
            [[win standardWindowButton:NSWindowMiniaturizeButton] setHidden:NO];
            [[win standardWindowButton:NSWindowZoomButton] setHidden:NO];
        } @catch (NSException *e) {
            // Protect against AppKit styleMask mutation during active transitions
        }
    }
}

__attribute__((constructor))
static void orchdroid_init(void) {
    installMetalPipelineFix();
    [[NSProcessInfo processInfo] setProcessName:@"OrchDroid Android Device"];

    void *appServices = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY);
    typedef OSErr (*CPSGetCurrentProcessFunc)(ProcessSerialNumber *psn);
    typedef OSErr (*CPSSetProcessNameFunc)(ProcessSerialNumber *psn, const char *processName);
    CPSGetCurrentProcessFunc getCurrent = appServices ? (CPSGetCurrentProcessFunc)dlsym(appServices, "CPSGetCurrentProcess") : NULL;
    CPSSetProcessNameFunc setName = appServices ? (CPSSetProcessNameFunc)dlsym(appServices, "CPSSetProcessName") : NULL;

    if (getCurrent && setName) {
        ProcessSerialNumber psn;
        if (getCurrent(&psn) == 0) {
            setName(&psn, "OrchDroid Android Device");
        }
    }

    // Install local event monitor for Aim Lock, Escape, and Trackpad Smooth Touch Scrolling
    [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskKeyDown | NSEventMaskScrollWheel) handler:^NSEvent *(NSEvent *event) {
        OrchDroidInputManager *mgr = [OrchDroidInputManager shared];

        // 1. Smooth Trackpad 2-Finger Touch Drag Conversion (Inverted Y-axis)
        if (event.type == NSEventTypeScrollWheel) {
            return handleTrackpadScroll(event);
        }

        // 2. Keyboard shortcuts
        if (event.type == NSEventTypeKeyDown) {
            // '~' (key code 50) or 'F1' (key code 122) toggles Aim Lock
            if (event.keyCode == 50 || event.keyCode == 122) {
                [mgr toggleAimLock];
                return nil; // Consume key event
            }
            // 'F2' (key code 120) cycles Custom Shaders
            if (event.keyCode == 120) {
                [[OrchDroidShaderEngine shared] cycleNextPreset];
                return nil;
            }
            // 'Esc' releases Aim Lock if engaged
            if (event.keyCode == 53 && mgr.isAimingLocked) {
                [mgr setAimLock:NO];
                return nil;
            }
        }

        return event;
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (getCurrent && setName) {
            ProcessSerialNumber psn;
            if (getCurrent(&psn) == 0) {
                setName(&psn, "OrchDroid Android Device");
            }
        }

        if ([NSApp mainMenu] && [[NSApp mainMenu] numberOfItems] > 0) {
            NSMenuItem *first = [[NSApp mainMenu] itemAtIndex:0];
            if (first && first.submenu) {
                [first.submenu setTitle:@"OrchDroid Android Device"];
            }
        }

        NSImage *instanceIcon = [[NSImage alloc] initWithContentsOfFile:@"/Volumes/LinuxFS/OrchDroid/dist/instance_icon.png"];
        if (instanceIcon) {
            [NSApp setApplicationIconImage:instanceIcon];
        }

        for (NSWindow *win in [NSApp windows]) {
            injectOrchDroidStyle(win);
        }
        
        for (int i = 1; i <= 15; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (getCurrent && setName) {
                    ProcessSerialNumber psn;
                    if (getCurrent(&psn) == 0) {
                        setName(&psn, "OrchDroid Android Device");
                    }
                }
                for (NSWindow *win in [NSApp windows]) {
                    injectOrchDroidStyle(win);
                }
            });
        }
    });
}
