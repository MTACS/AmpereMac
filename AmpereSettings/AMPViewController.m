//
//  AMPViewController.m
//  AmpereSettings
//
//  Created by DF on 1/19/25.
//

#import "AMPViewController.h"
#import <ServiceManagement/ServiceManagement.h>

NSUserDefaults *defaults;

@implementation AMPViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.fontMenu = [self fontSizeMenu];
    self.fontButton.menu = self.fontMenu;
    if (!defaults) defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.mtac.ampere"];
    [self.segmentControl setSelectedSegment:0];
    [self loadPreferences];
}
- (void)loadPreferences {
    BOOL temperatureUnit = [[defaults objectForKey:@"useFahrenheit"] boolValue];
    
    [[self.temperatureMenu.itemArray objectAtIndex:(temperatureUnit) ? 0 : 1] setState:NSControlStateValueOn];
    
    [self.temperatureButton setTitle:(temperatureUnit) ? @"Fahrenheit" : @"Celsius"];
    
    NSInteger batteryStyle = [[defaults objectForKey:@"batteryStyle"] integerValue];
    [[self.styleMenu.itemArray objectAtIndex:batteryStyle] setState:NSControlStateValueOn];
    
    NSString *styleType;
    switch (batteryStyle) {
        default:
        case 0:
            styleType = @"Horizontal";
            break;
        case 1:
            styleType = @"Vertical";
            break;
        case 2:
            styleType = @"Outline";
            break;
    }
    [self.styleButton setTitle:styleType];
    
    NSInteger fontSize = [[defaults objectForKey:@"fontSize"] integerValue];
    [self.fontButton setTitle:[NSString stringWithFormat:@"Size: %ld", fontSize]];
    [[self.fontMenu.itemArray objectAtIndex:fontSize - 9] setState:NSControlStateValueOn];
    
    self.loginSwitch.checked = [[defaults objectForKey:@"autoLaunch"] boolValue];
    
    BOOL useBatteryColors = [[defaults objectForKey:@"useBatteryColors"] boolValue];
    
    [self.batteryColorSwitch setChecked:useBatteryColors];
    
    BOOL showPercentage = [[defaults objectForKey:@"showPercentage"] boolValue];
    
    [self.percentageSwitch setChecked:showPercentage];
    
    self.normalColorWell.color = [self colorFromHexString:[defaults objectForKey:@"normalColor"]];
    self.chargingColorWell.color = [self colorFromHexString:[defaults objectForKey:@"chargingColor"]];
    self.criticalColorWell.color = [self colorFromHexString:[defaults objectForKey:@"criticalColor"]];
    self.lowPowerColorWell.color = [self colorFromHexString:[defaults objectForKey:@"lowPowerColor"]];
    self.textColorWell.color = [self colorFromHexString:[defaults objectForKey:@"textColor"]];
    NSURL *parentBundleURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"com.mtac.ampere"];
    NSBundle *parentBundle = [NSBundle bundleWithPath:parentBundleURL.path];
    [self.versionLabel setStringValue:[NSString stringWithFormat:@"Version %@", [[parentBundle infoDictionary] objectForKey:@"CFBundleShortVersionString"]]];
}
- (void)updateBatteryView {
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"AMPUpdateBatteryView" object:nil userInfo:nil deliverImmediately:YES];
}
- (NSMenu *)fontSizeMenu {
    NSMenu *fontMenu = [[NSMenu alloc] initWithTitle:@"Font Size"];
    for (int i = 9; i <= 12; i++) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%d", i] action:@selector(menuSelectionChanged:) keyEquivalent:@""];
        [fontMenu addItem:item];
    }
    return fontMenu;
}
- (IBAction)temperatureButtonClicked:(NSButton *)sender {
    NSPoint location = [NSEvent mouseLocation];
    NSMenu *menu = sender.menu;
    [menu popUpMenuPositioningItem:[menu itemAtIndex:0] atLocation:location inView:nil];
}
- (IBAction)styleButtonClicked:(NSButton *)sender {
    NSPoint location = [NSEvent mouseLocation];
    NSMenu *menu = sender.menu;
    [menu popUpMenuPositioningItem:[menu itemAtIndex:0] atLocation:location inView:nil];
}
- (IBAction)fontButtonClicked:(NSButton *)sender {
    NSPoint location = [NSEvent mouseLocation];
    NSMenu *menu = sender.menu;
    [menu popUpMenuPositioningItem:[menu itemAtIndex:0] atLocation:location inView:nil];
}
- (IBAction)resetColor:(NSButton *)sender {
    switch (sender.tag) {
        case 0: {
            NSString *colorString = @"#FFFFFFFF";
            self.normalColorWell.color = [self colorFromHexString:colorString];
            [defaults setObject:colorString forKey:@"normalColor"];
            break;
        }
        case 1: {
            NSString *colorString = @"#00F900FF";
            self.chargingColorWell.color = [self colorFromHexString:colorString];
            [defaults setObject:colorString forKey:@"chargingColor"];
            break;
        }
        case 2: {
            NSString *colorString = @"#FF2600FF";
            self.criticalColorWell.color = [self colorFromHexString:colorString];
            [defaults setObject:colorString forKey:@"criticalColor"];
            break;
        }
        case 3: {
            NSString *colorString = @"#FEDD11FF";
            self.lowPowerColorWell.color = [self colorFromHexString:colorString];
            [defaults setObject:colorString forKey:@"lowPowerColor"];
            break;
        }
        case 4: {
            NSString *colorString = @"#00000099";
            self.textColorWell.color = [self colorFromHexString:colorString];
            [defaults setObject:colorString forKey:@"textColor"];
            break;
        }
    }
    [defaults synchronize];
    [self updateBatteryView];
}
- (IBAction)segmentChanged:(NSSegmentedControl *)sender {
    NSInteger index = sender.selectedSegment;
    [self.tabView selectTabViewItemAtIndex:index];
}
- (IBAction)menuSelectionChanged:(NSMenuItem *)sender {
    NSMenu *menu = sender.menu;
    if ([menu isEqual:self.temperatureMenu]) {
        NSInteger index = [self.temperatureMenu indexOfItem:sender];
        switch (index) {
            default:
            case 0:
                [self.temperatureButton setTitle:@"Fahrenheit"];
                break;
            case 1:
                [self.temperatureButton setTitle:@"Celsius"];
                break;
        }
        for (int i = 0; i < self.temperatureMenu.itemArray.count; i++) {
            NSMenuItem *menuItem = [self.temperatureMenu.itemArray objectAtIndex:i];
            menuItem.state = (NSControlStateValue)[menuItem isEqual:sender];
        }
        [defaults setObject:(index == 0) ? @(YES) : @(NO) forKey:@"useFahrenheit"];
        [defaults synchronize];
        [self updateBatteryView];
    } else if ([menu isEqual:self.styleMenu]) {
        NSInteger index = [self.styleMenu indexOfItem:sender];
        switch (index) {
            default:
            case 0:
                [self.styleButton setTitle:@"Horizontal"];
                break;
            case 1:
                [self.styleButton setTitle:@"Vertical"];
                break;
            case 2:
                [self.styleButton setTitle:@"Outline"];
                break;
        }
        for (int i = 0; i < self.styleMenu.itemArray.count; i++) {
            NSMenuItem *menuItem = [self.styleMenu.itemArray objectAtIndex:i];
            menuItem.state = (NSControlStateValue)[menuItem isEqual:sender];
        }
        [defaults setObject:@(index) forKey:@"batteryStyle"];
        [defaults synchronize];
        [self updateBatteryView];
    } else if ([menu isEqual:self.fontMenu]) {
        NSInteger itemValue = [sender.title integerValue];
        [self.fontButton setTitle:[NSString stringWithFormat:@"Size: %@", sender.title]];
        for (int i = 0; i < self.fontMenu.itemArray.count; i++) {
            NSMenuItem *menuItem = [self.fontMenu.itemArray objectAtIndex:i];
            menuItem.state = (NSControlStateValue)[menuItem isEqual:sender];
        }
        [defaults setObject:@(itemValue) forKey:@"fontSize"];
        [defaults synchronize];
        [self updateBatteryView];
    }
}
- (IBAction)showPercentageSwitchChanged:(ITSwitch *)sender {
    [defaults setObject:[NSNumber numberWithBool:sender.checked] forKey:@"showPercentage"];
    [defaults synchronize];
    [self updateBatteryView];
}
- (IBAction)batteryColorSwitchChanged:(ITSwitch *)sender {
    [self setColorElementsEnabled:sender.checked];
    [defaults setObject:[NSNumber numberWithBool:sender.checked] forKey:@"useBatteryColors"];
    [defaults synchronize];
    [self updateBatteryView];
}
- (IBAction)toggleAutoLaunch:(ITSwitch *)sender {
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"AMPSetAutoLaunch" object:nil userInfo:@{@"enabled": @(sender.checked)}];
}
- (IBAction)colorWellDidSelectColor:(NSColorWell *)sender {
    if ([sender isEqual:self.normalColorWell]) {
        NSString *normalColorString = [self hexStringFromColor:self.normalColorWell.color];
        [defaults setObject:normalColorString forKey:@"normalColor"];
    } else if ([sender isEqual:self.chargingColorWell]) {
        NSString *chargingColorString = [self hexStringFromColor:self.chargingColorWell.color];
        [defaults setObject:chargingColorString forKey:@"chargingColor"];
    } if ([sender isEqual:self.criticalColorWell]) {
        NSString *criticalColorString = [self hexStringFromColor:self.criticalColorWell.color];
        [defaults setObject:criticalColorString forKey:@"criticalColor"];
    } if ([sender isEqual:self.lowPowerColorWell]) {
        NSString *lowPowerColorString = [self hexStringFromColor:self.lowPowerColorWell.color];
        [defaults setObject:lowPowerColorString forKey:@"lowPowerColor"];
    } if ([sender isEqual:self.textColorWell]) {
        NSString *textColorString = [self hexStringFromColor:self.textColorWell.color];
        [defaults setObject:textColorString forKey:@"textColor"];
    }
    [defaults synchronize];
    [self updateBatteryView];
}
- (void)setColorElementsEnabled:(BOOL)enabled {
    NSArray *colorElements = @[self.chargingColorWell, self.normalColorWell, self.criticalColorWell, self.lowPowerColorWell, self.textColorWell];
    for (NSControl *control in colorElements) {
        [control setEnabled:enabled];
    }
}
- (NSString *)hexStringFromColor:(NSColor *)color {
    NSColor *rgbColor = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    
    CGFloat red, green, blue, alpha;
    [rgbColor getRed:&red green:&green blue:&blue alpha:&alpha];
    
    return [NSString stringWithFormat:@"#%02lX%02lX%02lX%02lX",
                lround(red * 255),
                lround(green * 255),
                lround(blue * 255),
                lround(alpha * 255)];
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
- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}
@end
