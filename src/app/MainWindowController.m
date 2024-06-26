#import "MainWindowController.h"

#import "LEBConfiguration.h"
#import "LEBCanvasView.h"
#import "LEBExporter.h"

#pragma mark - Helpers

@interface LEBFlippedView : NSView
@end

@implementation LEBFlippedView
- (BOOL)isFlipped {
    return YES;
}
@end

static NSTextField *LEBLabel(NSString *text, CGFloat size, BOOL bold, NSColor *color) {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
    label.textColor = color ?: [NSColor labelColor];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

@interface MainWindowController () <NSTextFieldDelegate>

@property (nonatomic, strong) LEBConfiguration *configuration;

@property (nonatomic, strong) LEBCanvasView *canvasView;

@property (nonatomic, strong) NSTextField *messageField;

@property (nonatomic, strong) NSTextField *rowsField;
@property (nonatomic, strong) NSStepper *rowsStepper;
@property (nonatomic, strong) NSTextField *columnsField;
@property (nonatomic, strong) NSStepper *columnsStepper;

@property (nonatomic, strong) NSColorWell *ledColorWell;
@property (nonatomic, strong) NSColorWell *backgroundColorWell;
@property (nonatomic, strong) NSPopUpButton *palettePopUp;
@property (nonatomic, strong) NSPopUpButton *shapePopUp;
@property (nonatomic, strong) NSPopUpButton *fontScalePopUp;
@property (nonatomic, strong) NSSlider *dotSlider;
@property (nonatomic, strong) NSTextField *dotValueLabel;
@property (nonatomic, strong) NSButton *glowCheckbox;

@property (nonatomic, strong) NSSlider *speedSlider;
@property (nonatomic, strong) NSTextField *speedValueLabel;
@property (nonatomic, strong) NSPopUpButton *directionPopUp;

@property (nonatomic, strong) NSButton *playButton;
@property (nonatomic, strong) NSSlider *scrubSlider;
@property (nonatomic, strong) NSTextField *timeLabel;

@property (nonatomic, strong) NSPopUpButton *formatPopUp;
@property (nonatomic, strong) NSTextField *fpsField;
@property (nonatomic, strong) NSStepper *fpsStepper;
@property (nonatomic, strong) NSTextField *durationField;
@property (nonatomic, strong) NSButton *exportButton;

@property (nonatomic, strong) NSStackView *progressStack;
@property (nonatomic, strong) NSProgressIndicator *progressIndicator;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSButton *cancelButton;

@property (nonatomic, strong) LEBExporter *exporter;
@property (nonatomic) BOOL didStartPlayback;

@end

@implementation MainWindowController

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1120, 720)
                                                   styleMask:(NSWindowStyleMaskTitled |
                                                              NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskMiniaturizable |
                                                              NSWindowStyleMaskResizable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"LED Banner";
    window.minSize = NSMakeSize(900, 560);
    window.releasedWhenClosed = NO;
    if (@available(macOS 10.14, *)) {
        window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    }

    self = [super initWithWindow:window];
    if (self) {
        _configuration = [[LEBConfiguration alloc] init];
        [self buildInterface];
        [window center];
    }
    return self;
}

- (void)showWindow:(id)sender {
    [super showWindow:sender];
    [self.window makeKeyAndOrderFront:sender];
    if (!self.didStartPlayback) {
        self.didStartPlayback = YES;
        [self.canvasView play];
        self.playButton.title = @"Pause";
    }
}

#pragma mark - Interface

