//
//  AppDelegate.m
//  Ampere
//
//  Created by DF on 1/9/25.
//

#import "AppDelegate.h"
#include <objc/runtime.h>

NSUserDefaults *preferences;

BOOL containsKey(NSString *key) {
    return [preferences.dictionaryRepresentation.allKeys containsObject:key];
}

@interface AppDelegate ()
@property (strong) IBOutlet NSWindow *window;
@end

@implementation AppDelegate
@synthesize percentageLabel;
- (void)awakeFromNib {
    if (!preferences) preferences = [NSUserDefaults standardUserDefaults];
    [self loadPreferences];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateBatteryInfo) name:kPowerConditionChangedNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateBatteryInfo) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(updateBatteryInfo) name:@"AMPUpdateBatteryView" object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleAutoLaunch:) name:@"AMPSetAutoLaunch" object:nil];
    
    AMPPowerCondition *condition = [[AMPPowerCondition alloc] init];
    [condition startMonitoringCondition];
    
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [_statusItem.button setFont:[NSFont systemFontOfSize:12 weight:NSFontWeightMedium]];
    _statusItem.button.imageScaling = NSImageScaleProportionallyDown;
    [(NSButtonCell *)_statusItem.button.cell setHighlightsBy:NSNoCellMask];
    _statusItem.menu = self.batteryMenu;
    
    percentageLabel = [[NSTextField alloc] initWithFrame:CGRectZero];
    percentageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    percentageLabel.bezeled = NO;
    percentageLabel.editable = NO;
    percentageLabel.drawsBackground = NO;
    percentageLabel.backgroundColor = [NSColor clearColor];
    percentageLabel.maximumNumberOfLines = 1;
    // percentageLabel.alignment = NSTextAlignmentCenter;
    percentageLabel.cell = [AMPTextFieldCell new];
    
    [_statusItem.button addSubview:percentageLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [percentageLabel.leadingAnchor constraintEqualToAnchor:_statusItem.button.leadingAnchor],
    ]];
    
    self.labelHeightConstraint = [percentageLabel.heightAnchor constraintEqualToConstant:14];
    self.labelHeightConstraint.active = YES;
    
    self.labelCenterConstraint = [percentageLabel.centerYAnchor constraintEqualToAnchor:_statusItem.button.centerYAnchor];
    self.labelCenterConstraint.active = YES;
    
    self.labelTrailingConstraint = [percentageLabel.trailingAnchor constraintEqualToAnchor:_statusItem.button.trailingAnchor];
    self.labelTrailingConstraint.active = YES;
    
    [self updateBatteryInfo];
}
- (void)loadPreferences {
    
    if (!containsKey(@"batteryStyle")) {
        [preferences setObject:@(0) forKey:@"batteryStyle"];
    }
    
    if (!containsKey(@"fontSize")) {
        [preferences setObject:@(11) forKey:@"fontSize"];
    }
    
    if (!containsKey(@"useFahrenheit")) {
        [preferences setObject:@(YES) forKey:@"useFahrenheit"];
    }
    
    if (!containsKey(@"useBatteryColors")) {
        [preferences setObject:@(YES) forKey:@"useBatteryColors"];
    }
    
    if (!containsKey(@"showPercentage")) {
        [preferences setObject:@(YES) forKey:@"showPercentage"];
    }
    
    if (!containsKey(@"autoLaunch")) {
        [preferences setObject:@(NO) forKey:@"autoLaunch"];
    }
    
    if (!containsKey(@"normalColor")) {
        [preferences setObject:@"#FFFFFFFF" forKey:@"normalColor"];
    }
    
    if (!containsKey(@"chargingColor")) {
        [preferences setObject:@"#28cd41FF" forKey:@"chargingColor"];
    }
    
    if (!containsKey(@"criticalColor")) {
        [preferences setObject:@"#ff3b30FF" forKey:@"criticalColor"];
    }
    
    if (!containsKey(@"lowPowerColor")) {
        [preferences setObject:@"#FEDD11FF" forKey:@"lowPowerColor"];
    }
    
    if (!containsKey(@"textColor")) {
        [preferences setObject:@"#00000099" forKey:@"textColor"];
    }
    
    [preferences synchronize];
}
- (NSImage *)image:(NSImage *)image tintedWithColor:(NSColor *)tint {
    if (tint) {
        [image lockFocus];
        [tint set];
        NSRect imageRect = {NSZeroPoint, [image size]};
        NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceAtop);
        [image unlockFocus];
    }
    return image;
}
- (void)updateBatteryInfo {
    NSLog(@"Updating Battery");
    
    kern_return_t result;
    mach_port_t port = 0;
    io_registry_entry_t entry = IOServiceGetMatchingService(port, IOServiceMatching("IOPMPowerSource"));
    CFMutableDictionaryRef rawProperties = NULL;
    result = IORegistryEntryCreateCFProperties(entry, &rawProperties, NULL, 0);
    NSDictionary *properties = (__bridge_transfer NSDictionary *)rawProperties;
    
    CGFloat health = ([[properties objectForKey:@"NominalChargeCapacity"] floatValue] / [[properties objectForKey:@"DesignCapacity"] floatValue]) * 100;
    
    BOOL useFahrenheit = [[preferences objectForKey:@"useFahrenheit"] boolValue];
    
    double temperature;
    
    if (useFahrenheit) {
        temperature = (([[properties objectForKey:@"Temperature"] doubleValue] / 100) * (9/5)) + 32;
    } else {
        temperature = ([[properties objectForKey:@"Temperature"] doubleValue] / 100);
    }
    
    [self.cycleLabel setStringValue:[[properties objectForKey:@"CycleCount"] stringValue]];
    [self.healthLabel setStringValue:[NSString stringWithFormat:@"%.f%%", health]];
    [self.temperatureLabel setStringValue:[NSString stringWithFormat:@"%.fº", temperature]];
    [self.amperageLabel setStringValue:[NSString stringWithFormat:@"%.2fA", ([[properties objectForKey:@"Amperage"] doubleValue]) / 1000]];
    [self.voltageLabel setStringValue:[NSString stringWithFormat:@"%.2fV", ([[properties objectForKey:@"Voltage"] doubleValue]) / 1000]];
    [self.powerLabel setStringValue:[NSString stringWithFormat:@"%.fW", ([[properties objectForKey:@"Amperage"] doubleValue] / 1000) * ([[properties objectForKey:@"Voltage"] doubleValue] / 1000)]];
    
    BOOL charging = [[properties objectForKey:@"ExternalConnected"] boolValue];
    
    double capacityRemaining = [[properties objectForKey:@"CurrentCapacity"] doubleValue];
    double maxCapacity = [[properties objectForKey:@"MaxCapacity"] doubleValue];
    int percentage = (int)((capacityRemaining / maxCapacity) * 100);
    NSString *percentageString = [NSString stringWithFormat:@"%d", percentage];
    
    NSInteger batteryStyle = [[preferences objectForKey:@"batteryStyle"] integerValue];
    
    switch (batteryStyle) {
        default:
        case 0: {
            [_statusItem setLength:32];
            break;
        }
        case 1: {
            [_statusItem setLength:26];
            break;
        }
        case 2: {
            [_statusItem setLength:32];
            break;
        }
    }
    
    [_statusItem.button setImage:[self batteryFillImageWithPercentage:(capacityRemaining / maxCapacity) charging:charging style:batteryStyle]];

    BOOL useBatteryColors = [[preferences objectForKey:@"useBatteryColors"] boolValue];
    
    BOOL showPercentage = [[preferences objectForKey:@"showPercentage"] boolValue];
    
    NSInteger fontSize = [[preferences objectForKey:@"fontSize"] integerValue];
    
    [percentageLabel setHidden:(!showPercentage || batteryStyle == 1)];
    percentageLabel.font = [NSFont systemFontOfSize:fontSize weight:NSFontWeightBold];
    
    [percentageLabel setStringValue:percentageString];
    percentageLabel.textColor = (useBatteryColors) ? [self colorFromHexString:[preferences objectForKey:@"textColor"]] : [NSColor colorWithWhite:0 alpha:0.6];
    
    self.labelHeightConstraint.constant = (fontSize >= 13) ? 16 : 14;
    self.labelCenterConstraint.constant = (fontSize >= 13) ? 0 : 0;
    self.labelTrailingConstraint.constant = ((fontSize > 12) || percentage != 100) ? -3 : -5;
    [percentageLabel layout];
    
    [self.capacityLabel setStringValue:[NSString stringWithFormat:@"%@%%", percentageString]];
    
    if (charging) {
        [self.sourceLabel setStringValue:@"Power Adapter"];
    } else {
        [self.sourceLabel setStringValue:@"Battery"];
    }
}
- (NSColor *)colorFromHexString:(NSString *)hexString {
    NSString *cleanHexString = [hexString stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"#"]];
        
    if (cleanHexString.length != 6 && cleanHexString.length != 8) {
        NSLog(@"Invalid hex string: %@", hexString);
        return nil;
    }
        
    unsigned int rgbValue = 0;
    [[NSScanner scannerWithString:cleanHexString] scanHexInt:&rgbValue];
        
    CGFloat red, green, blue, alpha;
    if (cleanHexString.length == 6) {
        red = ((rgbValue >> 16) & 0xFF) / 255.0;
        green = ((rgbValue >> 8) & 0xFF) / 255.0;
        blue = (rgbValue & 0xFF) / 255.0;
        alpha = 1.0;
    } else {
        red = ((rgbValue >> 24) & 0xFF) / 255.0;
        green = ((rgbValue >> 16) & 0xFF) / 255.0;
        blue = ((rgbValue >> 8) & 0xFF) / 255.0;
        alpha = (rgbValue & 0xFF) / 255.0;
    }
    
    return [NSColor colorWithRed:red green:green blue:blue alpha:alpha];
}
- (NSImage *)batteryFillImageWithPercentage:(CGFloat)percentage charging:(BOOL)charging style:(NSInteger)style {
    
    BOOL useBatteryColors = [[preferences objectForKey:@"useBatteryColors"] boolValue];
    
    NSImage *finalBatteryImage;
    
    switch (style) {
        default:
        case 0: {
            NSImage *batteryImage = [NSImage imageNamed:@"battery"];
            NSImage *croppedBatteryImage;
            if (charging) {
                croppedBatteryImage = [self image:[self cropImage:batteryImage toWidthPercentage:percentage] tintedWithColor:(useBatteryColors) ? [self colorFromHexString:[preferences objectForKey:@"chargingColor"]] : [NSColor systemGreenColor]];
            } else {
                croppedBatteryImage = [self image:[self cropImage:batteryImage toWidthPercentage:percentage] tintedWithColor:(useBatteryColors) ? [self colorFromHexString:[preferences objectForKey:@"normalColor"]] : [NSColor whiteColor]];
            }
            
            if ((NSInteger)(percentage * 100) <= 10) {
                croppedBatteryImage = [self image:[self cropImage:batteryImage toWidthPercentage:percentage] tintedWithColor:(useBatteryColors) ? [self colorFromHexString:[preferences objectForKey:@"criticalColor"]] : [NSColor systemRedColor]];
            }
            
            if ([[NSProcessInfo processInfo] isLowPowerModeEnabled]) {
                croppedBatteryImage = [self image:[self cropImage:batteryImage toWidthPercentage:percentage] tintedWithColor:(useBatteryColors) ? [self colorFromHexString:[preferences objectForKey:@"lowPowerColor"]] : [self colorFromHexString:@"FEDD11FF"]];
            }
            
            finalBatteryImage = [self overlayImage:[NSImage imageNamed:@"battery"] withImage:croppedBatteryImage];
            break;
        }
        case 1: {
            NSImage *batteryImage = [NSImage imageNamed:@"battery-vertical"];
            NSImage *croppedBatteryImage;
            if (charging) {
                croppedBatteryImage = [self image:[self cropImage:batteryImage toHeightPercentage:percentage] tintedWithColor:(useBatteryColors) ? [self colorFromHexString:[preferences objectForKey:@"chargingColor"]] : [NSColor systemGreenColor]];
            } else {
                croppedBatteryImage = [self image:[self cropImage:batteryImage toHeightPercentage:percentage] tintedWithColor:(useBatteryColors) ? [self colorFromHexString:[preferences objectForKey:@"normalColor"]] : [NSColor whiteColor]];
            }
            
            if ((NSInteger)(percentage * 100) <= 10) {
                croppedBatteryImage = [self image:[self cropImage:batteryImage toHeightPercentage:percentage] tintedWithColor:(useBatteryColors) ? [self colorFromHexString:[preferences objectForKey:@"criticalColor"]] : [NSColor systemRedColor]];
            }
            
            if ([[NSProcessInfo processInfo] isLowPowerModeEnabled]) {
                croppedBatteryImage = [self image:[self cropImage:batteryImage toHeightPercentage:percentage] tintedWithColor:(useBatteryColors) ? [self colorFromHexString:[preferences objectForKey:@"lowPowerColor"]] : [self colorFromHexString:@"FEDD11FF"]];
            }
            
            finalBatteryImage = [self overlayImage:[NSImage imageNamed:@"battery-vertical"] withImage:croppedBatteryImage];
            break;
        }
        case 2: {
            NSImage *batteryImage = [NSImage imageNamed:@"battery"];
            NSImage *croppedBatteryImage = [self image:[self cropImage:batteryImage toWidthPercentage:percentage] tintedWithColor:[NSColor whiteColor]];
            NSImage *outlineImage;
            if (charging) {
                outlineImage = [self image:[NSImage imageNamed:@"battery-outline"] tintedWithColor:(useBatteryColors) ? [self colorFromHexString:[preferences objectForKey:@"chargingColor"]] : [NSColor systemGreenColor]];
            } else {
                outlineImage = [self image:[NSImage imageNamed:@"battery-outline"] tintedWithColor:(useBatteryColors) ? [self colorFromHexString:[preferences objectForKey:@"normalColor"]] : [NSColor whiteColor]];
            }
            
            if ((NSInteger)(percentage * 100) <= 10) {
                outlineImage = [self image:[NSImage imageNamed:@"battery-outline"] tintedWithColor:(useBatteryColors) ? [self colorFromHexString:[preferences objectForKey:@"criticalColor"]] : [NSColor systemRedColor]];
            }
            
            if ([[NSProcessInfo processInfo] isLowPowerModeEnabled]) {
                outlineImage = [self image:[NSImage imageNamed:@"battery-outline"] tintedWithColor:(useBatteryColors) ? [self colorFromHexString:[preferences objectForKey:@"lowPowerColor"]] : [self colorFromHexString:@"FEDD11FF"]];
            }
            finalBatteryImage = [self overlayImage:croppedBatteryImage withImage:outlineImage];
            break;
        }
    }
    
    return finalBatteryImage;
}
- (NSImage *)cropImage:(NSImage *)image toWidthPercentage:(CGFloat)percentage {
    if (!image || percentage <= 0.0 || percentage > 1.0) {
        return nil;
    }
    NSSize originalSize = [image size];
    
    CGFloat croppedWidth = originalSize.width * percentage;
    CGFloat croppedHeight = originalSize.height;
    
    NSRect sourceRect = NSMakeRect(0, 0, croppedWidth, croppedHeight);
    
    NSImage *croppedImage = [[NSImage alloc] initWithSize:NSMakeSize(originalSize.width, croppedHeight)];
    

    [croppedImage lockFocus];
    [image drawInRect:NSMakeRect(0, 0, croppedWidth, croppedHeight)
             fromRect:sourceRect
            operation:NSCompositingOperationCopy
             fraction:1];
    [croppedImage unlockFocus];
    
    return croppedImage;
}
- (NSImage *)cropImage:(NSImage *)image toHeightPercentage:(CGFloat)percentage {
    if (!image || percentage <= 0.0 || percentage > 1.0) {
        return nil;
    }
    NSSize originalSize = [image size];
    
    CGFloat croppedWidth = originalSize.width;
    CGFloat croppedHeight = originalSize.height * percentage;
    
    NSRect sourceRect = NSMakeRect(0, 0, croppedWidth, croppedHeight);
    
    NSImage *croppedImage = [[NSImage alloc] initWithSize:NSMakeSize(croppedWidth, originalSize.height)];
    

    [croppedImage lockFocus];
    [image drawInRect:NSMakeRect(0, 0, croppedWidth, croppedHeight)
             fromRect:sourceRect
            operation:NSCompositingOperationCopy
             fraction:1];
    [croppedImage unlockFocus];
    
    return croppedImage;
}
- (NSImage *)overlayImage:(NSImage *)image1 withImage:(NSImage *)image2 {
    if (!image1 || !image2) {
        return nil;
    }
    NSSize finalSize = [image1 size];
    NSImage *resultImage = [[NSImage alloc] initWithSize:finalSize];
    [resultImage lockFocus];
    
    [image1 drawInRect:NSMakeRect(0, 0, finalSize.width, finalSize.height)
              fromRect:NSZeroRect
             operation:NSCompositingOperationSourceOver
              fraction:0.6];
    
    [image2 drawInRect:NSMakeRect(0, 0, finalSize.width, finalSize.height)
              fromRect:NSZeroRect
             operation:NSCompositingOperationSourceOver
              fraction:1.0];
    [resultImage unlockFocus];
    
    return resultImage;
}
- (IBAction)quit:(NSMenuItem *)sender {
    [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
}
- (IBAction)showSettings:(id)sender {
    
    // [[NSWorkspace sharedWorkspace] openApplicationAtURL:configuration:completionHandler:] doesn't work but launchApplication: does? 
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSURL *helperURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"com.mtac.ampere.settings"];
    [[NSWorkspace sharedWorkspace] launchApplication:helperURL.path];
    #pragma clang diagnostic pop
}
- (void)toggleAutoLaunch:(NSNotification *)notification {
    NSDictionary *infoDict = notification.userInfo;
    NSLog(@"%@", infoDict);
    BOOL autoLaunch = [[infoDict objectForKey:@"enabled"] boolValue];
    [preferences setObject:@(autoLaunch) forKey:@"autoLaunch"];
    NSError *err;
    if (@available(macOS 13.0, *)) {
        SMAppService *mainService = [SMAppService mainAppService];
        
        if (autoLaunch == NSControlStateValueOn) {
            [mainService registerAndReturnError:&err];
        } else if (autoLaunch == NSControlStateValueOff) {
            [mainService unregisterAndReturnError:&err];
        }
    } else {
        SMLoginItemSetEnabled((__bridge CFStringRef)@"com.mtac.ampere", autoLaunch);
    }
    if (err) {
        NSLog(@"Error -> %@", err);
    }
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSColor.ignoresAlpha = NO;
}
- (void)applicationWillTerminate:(NSNotification *)aNotification {
}
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}
@end
