#import <Cocoa/Cocoa.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        NSString *resources = [[NSBundle mainBundle] resourcePath];
        setenv("CODEX_SWITCHER_RESOURCES", resources.UTF8String, 1);

        NSTask *task = [[NSTask alloc] init];
        task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/osascript"];
        task.arguments = @[@"-l", @"JavaScript", [resources stringByAppendingPathComponent:@"launcher.js"]];
        NSError *error = nil;
        if (![task launchAndReturnError:&error]) {
            NSLog(@"Unable to start launcher: %@", error);
            return 1;
        }
        [task waitUntilExit];
        return task.terminationStatus;
    }
}