- (void)buildInterface {
    NSView *root = [[NSView alloc] initWithFrame:NSZeroRect];
    root.wantsLayer = YES;
    root.layer.backgroundColor = [NSColor colorWithSRGBRed:0.075 green:0.075 blue:0.088 alpha:1.0].CGColor;

    self.canvasView = [[LEBCanvasView alloc] initWithFrame:NSZeroRect];
    self.canvasView.translatesAutoresizingMaskIntoConstraints = NO;
    self.canvasView.configuration = self.configuration;
    [root addSubview:self.canvasView];

    __weak typeof(self) weakSelf = self;
    self.canvasView.timeDidChangeHandler = ^(NSTimeInterval time, NSTimeInterval cycle) {
        [weakSelf updateTimeUIWithTime:time cycle:cycle];
    };

    NSView *inspector = [[NSView alloc] initWithFrame:NSZeroRect];
    inspector.translatesAutoresizingMaskIntoConstraints = NO;
    inspector.wantsLayer = YES;
    inspector.layer.backgroundColor = [NSColor colorWithSRGBRed:0.125 green:0.125 blue:0.142 alpha:1.0].CGColor;
    [root addSubview:inspector];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.drawsBackground = NO;
    scrollView.borderType = NSNoBorder;
    [inspector addSubview:scrollView];

    LEBFlippedView *documentView = [[LEBFlippedView alloc] initWithFrame:NSMakeRect(0, 0, 330, 900)];
    documentView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.documentView = documentView;

    NSStackView *stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 9.0;
    [documentView addSubview:stack];

    [self buildInspectorStack:stack];

    [NSLayoutConstraint activateConstraints:@[
        [self.canvasView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [self.canvasView.topAnchor constraintEqualToAnchor:root.topAnchor],
        [self.canvasView.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [self.canvasView.trailingAnchor constraintEqualToAnchor:inspector.leadingAnchor],

        [inspector.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [inspector.topAnchor constraintEqualToAnchor:root.topAnchor],
        [inspector.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [inspector.widthAnchor constraintEqualToConstant:340.0],

        [scrollView.leadingAnchor constraintEqualToAnchor:inspector.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:inspector.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:inspector.topAnchor constant:1.0],
        [scrollView.bottomAnchor constraintEqualToAnchor:inspector.bottomAnchor],

        [documentView.leadingAnchor constraintEqualToAnchor:scrollView.contentView.leadingAnchor],
        [documentView.topAnchor constraintEqualToAnchor:scrollView.contentView.topAnchor],
        [documentView.widthAnchor constraintEqualToAnchor:scrollView.contentView.widthAnchor],

        [stack.leadingAnchor constraintEqualToAnchor:documentView.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:documentView.trailingAnchor constant:-16.0],
        [stack.topAnchor constraintEqualToAnchor:documentView.topAnchor constant:14.0],
        [stack.bottomAnchor constraintEqualToAnchor:documentView.bottomAnchor constant:-16.0]
    ]];

    for (NSView *view in stack.arrangedSubviews) {
        [view.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    }

    self.window.contentView = root;
}

- (void)buildInspectorStack:(NSStackView *)stack {
    LEBConfiguration *config = self.configuration;

    // ---- Banner -----------------------------------------------------------
    [self addSectionTitle:@"Banner" toStack:stack first:YES];

    self.messageField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    self.messageField.stringValue = config.message;
    self.messageField.placeholderString = @"Message";
    self.messageField.font = [NSFont systemFontOfSize:13.0];
    self.messageField.delegate = self;
    [self.messageField setContentHuggingPriority:NSLayoutPriorityDefaultLow
                                  forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self.messageField.heightAnchor constraintEqualToConstant:24.0].active = YES;
    [stack addArrangedSubview:[self rowWithTitle:@"Message" control:self.messageField]];

    self.rowsField = [self numericFieldWithValue:config.rows];
    self.rowsStepper = [self stepperWithMin:1 max:128 value:config.rows
                                     action:@selector(rowsStepperChanged:)];
    [stack addArrangedSubview:[self rowWithTitle:@"Rows"
                                         control:[self fieldAndStepperStack:self.rowsField
                                                                     stepper:self.rowsStepper]]];

    self.columnsField = [self numericFieldWithValue:config.columns];
    self.columnsStepper = [self stepperWithMin:8 max:256 value:config.columns
                                       action:@selector(columnsStepperChanged:)];
    [stack addArrangedSubview:[self rowWithTitle:@"Columns"
                                         control:[self fieldAndStepperStack:self.columnsField
                                                                     stepper:self.columnsStepper]]];

    // ---- Style ------------------------------------------------------------
    [self addSectionTitle:@"Style" toStack:stack first:NO];

    self.ledColorWell = [[NSColorWell alloc] initWithFrame:NSZeroRect];
    self.ledColorWell.color = config.ledColor;
    self.ledColorWell.target = self;
    self.ledColorWell.action = @selector(ledColorChanged:);
    [self.ledColorWell.widthAnchor constraintEqualToConstant:52.0].active = YES;
    [self.ledColorWell.heightAnchor constraintEqualToConstant:24.0].active = YES;
    [stack addArrangedSubview:[self rowWithTitle:@"LED color" control:self.ledColorWell]];

    self.backgroundColorWell = [[NSColorWell alloc] initWithFrame:NSZeroRect];
    self.backgroundColorWell.color = config.backgroundColor;
    self.backgroundColorWell.target = self;
    self.backgroundColorWell.action = @selector(backgroundColorChanged:);
    [self.backgroundColorWell.widthAnchor constraintEqualToConstant:52.0].active = YES;
    [self.backgroundColorWell.heightAnchor constraintEqualToConstant:24.0].active = YES;
    [stack addArrangedSubview:[self rowWithTitle:@"Background" control:self.backgroundColorWell]];

    self.palettePopUp = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [self.palettePopUp addItemsWithTitles:@[@"Solid", @"Plasma", @"Rainbow"]];
    [self.palettePopUp selectItemAtIndex:config.palette];
    self.palettePopUp.target = self;
    self.palettePopUp.action = @selector(paletteChanged:);
    [stack addArrangedSubview:[self rowWithTitle:@"Palette" control:self.palettePopUp]];

    self.shapePopUp = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [self.shapePopUp addItemsWithTitles:@[@"Circle", @"Square"]];
    [self.shapePopUp selectItemAtIndex:config.ledShape];
    self.shapePopUp.target = self;
    self.shapePopUp.action = @selector(shapeChanged:);
    [stack addArrangedSubview:[self rowWithTitle:@"LED shape" control:self.shapePopUp]];

    self.fontScalePopUp = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [self.fontScalePopUp addItemsWithTitles:@[@"Small · 1×", @"Medium · 2×", @"Large · 3×", @"Extra large · 4×"]];
    [self.fontScalePopUp selectItemAtIndex:(NSInteger)MIN(MAX(config.fontScale, 1), 4) - 1];
    self.fontScalePopUp.target = self;
    self.fontScalePopUp.action = @selector(fontScaleChanged:);
    [self.fontScalePopUp.widthAnchor constraintGreaterThanOrEqualToConstant:150.0].active = YES;
    [stack addArrangedSubview:[self rowWithTitle:@"Font size" control:self.fontScalePopUp]];

    self.dotSlider = [NSSlider sliderWithValue:config.dotRatio minValue:0.3 maxValue:1.0
                                        target:self action:@selector(dotSizeChanged:)];
    self.dotSlider.continuous = YES;
    [self.dotSlider.widthAnchor constraintGreaterThanOrEqualToConstant:110.0].active = YES;
    self.dotValueLabel = [self valueLabelWithText:@""];
    NSStackView *dotControl = [self sliderWithValueLabelStack:self.dotSlider label:self.dotValueLabel];
    [self updateDotValueLabel];
    [stack addArrangedSubview:[self rowWithTitle:@"Dot size" control:dotControl]];

    self.glowCheckbox = [NSButton checkboxWithTitle:@"Glow" target:self action:@selector(glowChanged:)];
    self.glowCheckbox.state = config.glow ? NSControlStateValueOn : NSControlStateValueOff;
    [stack addArrangedSubview:[self rowWithTitle:@"Effect" control:self.glowCheckbox]];

    // ---- Motion -----------------------------------------------------------
    [self addSectionTitle:@"Motion" toStack:stack first:NO];

    self.speedSlider = [NSSlider sliderWithValue:config.scrollSpeed minValue:2.0 maxValue:80.0
                                          target:self action:@selector(speedChanged:)];
    self.speedSlider.continuous = YES;
    [self.speedSlider.widthAnchor constraintGreaterThanOrEqualToConstant:110.0].active = YES;
    self.speedValueLabel = [self valueLabelWithText:@""];
    NSStackView *speedControl = [self sliderWithValueLabelStack:self.speedSlider
                                                          label:self.speedValueLabel];
    [self updateSpeedValueLabel];
    [stack addArrangedSubview:[self rowWithTitle:@"Speed" control:speedControl]];

    self.directionPopUp = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [self.directionPopUp addItemsWithTitles:@[@"Right to left", @"Left to right"]];
    [self.directionPopUp selectItemAtIndex:config.direction];
    self.directionPopUp.target = self;
    self.directionPopUp.action = @selector(directionChanged:);
    [stack addArrangedSubview:[self rowWithTitle:@"Direction" control:self.directionPopUp]];

    // ---- Playback ---------------------------------------------------------
    [self addSectionTitle:@"Playback" toStack:stack first:NO];

    self.playButton = [NSButton buttonWithTitle:@"Pause" target:self action:@selector(togglePlayback:)];
    self.playButton.bezelStyle = NSBezelStyleRounded;
    [self.playButton.widthAnchor constraintEqualToConstant:78.0].active = YES;
    self.timeLabel = LEBLabel(@"0.0s / 0.0s", 11.0, NO, [NSColor secondaryLabelColor]);
    self.timeLabel.font = [NSFont monospacedDigitSystemFontOfSize:11.0 weight:NSFontWeightRegular];
    NSStackView *playControl = [NSStackView stackViewWithViews:@[self.playButton, self.timeLabel]];
    playControl.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    playControl.alignment = NSLayoutAttributeCenterY;
    playControl.spacing = 10.0;
    [stack addArrangedSubview:[self rowWithTitle:@"Playback" control:playControl]];

    self.scrubSlider = [NSSlider sliderWithValue:0.0 minValue:0.0 maxValue:1.0
                                          target:self action:@selector(scrubChanged:)];
    self.scrubSlider.continuous = YES;
    [self.scrubSlider.widthAnchor constraintGreaterThanOrEqualToConstant:110.0].active = YES;
    [stack addArrangedSubview:[self rowWithTitle:@"Position" control:self.scrubSlider]];

    // ---- Export -----------------------------------------------------------
    [self addSectionTitle:@"Export" toStack:stack first:NO];

    self.formatPopUp = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [self.formatPopUp addItemsWithTitles:@[@"Animated GIF", @"Video · MP4", @"Video · MOV (ProRes)"]];
    [self.formatPopUp selectItemAtIndex:0];
    self.formatPopUp.target = self;
    [stack addArrangedSubview:[self rowWithTitle:@"Format" control:self.formatPopUp]];

    self.fpsField = [self numericFieldWithValue:config.exportFPS];
    self.fpsStepper = [self stepperWithMin:10 max:60 value:config.exportFPS
                                    action:@selector(fpsStepperChanged:)];
    [stack addArrangedSubview:[self rowWithTitle:@"Frame rate"
                                         control:[self fieldAndStepperStack:self.fpsField
                                                                     stepper:self.fpsStepper]]];

    self.durationField = [self numericFieldWithValue:0];
    self.durationField.placeholderString = @"auto";
    self.durationField.toolTip = @"Seconds to export. 0 exports one full scroll cycle.";
    NSTextField *secondsLabel = LEBLabel(@"sec · 0 = auto", 10.0, NO, [NSColor secondaryLabelColor]);
    NSStackView *durationControl = [NSStackView stackViewWithViews:@[self.durationField, secondsLabel]];
    durationControl.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    durationControl.alignment = NSLayoutAttributeCenterY;
    durationControl.spacing = 7.0;
    [stack addArrangedSubview:[self rowWithTitle:@"Duration" control:durationControl]];

    self.exportButton = [NSButton buttonWithTitle:@"Export…" target:self action:@selector(exportPressed:)];
    self.exportButton.bezelStyle = NSBezelStyleRounded;
    self.exportButton.font = [NSFont boldSystemFontOfSize:13.0];
    [self.exportButton.heightAnchor constraintEqualToConstant:30.0].active = YES;
    [stack addArrangedSubview:self.exportButton];

    self.progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    self.progressIndicator.style = NSProgressIndicatorStyleBar;
    self.progressIndicator.indeterminate = NO;
    self.progressIndicator.minValue = 0.0;
    self.progressIndicator.maxValue = 1.0;
    self.progressIndicator.doubleValue = 0.0;
    self.progressIndicator.translatesAutoresizingMaskIntoConstraints = NO;

    self.statusLabel = LEBLabel(@"", 11.0, NO, [NSColor secondaryLabelColor]);
    self.cancelButton = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancelExport:)];
    self.cancelButton.bezelStyle = NSBezelStyleRounded;
    self.cancelButton.controlSize = NSControlSizeSmall;
    NSStackView *statusRow = [NSStackView stackViewWithViews:@[self.statusLabel, self.cancelButton]];
    statusRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    statusRow.alignment = NSLayoutAttributeCenterY;
    statusRow.spacing = 8.0;

    self.progressStack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    self.progressStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.progressStack.alignment = NSLayoutAttributeLeading;
    self.progressStack.spacing = 6.0;
    self.progressStack.detachesHiddenViews = YES;
    [self.progressStack addArrangedSubview:self.progressIndicator];
    [self.progressStack addArrangedSubview:statusRow];
    [self.progressStack.widthAnchor constraintGreaterThanOrEqualToConstant:280.0].active = YES;
    [self.progressIndicator.widthAnchor constraintEqualToAnchor:self.progressStack.widthAnchor].active = YES;
    [statusRow.widthAnchor constraintEqualToAnchor:self.progressStack.widthAnchor].active = YES;
    [self.cancelButton setContentHuggingPriority:NSLayoutPriorityRequired
                                  forOrientation:NSLayoutConstraintOrientationHorizontal];
    self.progressStack.hidden = YES;
    [stack addArrangedSubview:self.progressStack];
}

#pragma mark - Control factories

- (void)addSectionTitle:(NSString *)title toStack:(NSStackView *)stack first:(BOOL)first {
    if (!first) {
        NSView *spacer = [[NSView alloc] initWithFrame:NSZeroRect];
        [spacer.heightAnchor constraintEqualToConstant:8.0].active = YES;
        [stack addArrangedSubview:spacer];
    }
    NSTextField *label = LEBLabel(title.uppercaseString, 10.5, YES, [NSColor secondaryLabelColor]);
    [stack addArrangedSubview:label];
}

- (NSStackView *)rowWithTitle:(NSString *)title control:(NSView *)control {
    NSTextField *label = LEBLabel(title, 12.0, NO, [NSColor secondaryLabelColor]);
    [label setContentHuggingPriority:NSLayoutPriorityRequired
                      forOrientation:NSLayoutConstraintOrientationHorizontal];
    [label.widthAnchor constraintEqualToConstant:82.0].active = YES;

    NSStackView *row = [NSStackView stackViewWithViews:@[label, control]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 8.0;
    [control setContentHuggingPriority:NSLayoutPriorityDefaultLow
                        forOrientation:NSLayoutConstraintOrientationHorizontal];
    [control setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                      forOrientation:NSLayoutConstraintOrientationHorizontal];
    return row;
}

- (NSTextField *)numericFieldWithValue:(NSInteger)value {
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSZeroRect];
    field.stringValue = [NSString stringWithFormat:@"%ld", (long)value];
    field.alignment = NSTextAlignmentRight;
    field.font = [NSFont monospacedDigitSystemFontOfSize:12.0 weight:NSFontWeightRegular];
    field.delegate = self;
    [field.widthAnchor constraintEqualToConstant:54.0].active = YES;
    [field.heightAnchor constraintEqualToConstant:22.0].active = YES;
    return field;
}

- (NSStepper *)stepperWithMin:(double)min
                          max:(double)max
                        value:(double)value
                       action:(SEL)action {
    NSStepper *stepper = [[NSStepper alloc] initWithFrame:NSZeroRect];
    stepper.minValue = min;
    stepper.maxValue = max;
    stepper.increment = 1.0;
    stepper.doubleValue = value;
    stepper.valueWraps = NO;
    stepper.autorepeat = YES;
    stepper.target = self;
    stepper.action = action;
    return stepper;
}

- (NSStackView *)fieldAndStepperStack:(NSTextField *)field stepper:(NSStepper *)stepper {
    NSStackView *stack = [NSStackView stackViewWithViews:@[field, stepper]];
    stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    stack.alignment = NSLayoutAttributeCenterY;
    stack.spacing = 4.0;
    return stack;
}

- (NSTextField *)valueLabelWithText:(NSString *)text {
    NSTextField *label = LEBLabel(text, 11.0, NO, [NSColor secondaryLabelColor]);
    label.alignment = NSTextAlignmentRight;
    label.font = [NSFont monospacedDigitSystemFontOfSize:11.0 weight:NSFontWeightRegular];
    [label.widthAnchor constraintEqualToConstant:54.0].active = YES;
    [label setContentHuggingPriority:NSLayoutPriorityRequired
                      forOrientation:NSLayoutConstraintOrientationHorizontal];
    return label;
}

- (NSStackView *)sliderWithValueLabelStack:(NSSlider *)slider label:(NSTextField *)label {
    NSStackView *stack = [NSStackView stackViewWithViews:@[slider, label]];
    stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    stack.alignment = NSLayoutAttributeCenterY;
    stack.spacing = 8.0;
    [slider setContentHuggingPriority:NSLayoutPriorityDefaultLow
                       forOrientation:NSLayoutConstraintOrientationHorizontal];
    return stack;
}

#pragma mark - Actions

- (void)controlTextDidChange:(NSNotification *)notification {
    if (notification.object == self.messageField) {
        self.configuration.message = self.messageField.stringValue;
        [self.configuration notifyChanged];
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    id object = notification.object;
    if (object == self.messageField) {
        self.configuration.message = self.messageField.stringValue;
        [self.configuration notifyChanged];
    } else if (object == self.rowsField) {
        [self commitIntegerField:self.rowsField
                          stepper:self.rowsStepper
                              min:1 max:128
                      applyBlock:^(NSInteger value) {
            self.configuration.rows = (NSUInteger)value;
        }];
    } else if (object == self.columnsField) {
        [self commitIntegerField:self.columnsField
                          stepper:self.columnsStepper
                              min:8 max:256
                      applyBlock:^(NSInteger value) {
            self.configuration.columns = (NSUInteger)value;
        }];
    } else if (object == self.fpsField) {
        [self commitIntegerField:self.fpsField
                          stepper:self.fpsStepper
                              min:10 max:60
                      applyBlock:^(NSInteger value) {
            self.configuration.exportFPS = (NSUInteger)value;
        }];
    } else if (object == self.durationField) {
        double value = MIN(MAX(self.durationField.doubleValue, 0.0), 300.0);
        self.durationField.stringValue = [self formatDuration:value];
        self.configuration.exportDuration = value;
    }
}

- (void)commitIntegerField:(NSTextField *)field
                    stepper:(NSStepper *)stepper
                        min:(NSInteger)min
                        max:(NSInteger)max
                applyBlock:(void (^)(NSInteger value))applyBlock {
    NSInteger value = field.integerValue;
    value = MIN(MAX(value, min), max);
    field.stringValue = [NSString stringWithFormat:@"%ld", (long)value];
    stepper.doubleValue = value;
    applyBlock(value);
    [self.configuration notifyChanged];
}

- (NSString *)formatDuration:(double)value {
    if (value <= 0.0) {
        return @"0";
    }
    if (fabs(value - round(value)) < 0.001) {
        return [NSString stringWithFormat:@"%ld", (long)round(value)];
    }
    return [NSString stringWithFormat:@"%.1f", value];
}

- (void)rowsStepperChanged:(NSStepper *)sender {
    NSInteger value = MIN(MAX((NSInteger)lrint(sender.doubleValue), 1), 128);
    self.rowsField.stringValue = [NSString stringWithFormat:@"%ld", (long)value];
    self.configuration.rows = (NSUInteger)value;
    [self.configuration notifyChanged];
}

- (void)columnsStepperChanged:(NSStepper *)sender {
    NSInteger value = MIN(MAX((NSInteger)lrint(sender.doubleValue), 8), 256);
    self.columnsField.stringValue = [NSString stringWithFormat:@"%ld", (long)value];
    self.configuration.columns = (NSUInteger)value;
    [self.configuration notifyChanged];
}

- (void)fpsStepperChanged:(NSStepper *)sender {
    NSInteger value = MIN(MAX((NSInteger)lrint(sender.doubleValue), 10), 60);
    self.fpsField.stringValue = [NSString stringWithFormat:@"%ld", (long)value];
    self.configuration.exportFPS = (NSUInteger)value;
}

- (void)ledColorChanged:(NSColorWell *)sender {
    self.configuration.ledColor = sender.color;
    [self.configuration notifyChanged];
}

- (void)backgroundColorChanged:(NSColorWell *)sender {
    self.configuration.backgroundColor = sender.color;
    [self.configuration notifyChanged];
}

- (void)paletteChanged:(NSPopUpButton *)sender {
    self.configuration.palette = (LEBPalette)sender.indexOfSelectedItem;
    [self.configuration notifyChanged];
}

- (void)shapeChanged:(NSPopUpButton *)sender {
    self.configuration.ledShape = (LEBLedShape)sender.indexOfSelectedItem;
    [self.configuration notifyChanged];
}

- (void)fontScaleChanged:(NSPopUpButton *)sender {
    self.configuration.fontScale = (NSUInteger)(sender.indexOfSelectedItem + 1);
    [self.configuration notifyChanged];
}

- (void)dotSizeChanged:(NSSlider *)sender {
    self.configuration.dotRatio = sender.doubleValue;
    [self updateDotValueLabel];
    [self.configuration notifyChanged];
}

- (void)updateDotValueLabel {
    self.dotValueLabel.stringValue = [NSString stringWithFormat:@"%ld%%", (long)lround(self.dotSlider.doubleValue * 100.0)];
}

- (void)glowChanged:(NSButton *)sender {
    self.configuration.glow = (sender.state == NSControlStateValueOn);
    [self.configuration notifyChanged];
}

- (void)speedChanged:(NSSlider *)sender {
    self.configuration.scrollSpeed = sender.doubleValue;
    [self updateSpeedValueLabel];
    [self.configuration notifyChanged];
}

- (void)updateSpeedValueLabel {
    self.speedValueLabel.stringValue = [NSString stringWithFormat:@"%ld/s", (long)lround(self.speedSlider.doubleValue)];
}

- (void)directionChanged:(NSPopUpButton *)sender {
    self.configuration.direction = (LEBScrollDirection)sender.indexOfSelectedItem;
    [self.configuration notifyChanged];
}

- (void)togglePlayback:(id)sender {
    [self.canvasView togglePlayback];
    self.playButton.title = self.canvasView.isPlaying ? @"Pause" : @"Play";
}

- (void)scrubChanged:(NSSlider *)sender {
    NSTimeInterval cycle = [self.canvasView cycleDuration];
    self.canvasView.currentTime = sender.doubleValue * cycle;
}

- (void)updateTimeUIWithTime:(NSTimeInterval)time cycle:(NSTimeInterval)cycle {
    if ((NSEvent.pressedMouseButtons & 1) == 0) {
        self.scrubSlider.doubleValue = cycle > 0.0 ? time / cycle : 0.0;
    }
    self.timeLabel.stringValue = [NSString stringWithFormat:@"%.1fs / %.1fs", time, cycle];
}

#pragma mark - Export

- (void)exportFromMenu:(id)sender {
    [self exportPressed:sender];
}

- (void)exportPressed:(id)sender {
    if (self.exporter) {
        return;
    }
    [self.window makeFirstResponder:nil];

    LEBExportFormat format = (LEBExportFormat)self.formatPopUp.indexOfSelectedItem;
    NSString *extension = @"gif";
    if (format == LEBExportFormatMP4) {
        extension = @"mp4";
    } else if (format == LEBExportFormatMOV) {
        extension = @"mov";
    }

    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.title = @"Export LED Banner";
    panel.prompt = @"Export";
    panel.canCreateDirectories = YES;
    panel.nameFieldStringValue = [@"LED Banner" stringByAppendingPathExtension:extension];
    panel.allowedFileTypes = @[extension];

    __weak typeof(self) weakSelf = self;
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || result != NSModalResponseOK || !panel.URL) {
            return;
        }
        [strongSelf beginExportToURL:panel.URL format:format];
    }];
}

- (void)beginExportToURL:(NSURL *)url format:(LEBExportFormat)format {
    LEBConfiguration *snapshot = [self.configuration copy];

    LEBExporter *exporter = nil;
    if (format == LEBExportFormatGIF) {
        exporter = [[LEBGifExporter alloc] init];
    } else {
        LEBVideoExporter *videoExporter = [[LEBVideoExporter alloc] init];
        videoExporter.format = format;
        exporter = videoExporter;
    }
    exporter.configuration = snapshot;
    exporter.fps = MAX(snapshot.exportFPS, (NSUInteger)1);
    exporter.duration = snapshot.exportDuration;
    self.exporter = exporter;

    [self.canvasView pause];
    self.playButton.title = @"Play";

    self.progressStack.hidden = NO;
    self.progressIndicator.minValue = 0.0;
    self.progressIndicator.maxValue = (double)[exporter frameCount];
    self.progressIndicator.doubleValue = 0.0;
    self.statusLabel.stringValue = @"Preparing export…";
    self.cancelButton.hidden = NO;
    self.cancelButton.enabled = YES;
    self.exportButton.enabled = NO;

    __weak typeof(self) weakSelf = self;
    exporter.progressHandler = ^(NSUInteger completed, NSUInteger total) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.progressIndicator.maxValue = (double)MAX(total, (NSUInteger)1);
        strongSelf.progressIndicator.doubleValue = (double)completed;
        strongSelf.statusLabel.stringValue = [NSString stringWithFormat:@"Rendering frame %lu of %lu",
                                              (unsigned long)completed, (unsigned long)total];
    };

    [exporter exportToURL:url completion:^(NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.exporter = nil;
        strongSelf.exportButton.enabled = YES;
        strongSelf.cancelButton.hidden = YES;

        BOOL cancelled = ([error.domain isEqualToString:LEBExporterErrorDomain] && error.code == 1) ||
                         ([error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSUserCancelledError);

        if (error && !cancelled) {
            strongSelf.statusLabel.stringValue = @"Export failed.";
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Export failed";
            alert.informativeText = error.localizedDescription ?: @"Unknown error.";
            alert.alertStyle = NSAlertStyleWarning;
            [alert beginSheetModalForWindow:strongSelf.window completionHandler:nil];
        } else if (cancelled) {
            strongSelf.statusLabel.stringValue = @"Export cancelled.";
            strongSelf.progressIndicator.doubleValue = 0.0;
        } else {
            strongSelf.progressIndicator.doubleValue = strongSelf.progressIndicator.maxValue;
            strongSelf.statusLabel.stringValue = [NSString stringWithFormat:@"Saved %@", url.lastPathComponent];
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf2 = weakSelf;
            if (strongSelf2 && strongSelf2.exporter == nil) {
                strongSelf2.progressStack.hidden = YES;
            }
        });
    }];
}

- (void)cancelExport:(id)sender {
    if (!self.exporter) {
        return;
    }
    [self.exporter cancel];
    self.cancelButton.enabled = NO;
    self.statusLabel.stringValue = @"Cancelling…";
}

@end
