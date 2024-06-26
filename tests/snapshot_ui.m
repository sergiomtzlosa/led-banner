#import <Cocoa/Cocoa.h>
#import "MainWindowController.h"

// Development helper: renders the main window's content view to build/ui-snapshot.png
// without requiring screen-recording permission.
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];

        MainWindowController *controller = [[MainWindowController alloc] init];
        NSWindow *window = controller.window;
        [window setFrame:NSMakeRect(0, 0, 1120, 1000) display:NO];
        NSView *content = window.contentView;
        [content layoutSubtreeIfNeeded];

        NSRect bounds = content.bounds;
        NSBitmapImageRep *rep = [content bitmapImageRepForCachingDisplayInRect:bounds];
        [content cacheDisplayInRect:bounds toBitmapImageRep:rep];

        NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        BOOL ok = [png writeToFile:@"build/ui-snapshot.png" atomically:YES];
        fprintf(stdout, "%s build/ui-snapshot.png\n", ok ? "wrote" : "failed to write");
        return ok ? 0 : 1;
    }
}
