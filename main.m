// TweaksLoader.m - v1.1
// By AldazDev

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <spawn.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>
#include <stdio.h>

#define GESTALT_PLIST ALGGestaltPath()
#define LOG_PATH "/var/mobile/Media/aldazdev.log"
#define GESTALT_BACKUP @"/var/mobile/Media/TweaksLoader_MobileGestalt_backup.plist"
#define PEIK @"oPeik/9e8lQWMszEjbPzng"
static void ALGShowFileBrowser(NSString *path);
static void ALGShowTerminal(void);
static void ALGShowGestaltEditor(void);
static NSDictionary *ALGLoadGestaltPlist(void);
static BOOL ALGSaveGestaltPlist(NSDictionary *dict);
static void ALGBackupGestalt(void);
static BOOL ALGRestoreGestalt(void);
static NSArray *ALGGestaltTweaks(void);
static BOOL ALGPatchCacheDataDeviceClass(NSMutableDictionary *plist, BOOL toIPad);


extern char **environ;

static NSString *ALGGestaltPath(void) {
    return @"/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist";
}

static void ALGGestaltUnlockPath(NSString *p) {
    const char *cp = p.UTF8String;
    struct stat st;
    if (stat(cp, &st) == 0 && (st.st_flags & (UF_IMMUTABLE | SF_IMMUTABLE))) {
        int r = chflags(cp, st.st_flags & ~(UF_IMMUTABLE | SF_IMMUTABLE));
        NSLog(@"[TweaksLoader:Gestalt] chflags nouchg %@: %d errno: %d", p, r, errno);
    }
}
static void ALGGestaltUnlock(void) {
    NSString *filePath = ALGGestaltPath();
    // Desbloquear el archivo
    ALGGestaltUnlockPath(filePath);
    // Desbloquear directorios padre en cascada
    NSString *dir = [filePath stringByDeletingLastPathComponent];
    while (dir.length > 1 && ![dir isEqualToString:@"/"]) {
        ALGGestaltUnlockPath(dir);
        dir = [dir stringByDeletingLastPathComponent];
        // Solo hasta /var/containers/Shared
        if ([dir hasSuffix:@"Shared"]) { ALGGestaltUnlockPath(dir); break; }
    }
}
static void ALGGestaltLock(void) {
    const char *path = ALGGestaltPath().UTF8String;
    struct stat st;
    if (stat(path, &st) == 0) {
        int r = chflags(path, st.st_flags | UF_IMMUTABLE);
        NSLog(@"[TweaksLoader:Gestalt] chflags uchg: %d errno: %d", r, errno);
    }
}




// ─── LiquidGlass inlineado ───────────────────────────────────
typedef struct { CGFloat cornerRadius; CGFloat blurAlpha; CGFloat borderAlpha; CGFloat shadowRadius; CGFloat shadowOpacity; } LGParams;
static const LGParams LGParamsDock   = {26.0f, 0.55f, 0.25f, 18.0f, 0.35f};
static const LGParams LGParamsBanner = {14.0f, 0.45f, 0.30f, 12.0f, 0.30f};
static const LGParams LGParamsCC     = {22.0f, 0.78f, 0.35f, 20.0f, 0.40f};

static void ALGApplyLiquidGlass(UIView *v, LGParams p) {
    if (!v || v.bounds.size.width < 10) return;
    for (UIView *s in [v.subviews copy]) if (objc_getAssociatedObject(s,"algGlass")) [s removeFromSuperview];
    for (CALayer *l in [v.layer.sublayers copy]) if ([l.name hasPrefix:@"LG"]) [l removeFromSuperlayer];
    UIBlurEffect *blurEff;
    if (@available(iOS 13.0,*)) blurEff=[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    else blurEff=[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *bv=[[UIVisualEffectView alloc] initWithEffect:blurEff];
    bv.frame=v.bounds; bv.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    bv.alpha=p.blurAlpha; bv.layer.cornerRadius=p.cornerRadius;
    if (@available(iOS 13.0,*)) bv.layer.cornerCurve=kCACornerCurveContinuous;
    bv.layer.masksToBounds=YES; bv.userInteractionEnabled=NO;
    objc_setAssociatedObject(bv,"algGlass",@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [v insertSubview:bv atIndex:0];
    // Refraction
    CAGradientLayer *ref=[CAGradientLayer layer]; ref.name=@"LGRef"; ref.type=kCAGradientLayerRadial; ref.frame=v.bounds;
    ref.colors=@[(id)[UIColor colorWithWhite:1 alpha:0.07f].CGColor,(id)[UIColor colorWithWhite:1 alpha:0.02f].CGColor,(id)[UIColor colorWithWhite:1 alpha:0].CGColor];
    ref.locations=@[@0,@0.45f,@1]; ref.startPoint=CGPointMake(0.25f,0.2f); ref.endPoint=CGPointMake(1.2f,1.2f);
    ref.cornerRadius=p.cornerRadius; [v.layer addSublayer:ref];
    // Inner glow
    CAGradientLayer *ig=[CAGradientLayer layer]; ig.name=@"LGGlow"; ig.frame=v.bounds;
    ig.colors=@[(id)[UIColor colorWithWhite:1 alpha:0.12f].CGColor,(id)[UIColor colorWithWhite:1 alpha:0].CGColor,(id)[UIColor colorWithWhite:1 alpha:0].CGColor,(id)[UIColor colorWithWhite:1 alpha:0.04f].CGColor];
    ig.locations=@[@0,@0.15f,@0.85f,@1]; ig.cornerRadius=p.cornerRadius;
    CAShapeLayer *igm=[CAShapeLayer layer]; UIBezierPath *igo=[UIBezierPath bezierPathWithRoundedRect:v.bounds cornerRadius:p.cornerRadius];
    UIBezierPath *igi=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(v.bounds,3,3) cornerRadius:MAX(0,p.cornerRadius-3)];
    [igo appendPath:igi]; igo.usesEvenOddFillRule=YES; igm.path=igo.CGPath; igm.fillRule=kCAFillRuleEvenOdd; ig.mask=igm; [v.layer addSublayer:ig];
    // Specular 3-stop
    CAGradientLayer *spec=[CAGradientLayer layer]; spec.name=@"LGSpecular"; spec.frame=v.bounds;
    spec.colors=@[(id)[UIColor colorWithWhite:1 alpha:0.22f].CGColor,(id)[UIColor colorWithWhite:1 alpha:0.06f].CGColor,(id)[UIColor colorWithWhite:1 alpha:0].CGColor];
    spec.locations=@[@0,@0.25f,@0.6f]; spec.startPoint=CGPointMake(0,0); spec.endPoint=CGPointMake(0.6f,0.8f);
    spec.cornerRadius=p.cornerRadius; [v.layer addSublayer:spec];
    // Chromatic edge
    CAGradientLayer *chr=[CAGradientLayer layer]; chr.name=@"LGChr"; chr.frame=v.bounds;
    chr.colors=@[(id)[UIColor colorWithRed:.6f green:.8f blue:1 alpha:.08f].CGColor,(id)[UIColor colorWithRed:1 green:.9f blue:.7f alpha:.04f].CGColor,(id)[UIColor colorWithRed:.7f green:.6f blue:1 alpha:.06f].CGColor];
    chr.cornerRadius=p.cornerRadius;
    CAShapeLayer *cm=[CAShapeLayer layer]; UIBezierPath *co=[UIBezierPath bezierPathWithRoundedRect:v.bounds cornerRadius:p.cornerRadius];
    UIBezierPath *ci2=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(v.bounds,1.5f,1.5f) cornerRadius:MAX(0,p.cornerRadius-1.5f)];
    [co appendPath:ci2]; co.usesEvenOddFillRule=YES; cm.path=co.CGPath; cm.fillRule=kCAFillRuleEvenOdd; chr.mask=cm; [v.layer addSublayer:chr];
    v.layer.cornerRadius=p.cornerRadius;
    if (@available(iOS 13.0,*)) v.layer.cornerCurve=kCACornerCurveContinuous;
    v.layer.borderWidth=0.5f; v.layer.borderColor=[UIColor colorWithWhite:1 alpha:p.borderAlpha].CGColor;
    v.layer.shadowColor=[UIColor blackColor].CGColor; v.layer.shadowRadius=p.shadowRadius;
    v.layer.shadowOpacity=p.shadowOpacity; v.layer.shadowOffset=CGSizeMake(0,4);
}


// Logging a /var/mobile/Media/ — SpringBoard puede escribir aquí
static void lgLog(const char *msg) {
    FILE *f = fopen(LOG_PATH, "a");
    if (f) {
        time_t t = time(NULL); struct tm *tm = localtime(&t);
        fprintf(f, "[%02d:%02d:%02d] %s\n", tm->tm_hour, tm->tm_min, tm->tm_sec, msg);
        fclose(f);
    }
}

static void hookMethod(const char *cls, SEL sel, IMP imp, IMP *orig) {
    Class c = objc_getClass(cls);
    if (!c) { return; }
    Method m = class_getInstanceMethod(c, sel);
    if (!m) { return; }
    if (orig) *orig = method_getImplementation(m);
    method_setImplementation(m, imp);
}

#define HOOK(cls, sel, hook, orig) do { \
    Method _m = class_getInstanceMethod(cls, sel); \
    if (_m) { orig = (void *)method_getImplementation(_m); method_setImplementation(_m, (IMP)hook); } \
} while(0)


@interface CCUIModularControlCenterOverlayViewController : UIViewController @end
@interface CCUIContentModuleContentContainerView : UIView @end
@interface UIView (CCPrivate)
- (UIViewController *)_viewControllerForAncestor;
@end
@interface CALayer (CCPrivate2)
@property (assign) BOOL continuousCorners;
@end

@interface CALayer (ALGPrivate)
@property (assign) BOOL continuousCorners;
@end

@interface NCNotificationRequest : NSObject
@property (nonatomic,copy,readonly) NSString *sectionIdentifier;
@end

@interface NCBadgedIconView : UIView
@property (nonatomic,retain) UIView *iconView;
@end

@interface NCNotificationSeamlessContentView : UIView
@property (nonatomic,copy) UIImage *prominentIcon;
@property (nonatomic,copy) UIImage *subordinateIcon;
@end

@interface NCNotificationShortLookView : UIView
@property (nonatomic,readonly) UIView *backgroundMaterialView;
@end

@interface NCNotificationShortLookViewController : UIViewController
@property (nonatomic,readonly) UIView *viewForPreview;
@property (nonatomic,retain) NCNotificationRequest *notificationRequest;
@end

@interface NCNotificationSummaryPlatterView : UIView
@end

// ─────────────────────────────────────────
// PASSTHROUGH WINDOW
// ─────────────────────────────────────────
@interface ALGPassthroughWindow : UIWindow
@end
@implementation ALGPassthroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *rootView = self.rootViewController.view;
    CGPoint p = [rootView convertPoint:point fromView:self];
    UIView *hit = [rootView hitTest:p withEvent:event];
    if (!hit || hit == rootView) return nil;
    return hit;
}
@end

// ─────────────────────────────────────────
// BLOCK BUTTON — UIButton que ejecuta un bloque
// ─────────────────────────────────────────
@interface ALGBlockButton : UIButton
@property (nonatomic, copy) void (^actionBlock)(void);
@end
@implementation ALGBlockButton
- (void)handleTap { if (self.actionBlock) self.actionBlock(); }
@end

// ─────────────────────────────────────────
// SCROLL PROXY — UIScrollViewDelegate sin Substrate
// ─────────────────────────────────────────
@interface ALGScrollProxy : NSObject <UIScrollViewDelegate>
@property (nonatomic, copy) void (^onScroll)(UIScrollView *);
@end
@implementation ALGScrollProxy
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.onScroll) self.onScroll(scrollView);
}
@end

// ═══════════════════════════════════════════════════════════════
// HSB Color Wheel — interactive color picker
// ═══════════════════════════════════════════════════════════════
@interface ALGColorWheel : UIView
@property (nonatomic, copy) void (^onColorChanged)(UIColor *color);
@property (nonatomic, strong) UIColor *selectedColor;
@property (nonatomic, strong) UIView *indicator;
@property (nonatomic, assign) CGFloat curHue;
@property (nonatomic, assign) CGFloat curSat;
@end
@implementation ALGColorWheel
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _curHue = 0.55f; _curSat = 0.8f;
        _selectedColor = [UIColor colorWithHue:0.55f saturation:0.8f brightness:1 alpha:1];
        _indicator = [[UIView alloc] initWithFrame:CGRectMake(0,0,16,16)];
        _indicator.layer.cornerRadius = 8;
        _indicator.layer.borderWidth = 2.5f;
        _indicator.layer.borderColor = [UIColor whiteColor].CGColor;
        _indicator.layer.shadowColor = [UIColor blackColor].CGColor;
        _indicator.layer.shadowRadius = 3; _indicator.layer.shadowOpacity = 0.6f;
        _indicator.layer.shadowOffset = CGSizeZero;
        _indicator.userInteractionEnabled = NO;
        [self addSubview:_indicator];
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext(); if (!ctx) return;
    CGFloat cx = rect.size.width/2, cy = rect.size.height/2;
    CGFloat outerR = MIN(cx,cy) - 2, innerR = outerR * 0.28f;
    for (int i = 0; i < 360; i++) {
        CGFloat a1 = (float)i/360.0f*2*M_PI, a2 = (float)(i+1)/360.0f*2*M_PI;
        for (int ring = 0; ring < 5; ring++) {
            CGFloat rO = outerR - ring*(outerR-innerR)/5.0f;
            CGFloat rI = outerR - (ring+1)*(outerR-innerR)/5.0f;
            CGFloat sat = 1.0f - (float)ring/5.0f;
            UIColor *c = [UIColor colorWithHue:(float)i/360.0f saturation:sat brightness:1 alpha:1];
            CGContextSetFillColorWithColor(ctx, c.CGColor);
            UIBezierPath *p = [UIBezierPath bezierPath];
            [p moveToPoint:CGPointMake(cx+rI*cosf(a1), cy+rI*sinf(a1))];
            [p addLineToPoint:CGPointMake(cx+rO*cosf(a1), cy+rO*sinf(a1))];
            [p addLineToPoint:CGPointMake(cx+rO*cosf(a2), cy+rO*sinf(a2))];
            [p addLineToPoint:CGPointMake(cx+rI*cosf(a2), cy+rI*sinf(a2))];
            [p closePath]; [p fill];
        }
    }
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(cx-innerR, cy-innerR, innerR*2, innerR*2));
}
- (void)layoutSubviews { [super layoutSubviews]; [self moveIndicator]; }
- (void)moveIndicator {
    CGFloat cx=self.bounds.size.width/2, cy=self.bounds.size.height/2;
    CGFloat outerR=MIN(cx,cy)-2, innerR=outerR*0.28f;
    CGFloat angle=self.curHue*2*M_PI;
    CGFloat dist=innerR + self.curSat*(outerR-innerR);
    dist=MAX(innerR,MIN(dist,outerR));
    self.indicator.center = CGPointMake(cx+dist*cosf(angle), cy+dist*sinf(angle));
    self.indicator.backgroundColor = self.selectedColor;
}
- (void)handleTouch:(CGPoint)pt {
    CGFloat cx=self.bounds.size.width/2, cy=self.bounds.size.height/2;
    CGFloat outerR=MIN(cx,cy)-2, innerR=outerR*0.28f;
    CGFloat dx=pt.x-cx, dy=pt.y-cy, dist=sqrtf(dx*dx+dy*dy);
    if (dist < 1) return;
    CGFloat angle = atan2f(dy,dx); if (angle<0) angle+=2*M_PI;
    self.curHue = angle/(2*M_PI);
    self.curSat = MAX(0,MIN(1,(dist-innerR)/(outerR-innerR)));
    self.selectedColor = [UIColor colorWithHue:self.curHue saturation:MAX(0.05f,self.curSat) brightness:1 alpha:1];
    [self moveIndicator];
    if (self.onColorChanged) self.onColorChanged(self.selectedColor);
}
- (void)touchesBegan:(NSSet*)t withEvent:(UIEvent*)e { [self handleTouch:[[t anyObject] locationInView:self]]; }
- (void)touchesMoved:(NSSet*)t withEvent:(UIEvent*)e { [self handleTouch:[[t anyObject] locationInView:self]]; }
@end
// ─────────────────────────────────────────
// Prefs via NSUserDefaults — SpringBoard
#define ALG_SUITE @"com.aldazdev.Twe3akL0aders"

static NSMutableDictionary *ALGPrefs(void) {
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:ALG_SUITE];
    NSDictionary *all = [ud dictionaryRepresentation];
    // Filtrar NSNull y valores Apple internos que crashean
    NSMutableDictionary *filtered = [NSMutableDictionary dictionary];
    for (NSString *k in all) {
        id v = all[k];
        if (v && ![v isKindOfClass:[NSNull class]] &&
            ([k hasPrefix:@"enabled"] || [k hasPrefix:@"anim"] ||
             [k hasPrefix:@"icon"] || [k hasPrefix:@"page"] ||
             [k hasPrefix:@"batt"] || [k hasPrefix:@"glass"] ||
             [k hasPrefix:@"notif"] || [k hasPrefix:@"banner"] ||
             [k hasPrefix:@"terminal"]))
            filtered[k] = v;
    }
    NSMutableDictionary *d = filtered.count > 1 ? filtered : nil;
    if (!d) d = [NSMutableDictionary dictionaryWithDictionary:@{
        @"enabled":    @YES,
        @"animations": @YES,
        @"pageAnim":   @(0),   // 0=cube 1=wave 2=tilt 3=fade
        @"iconRadius": @(27.0f),
    }];
    return d;
}
static void ALGSavePrefs(NSMutableDictionary *d) {
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:ALG_SUITE];
    for (NSString *k in d) [ud setObject:d[k] forKey:k];
    [ud synchronize];
}

static CGFloat gIconRadius   = 27.0f;
static BOOL    gAnimations   = YES;
static BOOL    gGlassEnabled = YES;
static NSInteger gPageAnim   = 0; 
static NSInteger gBatteryStyle   = 0;
static BOOL    gPageAnimEnabled = YES;
static BOOL    gIconRound       = YES;
static BOOL    gBannerGlass     = YES;
static BOOL    gBatteryCustom   = NO;
static BOOL    gTerminalEnabled = NO;

static void ALGLoadPrefs(void) {
    NSMutableDictionary *p = ALGPrefs();
    gIconRadius    = [p[@"iconRadius"] floatValue];
    gAnimations    = [p[@"animations"] boolValue];
    gGlassEnabled  = [p[@"enabled"] boolValue];
    gPageAnim      = [p[@"pageAnim"] integerValue];
    gBatteryStyle    = [p[@"batteryStyle"] integerValue];
    gPageAnimEnabled = p[@"pageAnimEnabled"] ? [p[@"pageAnimEnabled"] boolValue] : YES;
    gIconRound       = p[@"iconRound"]       ? [p[@"iconRound"] boolValue]       : YES;
    gBannerGlass     = p[@"bannerGlass"]     ? [p[@"bannerGlass"] boolValue]     : YES;
    gBatteryCustom   = p[@"batteryCustom"]   ? [p[@"batteryCustom"] boolValue]   : NO;
    gTerminalEnabled = p[@"terminalEnabled"] ? [p[@"terminalEnabled"] boolValue] : NO;
}


static ALGPassthroughWindow *gSettingsWindow = nil;

#define ALG_ACCENT     [UIColor colorWithRed:0.22f green:0.55f blue:1.0f alpha:1.0f]
#define ALG_WARN       [UIColor colorWithRed:1.0f green:0.55f blue:0.2f alpha:1.0f]
#define ALG_RED        [UIColor colorWithRed:0.85f green:0.22f blue:0.22f alpha:1.0f]
#define ALG_GREEN      [UIColor colorWithRed:0.2f green:0.72f blue:0.45f alpha:1.0f]

static void ALGClosePanel(void) {
    if (!gSettingsWindow || gSettingsWindow.hidden) return;
    UIView *panel = [gSettingsWindow.rootViewController.view viewWithTag:9999];
    UIView *dim = [gSettingsWindow.rootViewController.view viewWithTag:9998];
    [UIView animateWithDuration:0.25f animations:^{
        panel.alpha = 0; panel.transform = CGAffineTransformMakeScale(0.92f,0.92f);
        if (dim) dim.alpha = 0;
    } completion:^(BOOL d) {
        gSettingsWindow.hidden = YES;
        gSettingsWindow.userInteractionEnabled = NO;
    }];
}

// ── Glass panel factory ──
static UIView *ALGMakeGlassPanel(CGRect frame) {
    UIView *p = [[UIView alloc] initWithFrame:frame];
    p.backgroundColor = [UIColor clearColor];
    p.layer.cornerRadius = 28; p.clipsToBounds = YES;
    if (@available(iOS 13.0,*)) p.layer.cornerCurve = kCACornerCurveContinuous;
    // Blur
    UIBlurEffect *bl;
    if (@available(iOS 13.0,*)) bl=[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    else bl=[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *bv=[[UIVisualEffectView alloc] initWithEffect:bl];
    bv.frame=p.bounds; bv.userInteractionEnabled=NO; [p addSubview:bv];
    // Tint
    UIView *t=[[UIView alloc] initWithFrame:p.bounds];
    t.backgroundColor=[UIColor colorWithRed:0.03f green:0.03f blue:0.11f alpha:0.60f];
    t.userInteractionEnabled=NO; [p addSubview:t];
    // Top specular
    CAGradientLayer *sp=[CAGradientLayer layer]; sp.frame=p.bounds;
    sp.colors=@[(id)[UIColor colorWithWhite:1 alpha:0.09f].CGColor,
                (id)[UIColor colorWithWhite:1 alpha:0].CGColor];
    sp.locations=@[@0,@0.4f]; [p.layer addSublayer:sp];
    // Border
    CAGradientLayer *bd=[CAGradientLayer layer]; bd.frame=p.bounds;
    bd.colors=@[(id)[UIColor colorWithWhite:1 alpha:0.35f].CGColor,
                (id)[UIColor colorWithWhite:1 alpha:0.05f].CGColor,
                (id)[UIColor colorWithWhite:1 alpha:0.12f].CGColor];
    bd.locations=@[@0,@0.5f,@1];
    CAShapeLayer *bm=[CAShapeLayer layer];
    UIBezierPath *bo=[UIBezierPath bezierPathWithRoundedRect:p.bounds cornerRadius:28];
    UIBezierPath *bi=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(p.bounds,0.6f,0.6f) cornerRadius:27.4f];
    [bo appendPath:bi]; bo.usesEvenOddFillRule=YES;
    bm.path=bo.CGPath; bm.fillRule=kCAFillRuleEvenOdd;
    bd.mask=bm; [p.layer addSublayer:bd];
    return p;
}

// ── Row builder ──
static UIView *ALGRow(CGFloat y, CGFloat w, CGFloat h) {
    UIView *r=[[UIView alloc] initWithFrame:CGRectMake(12,y,w-24,h)];
    r.backgroundColor=[UIColor colorWithWhite:1 alpha:0.045f];
    r.layer.cornerRadius=13;
    if (@available(iOS 13.0,*)) r.layer.cornerCurve=kCACornerCurveContinuous;
    r.userInteractionEnabled=YES;
    return r;
}

// ── Section header ──
static UILabel *ALGSection(NSString *text, CGFloat y, CGFloat w) {
    UILabel *l=[[UILabel alloc] initWithFrame:CGRectMake(20,y,w-40,16)];
    l.text=[text uppercaseString];
    l.font=[UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    l.textColor=[UIColor colorWithWhite:1 alpha:0.32f];
    l.userInteractionEnabled=NO;
    return l;
}

// ── Row with toggle ──
static void ALGRowToggle(UIView *row, NSString *title, NSString *icon, BOOL on, NSInteger tag) {
    CGFloat rw=row.bounds.size.width, rh=row.bounds.size.height;
    CGFloat lx = 14;
    if (@available(iOS 13.0,*)) {
        UIImage *im=[UIImage systemImageNamed:icon
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]];
        UIImageView *iv=[[UIImageView alloc] initWithImage:im];
        iv.frame=CGRectMake(14,(rh-20)/2,20,20);
        iv.tintColor=[UIColor colorWithWhite:1 alpha:0.5f];
        iv.contentMode=UIViewContentModeScaleAspectFit;
        iv.userInteractionEnabled=NO; [row addSubview:iv];
        lx = 42;
    }
    UILabel *lb=[[UILabel alloc] initWithFrame:CGRectMake(lx,0,rw-lx-68,rh)];
    lb.text=title; lb.font=[UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    lb.textColor=[UIColor whiteColor]; lb.userInteractionEnabled=NO;
    [row addSubview:lb];
    UISwitch *sw=[[UISwitch alloc] initWithFrame:CGRectMake(rw-62,(rh-31)/2,51,31)];
    sw.on=on; sw.onTintColor=ALG_ACCENT; sw.tag=tag;
    [row addSubview:sw];
}

// ── Nav card button ──
static ALGBlockButton *ALGNavCard(NSString *title, NSString *icon, NSString *sub, CGFloat y, CGFloat w, UIColor *iconColor) {
    ALGBlockButton *b=[ALGBlockButton buttonWithType:UIButtonTypeCustom];
    b.frame=CGRectMake(12,y,w-24,58);
    b.backgroundColor=[UIColor colorWithWhite:1 alpha:0.045f];
    b.layer.cornerRadius=14;
    if (@available(iOS 13.0,*)) b.layer.cornerCurve=kCACornerCurveContinuous;
    if (@available(iOS 13.0,*)){
        UIImage *im=[UIImage systemImageNamed:icon
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold]];
        UIImageView *iv=[[UIImageView alloc] initWithImage:im];
        iv.frame=CGRectMake(16,18,22,22);
        iv.tintColor=iconColor ?: ALG_ACCENT;
        iv.contentMode=UIViewContentModeScaleAspectFit;
        iv.userInteractionEnabled=NO; [b addSubview:iv];
    }
    UILabel *lb=[[UILabel alloc] initWithFrame:CGRectMake(48,sub?10:0,w-24-80,sub?22:58)];
    lb.text=title; lb.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    lb.textColor=[UIColor whiteColor]; lb.userInteractionEnabled=NO;
    [b addSubview:lb];
    if (sub) {
        UILabel *s=[[UILabel alloc] initWithFrame:CGRectMake(48,30,w-24-80,16)];
        s.text=sub; s.font=[UIFont systemFontOfSize:11]; s.textColor=[UIColor colorWithWhite:1 alpha:0.38f];
        s.userInteractionEnabled=NO; [b addSubview:s];
    }
    if (@available(iOS 13.0,*)){
        UIImage *ch=[UIImage systemImageNamed:@"chevron.right"
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightMedium]];
        UIImageView *cv=[[UIImageView alloc] initWithImage:ch];
        cv.frame=CGRectMake(w-24-28,21,14,14);
        cv.tintColor=[UIColor colorWithWhite:1 alpha:0.22f];
        cv.userInteractionEnabled=NO; [b addSubview:cv];
    }
    return b;
}

// ── Action button ──
static ALGBlockButton *ALGActionBtn(NSString *title, UIColor *color, CGFloat y, CGFloat w) {
    ALGBlockButton *b=[ALGBlockButton buttonWithType:UIButtonTypeCustom];
    b.frame=CGRectMake(12,y,w-24,44);
    b.layer.cornerRadius=14;
    if (@available(iOS 13.0,*)) b.layer.cornerCurve=kCACornerCurveContinuous;
    UIVisualEffectView *bv=[[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    bv.frame=b.bounds; bv.layer.cornerRadius=14; bv.layer.masksToBounds=YES;
    bv.userInteractionEnabled=NO; [b addSubview:bv];
    CGFloat r,g2,b2,a; [color getRed:&r green:&g2 blue:&b2 alpha:&a];
    CAGradientLayer *gl=[CAGradientLayer layer]; gl.frame=b.bounds; gl.cornerRadius=14;
    gl.colors=@[(id)[UIColor colorWithRed:r green:g2 blue:b2 alpha:0.72f].CGColor,
                (id)[UIColor colorWithRed:r*0.65f green:g2*0.65f blue:b2*0.65f alpha:0.5f].CGColor];
    gl.startPoint=CGPointMake(0,0); gl.endPoint=CGPointMake(1,1);
    [b.layer addSublayer:gl];
    b.layer.borderWidth=0.5f; b.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.15f].CGColor;
    UILabel *lb=[[UILabel alloc] initWithFrame:b.bounds];
    lb.text=title; lb.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    lb.textColor=[UIColor whiteColor]; lb.textAlignment=NSTextAlignmentCenter;
    lb.userInteractionEnabled=NO; [b addSubview:lb];
    return b;
}

// ── Toast ──
static void ALGToast(UIView *parent, NSString *text, BOOL ok) {
    UILabel *t=[[UILabel alloc] init];
    t.text=text; t.font=[UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    t.textColor=[UIColor whiteColor];
    t.backgroundColor=ok?ALG_GREEN:ALG_RED;
    t.textAlignment=NSTextAlignmentCenter;
    t.layer.cornerRadius=16; t.clipsToBounds=YES;
    [t sizeToFit];
    CGFloat tw=t.bounds.size.width+32;
    t.frame=CGRectMake((parent.bounds.size.width-tw)/2,12,tw,32);
    t.alpha=0; [parent addSubview:t];
    [UIView animateWithDuration:0.2f animations:^{t.alpha=1;} completion:^(BOOL d){
        [UIView animateWithDuration:0.3f delay:1.8f options:0 animations:^{t.alpha=0;}
            completion:^(BOOL d2){[t removeFromSuperview];}];
    }];
}

// ── Respring ──
static void ALGDoRespring(void) {
    Class fbsCls=NSClassFromString(@"FBSSystemService");
    if (fbsCls) {
        SEL ss=NSSelectorFromString(@"sharedService");
        SEL rs=NSSelectorFromString(@"exitAndRelaunch:");
        if ([fbsCls respondsToSelector:ss]) {
            id svc=((id(*)(id,SEL))objc_msgSend)(fbsCls,ss);
            if (svc && [svc respondsToSelector:rs]) {
                ((void(*)(id,SEL,BOOL))objc_msgSend)(svc,rs,YES); return;
            }
        }
    }
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [[UIApplication sharedApplication] performSelector:NSSelectorFromString(@"terminateWithSuccess")];
    #pragma clang diagnostic pop
}

// ── Navigation push/pop ──
static NSInteger gNavDepth = 0;
static void ALGPush(UIView *container, UIView *page, CGFloat pw) {
    page.frame=CGRectMake(pw,0,container.bounds.size.width,container.bounds.size.height);
    page.tag=9900+(++gNavDepth);
    // Dar fondo opaco a la nueva pagina para que no se vea la anterior
    page.backgroundColor=[UIColor colorWithRed:0.02f green:0.02f blue:0.08f alpha:1.0f];
    [container addSubview:page];
    [UIView animateWithDuration:0.32f delay:0 usingSpringWithDamping:0.88f initialSpringVelocity:0.5f
        options:UIViewAnimationOptionAllowUserInteraction animations:^{
        for (UIView *v in container.subviews)
            if (v.tag>=9900 && v.tag<page.tag)
                v.frame=CGRectMake(-pw*0.3f,0,v.bounds.size.width,v.bounds.size.height);
        page.frame=CGRectMake(0,0,container.bounds.size.width,container.bounds.size.height);
    } completion:^(BOOL d){
        // Ocultar paginas anteriores completamente
        for (UIView *v in container.subviews)
            if (v.tag>=9900 && v.tag<page.tag) v.hidden=YES;
    }];
}

static void ALGPop(UIView *container, CGFloat pw) {
    UIView *top=nil, *prev=nil;
    for (UIView *v in container.subviews) {
        if (v.tag>=9900) {
            if (!top||v.tag>top.tag){prev=top;top=v;}
            else if(!prev||v.tag>prev.tag) prev=v;
        }
    }
    if (!top) return;
    gNavDepth--;
    // Mostrar y posicionar la pagina anterior antes de animar
    if (prev) {
        prev.hidden=NO;
        prev.frame=CGRectMake(-pw*0.3f,0,prev.bounds.size.width,prev.bounds.size.height);
    }
    [UIView animateWithDuration:0.28f delay:0 usingSpringWithDamping:0.9f initialSpringVelocity:0.4f
        options:UIViewAnimationOptionAllowUserInteraction animations:^{
        top.frame=CGRectMake(pw,0,top.bounds.size.width,top.bounds.size.height);
        if (prev) prev.frame=CGRectMake(0,0,prev.bounds.size.width,prev.bounds.size.height);
    } completion:^(BOOL d){[top removeFromSuperview];}];
}

// ── Page header with back button ──
static UIView *ALGPageHeader(NSString *title, CGFloat w, UIView *navContainer, CGFloat pw) {
    UIView *hdr=[[UIView alloc] initWithFrame:CGRectMake(0,0,w,48)];
    hdr.backgroundColor=[UIColor clearColor];
    // Separator
    CAGradientLayer *sep=[CAGradientLayer layer]; sep.frame=CGRectMake(0,47.5f,w,0.5f);
    sep.colors=@[(id)[UIColor colorWithWhite:1 alpha:0].CGColor,
                 (id)[UIColor colorWithWhite:1 alpha:0.18f].CGColor,
                 (id)[UIColor colorWithWhite:1 alpha:0].CGColor];
    sep.startPoint=CGPointMake(0,0.5f); sep.endPoint=CGPointMake(1,0.5f);
    [hdr.layer addSublayer:sep];
    // Back button
    ALGBlockButton *back=[ALGBlockButton buttonWithType:UIButtonTypeCustom];
    back.frame=CGRectMake(4,6,60,36);
    if (@available(iOS 13.0,*)){
        UIImage *ch=[UIImage systemImageNamed:@"chevron.left"
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold]];
        UIImageView *cv=[[UIImageView alloc] initWithImage:ch];
        cv.frame=CGRectMake(12,10,14,16);
        cv.tintColor=ALG_ACCENT; cv.userInteractionEnabled=NO;
        [back addSubview:cv];
    }
    __weak UIView *wc=navContainer;
    back.actionBlock=^{ ALGPop(wc,pw); };
    [back addTarget:back action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    [hdr addSubview:back];
    // Title
    UILabel *lb=[[UILabel alloc] initWithFrame:CGRectMake(60,6,w-120,36)];
    lb.text=title; lb.font=[UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    lb.textColor=[UIColor whiteColor]; lb.textAlignment=NSTextAlignmentCenter;
    lb.userInteractionEnabled=NO; [hdr addSubview:lb];
    return hdr;
}

// ═══════════════════════════════════════════════════════════════
// SETTINGS PANEL — Navigation Stack
// ═══════════════════════════════════════════════════════════════

static void ALGShowSettingsPanel(void) {
    if (gSettingsWindow && !gSettingsWindow.hidden) { ALGClosePanel(); return; }

    if (!gSettingsWindow) {
        UIWindowScene *scene=nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if ([s isKindOfClass:[UIWindowScene class]]){scene=(UIWindowScene*)s;break;}
        if (@available(iOS 13.0,*))
            gSettingsWindow=[[ALGPassthroughWindow alloc] initWithWindowScene:scene];
        else
            gSettingsWindow=[[ALGPassthroughWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        gSettingsWindow.windowLevel=UIWindowLevelNormal+10;
        gSettingsWindow.backgroundColor=[UIColor clearColor];
        UIViewController *vc=[[UIViewController alloc] init];
        vc.view.backgroundColor=[UIColor clearColor];
        vc.view.userInteractionEnabled=YES;
        gSettingsWindow.rootViewController=vc;
    }

    CGRect sb=[UIScreen mainScreen].bounds;
    gSettingsWindow.frame=sb;
    UIView *rootView=gSettingsWindow.rootViewController.view;
    rootView.frame=sb;
    for (UIView *v in [rootView.subviews copy]) [v removeFromSuperview];
    gNavDepth=0;

    NSMutableDictionary *prefs=ALGPrefs();
    CGFloat screenW=sb.size.width, screenH=sb.size.height;
    CGFloat panelW=MIN(screenW-32,340);
    CGFloat panelH=MIN(screenH*0.82f,620);
    CGFloat panelX=(screenW-panelW)/2, panelY=(screenH-panelH)/2;

    // Dim background
    UIView *dim=[[UIView alloc] initWithFrame:sb];
    dim.backgroundColor=[UIColor colorWithWhite:0 alpha:0.35f];
    dim.tag=9998; dim.alpha=0;
    ALGBlockButton *dimBtn=[ALGBlockButton buttonWithType:UIButtonTypeCustom];
    dimBtn.frame=dim.bounds;
    dimBtn.actionBlock=^{ ALGClosePanel(); };
    [dimBtn addTarget:dimBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    [dim addSubview:dimBtn];
    [rootView addSubview:dim];

    // Shadow
    UIView *shd=[[UIView alloc] initWithFrame:CGRectMake(panelX,panelY,panelW,panelH)];
    shd.backgroundColor=[UIColor clearColor];
    shd.layer.cornerRadius=28;
    shd.layer.shadowColor=[UIColor colorWithRed:0.1f green:0.2f blue:0.8f alpha:0.5f].CGColor;
    shd.layer.shadowOpacity=0.8f; shd.layer.shadowRadius=28; shd.layer.shadowOffset=CGSizeMake(0,10);
    shd.userInteractionEnabled=NO;
    [rootView addSubview:shd];

    // Panel
    UIView *panel=ALGMakeGlassPanel(CGRectMake(panelX,panelY,panelW,panelH));
    panel.tag=9999;

    // Navigation container (clips subpages)
    UIView *navContainer=[[UIView alloc] initWithFrame:CGRectMake(0,0,panelW,panelH)];
    navContainer.clipsToBounds=YES;
    navContainer.userInteractionEnabled=YES;
    [panel addSubview:navContainer];

    // ════════════════════════════
    // HOME PAGE
    // ════════════════════════════
    UIView *home=[[UIView alloc] initWithFrame:CGRectMake(0,0,panelW,panelH)];
    home.tag=9900; home.userInteractionEnabled=YES;
    {
        // Header
        UIView *pill=[[UIView alloc] initWithFrame:CGRectMake((panelW-36)/2,8,36,4)];
        pill.backgroundColor=[UIColor colorWithWhite:1 alpha:0.2f];
        pill.layer.cornerRadius=2; [home addSubview:pill];

        UILabel *ttl=[[UILabel alloc] initWithFrame:CGRectMake(0,20,panelW,24)];
        ttl.text=@"Tweaks Loader";
        ttl.font=[UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        ttl.textColor=[UIColor whiteColor]; ttl.textAlignment=NSTextAlignmentCenter;
        ttl.userInteractionEnabled=NO; [home addSubview:ttl];

        UILabel *sub=[[UILabel alloc] initWithFrame:CGRectMake(0,44,panelW,14)];
        sub.text=@"by AldazDev";
        sub.font=[UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
        sub.textColor=[UIColor colorWithWhite:1 alpha:0.3f];
        sub.textAlignment=NSTextAlignmentCenter;
        sub.userInteractionEnabled=NO; [home addSubview:sub];

        // Separator
        CAGradientLayer *hs=[CAGradientLayer layer]; hs.frame=CGRectMake(0,65,panelW,0.5f);
        hs.colors=@[(id)[UIColor colorWithWhite:1 alpha:0].CGColor,
                     (id)[UIColor colorWithWhite:1 alpha:0.18f].CGColor,
                     (id)[UIColor colorWithWhite:1 alpha:0].CGColor];
        hs.startPoint=CGPointMake(0,0.5f); hs.endPoint=CGPointMake(1,0.5f);
        [home.layer addSublayer:hs];

        // Close button
        ALGBlockButton *xBtn=[ALGBlockButton buttonWithType:UIButtonTypeCustom];
        xBtn.frame=CGRectMake(panelW-44,12,34,34);
        xBtn.layer.cornerRadius=17;
        xBtn.backgroundColor=[UIColor colorWithWhite:1 alpha:0.08f];
        UILabel *xL=[[UILabel alloc] initWithFrame:CGRectMake(0,0,34,34)];
        xL.text=@"\u2715"; xL.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        xL.textColor=[UIColor colorWithWhite:1 alpha:0.45f];
        xL.textAlignment=NSTextAlignmentCenter; xL.userInteractionEnabled=NO;
        [xBtn addSubview:xL];
        xBtn.actionBlock=^{ALGClosePanel();};
        [xBtn addTarget:xBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [home addSubview:xBtn];

        // ── Nav cards ──
        CGFloat cy=80;

        ALGBlockButton *c1=ALGNavCard(@"General",@"slider.horizontal.3",@"Features, icons, glass effects",cy,panelW,ALG_ACCENT);
        __weak UIView *wnc=navContainer;
        c1.actionBlock=^{
            // ── GENERAL SUBPAGE ──
            UIView *pg=[[UIView alloc] initWithFrame:CGRectMake(0,0,panelW,panelH)];
            pg.backgroundColor=[UIColor clearColor]; pg.userInteractionEnabled=YES;

            UIView *hdr=ALGPageHeader(@"General",panelW,wnc,panelW);
            [pg addSubview:hdr];

            UIScrollView *sc=[[UIScrollView alloc] initWithFrame:CGRectMake(0,48,panelW,panelH-48)];
            sc.showsVerticalScrollIndicator=NO; sc.bounces=YES;
            [pg addSubview:sc];

            CGFloat y=12;
            [sc addSubview:ALGSection(@"Features",y,panelW)]; y+=22;

            NSArray *fN=@[@"Dock animations",@"Round icons",@"Banner glass",@"Custom battery",@"Terminal"];
            NSArray *fK=@[@"animations",@"iconRound",@"bannerGlass",@"batteryCustom",@"terminalEnabled"];
            NSArray *fI=@[@"dock.rectangle",@"app.badge",@"sparkles",@"battery.75",@"terminal"];
            BOOL fD[]={YES,YES,YES,NO,NO};
            for (NSInteger i=0;i<(NSInteger)fN.count;i++){
                UIView *row=ALGRow(y,panelW,46);
                ALGRowToggle(row,fN[i],fI[i],
                    prefs[fK[i]]?[prefs[fK[i]] boolValue]:fD[i], 6000+i);
                [sc addSubview:row]; y+=52;
            }

            y+=8;
            [sc addSubview:ALGSection(@"Icon Roundness",y,panelW)]; y+=22;
            UIView *slBg=ALGRow(y,panelW,64);
            // Preview
            UIView *prev=[[UIView alloc] initWithFrame:CGRectMake(slBg.bounds.size.width-52,14,36,36)];
            prev.backgroundColor=ALG_ACCENT;
            prev.layer.cornerRadius=[prefs[@"iconRadius"] floatValue];
            if (@available(iOS 13.0,*)) prev.layer.cornerCurve=kCACornerCurveContinuous;
            prev.userInteractionEnabled=NO; prev.tag=3001;
            [slBg addSubview:prev];
            // Slider
            UISlider *sld=[[UISlider alloc] initWithFrame:CGRectMake(14,20,slBg.bounds.size.width-80,28)];
            sld.minimumValue=0; sld.maximumValue=36; sld.value=[prefs[@"iconRadius"] floatValue];
            sld.minimumTrackTintColor=ALG_ACCENT; sld.tag=2002;
            ALGBlockButton *slP=[ALGBlockButton new];
            __weak UISlider *ws=sld; __weak UIView *wsl=slBg;
            slP.actionBlock=^{
                UIView *pv=[wsl viewWithTag:3001];
                pv.layer.cornerRadius=ws.value;
                gIconRadius=ws.value;
            };
            [sld addTarget:slP action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];
            objc_setAssociatedObject(sld,"p",slP,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [slBg addSubview:sld];
            [sc addSubview:slBg]; y+=74;

            // Save button
            y+=12;
            ALGBlockButton *saveBtn=ALGActionBtn(@"Save & Apply",ALG_ACCENT,y,panelW);
            __weak UIScrollView *wsc=sc;
            saveBtn.actionBlock=^{
                NSMutableDictionary *p=ALGPrefs();
                for (NSInteger i=0;i<(NSInteger)fK.count;i++){
                    UISwitch *sw=(UISwitch*)[wsc viewWithTag:6000+i];
                    if (sw) p[fK[i]]=@(sw.on);
                }
                UISlider *sl2=(UISlider*)[wsc viewWithTag:2002];
                if (sl2) p[@"iconRadius"]=@(sl2.value);
                ALGSavePrefs(p); ALGLoadPrefs();
                if (@available(iOS 10.0,*)){
                    UINotificationFeedbackGenerator *gen=[[UINotificationFeedbackGenerator alloc] init];
                    [gen notificationOccurred:UINotificationFeedbackTypeSuccess];
                }
                ALGToast(pg,@"Saved!",YES);
            };
            [saveBtn addTarget:saveBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
            [sc addSubview:saveBtn]; y+=56;
            sc.contentSize=CGSizeMake(panelW,y+20);

            ALGPush(wnc,pg,panelW);
        };
        [c1 addTarget:c1 action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [home addSubview:c1]; cy+=66;

        ALGBlockButton *c2=ALGNavCard(@"Animations",@"wand.and.stars",@"Page scroll effects",cy,panelW,
            [UIColor colorWithRed:0.6f green:0.3f blue:1 alpha:1]);
        c2.actionBlock=^{
            // ── ANIMATIONS SUBPAGE ──
            UIView *pg=[[UIView alloc] initWithFrame:CGRectMake(0,0,panelW,panelH)];
            pg.backgroundColor=[UIColor clearColor]; pg.userInteractionEnabled=YES;
            [pg addSubview:ALGPageHeader(@"Animations",panelW,wnc,panelW)];

            CGFloat y=60;
            [pg addSubview:ALGSection(@"Page Scroll Style",y,panelW)]; y+=22;

            NSArray *aN=@[@"Cube",@"Wave",@"Tilt 3D",@"Fade",@"Spiral",@"Float",@"Smooth",@"None"];
            CGFloat bw=(panelW-36)/4.0f;
            for (NSInteger i=0;i<8;i++){
                CGFloat bx=14+(i%4)*bw;
                CGFloat by=y+(i/4)*40;
                ALGBlockButton *ab=[ALGBlockButton buttonWithType:UIButtonTypeCustom];
                ab.frame=CGRectMake(bx,by,bw-4,34);
                [ab setTitle:aN[i] forState:UIControlStateNormal];
                ab.titleLabel.font=[UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
                BOOL sel=[prefs[@"pageAnim"] integerValue]==i;
                ab.backgroundColor=sel?ALG_ACCENT:[UIColor colorWithWhite:1 alpha:0.08f];
                [ab setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                ab.layer.cornerRadius=10; ab.tag=4000+i;
                if (@available(iOS 13.0,*)) ab.layer.cornerCurve=kCACornerCurveContinuous;
                NSInteger idx=i; __weak UIView *wpg=pg;
                __weak ALGBlockButton *wab=ab;
                ab.actionBlock=^{
                    for(NSInteger j=0;j<8;j++){
                        UIButton *o=(UIButton*)[wpg viewWithTag:4000+j];
                        o.backgroundColor=[UIColor colorWithWhite:1 alpha:0.08f];
                    }
                    wab.backgroundColor=ALG_ACCENT;
                    gPageAnim=idx;
                    NSMutableDictionary *p=ALGPrefs(); p[@"pageAnim"]=@(idx);
                    ALGSavePrefs(p);
                };
                [ab addTarget:ab action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
                [pg addSubview:ab];
            }
            y+=90;
            // Toggle
            UIView *trow=ALGRow(y,panelW,46);
            ALGRowToggle(trow,@"Enable page animations",@"play.circle",
                prefs[@"pageAnimEnabled"]?[prefs[@"pageAnimEnabled"] boolValue]:YES,6100);
            ALGBlockButton *tp=[ALGBlockButton new];
            __weak UIView *wtr=trow;
            tp.actionBlock=^{
                UISwitch *sw=(UISwitch*)[wtr viewWithTag:6100];
                gPageAnimEnabled=sw.on;
                NSMutableDictionary *p=ALGPrefs(); p[@"pageAnimEnabled"]=@(sw.on);
                ALGSavePrefs(p);
            };
            UISwitch *tsw=(UISwitch*)[trow viewWithTag:6100];
            [tsw addTarget:tp action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];
            objc_setAssociatedObject(tsw,"p",tp,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [pg addSubview:trow];

            ALGPush(wnc,pg,panelW);
        };
        [c2 addTarget:c2 action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [home addSubview:c2]; cy+=66;

        ALGBlockButton *c3=ALGNavCard(@"Battery",@"battery.100.bolt",@"Custom battery icon styles",cy,panelW,
            [UIColor colorWithRed:0.2f green:0.8f blue:0.4f alpha:1]);
        c3.actionBlock=^{
            // ── BATTERY SUBPAGE ──
            UIView *pg=[[UIView alloc] initWithFrame:CGRectMake(0,0,panelW,panelH)];
            pg.backgroundColor=[UIColor clearColor]; pg.userInteractionEnabled=YES;
            [pg addSubview:ALGPageHeader(@"Battery",panelW,wnc,panelW)];

            CGFloat y=60;
            [pg addSubview:ALGSection(@"Icon Style",y,panelW)]; y+=22;

            NSArray *bN=@[@"Default",@"Vertical",@"Face",@"Heart",@"Bolt",@"Percent"];
            CGFloat bw2=(panelW-36)/3.0f;
            for (NSInteger i=0;i<6;i++){
                CGFloat bx=14+(i%3)*bw2;
                CGFloat by=y+(i/3)*40;
                ALGBlockButton *ab=[ALGBlockButton buttonWithType:UIButtonTypeCustom];
                ab.frame=CGRectMake(bx,by,bw2-4,34);
                [ab setTitle:bN[i] forState:UIControlStateNormal];
                ab.titleLabel.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
                BOOL sel=[prefs[@"batteryStyle"] integerValue]==i;
                ab.backgroundColor=sel?ALG_GREEN:[UIColor colorWithWhite:1 alpha:0.08f];
                [ab setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                ab.layer.cornerRadius=10; ab.tag=5000+i;
                if (@available(iOS 13.0,*)) ab.layer.cornerCurve=kCACornerCurveContinuous;
                NSInteger idx=i; __weak UIView *wpg=pg;
                __weak ALGBlockButton *wab=ab;
                ab.actionBlock=^{
                    for(NSInteger j=0;j<6;j++){
                        UIButton *o=(UIButton*)[wpg viewWithTag:5000+j];
                        o.backgroundColor=[UIColor colorWithWhite:1 alpha:0.08f];
                    }
                    wab.backgroundColor=ALG_GREEN;
                    gBatteryStyle=idx;
                    NSMutableDictionary *p=ALGPrefs(); p[@"batteryStyle"]=@(idx);
                    ALGSavePrefs(p);
                };
                [ab addTarget:ab action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
                [pg addSubview:ab];
            }
            y+=90;
            UILabel *note=[[UILabel alloc] initWithFrame:CGRectMake(20,y,panelW-40,36)];
            note.text=@"Enable 'Custom battery' in General to apply.";
            note.font=[UIFont systemFontOfSize:11]; note.textColor=[UIColor colorWithWhite:1 alpha:0.38f];
            note.numberOfLines=2; note.userInteractionEnabled=NO;
            [pg addSubview:note];

            ALGPush(wnc,pg,panelW);
        };
        [c3 addTarget:c3 action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [home addSubview:c3]; cy+=66;

        ALGBlockButton *c4=ALGNavCard(@"MobileGestalt",@"cpu",@"Device features, iPadOS, AI",cy,panelW,
            ALG_WARN);
        c4.actionBlock=^{ALGShowGestaltEditor();};
        [c4 addTarget:c4 action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [home addSubview:c4]; cy+=66;

        // ── Bottom actions ──
        cy+=8;
        // Separator
        CAGradientLayer *bs=[CAGradientLayer layer]; bs.frame=CGRectMake(20,cy,panelW-40,0.5f);
        bs.colors=@[(id)[UIColor colorWithWhite:1 alpha:0].CGColor,
                     (id)[UIColor colorWithWhite:1 alpha:0.15f].CGColor,
                     (id)[UIColor colorWithWhite:1 alpha:0].CGColor];
        bs.startPoint=CGPointMake(0,0.5f); bs.endPoint=CGPointMake(1,0.5f);
        [home.layer addSublayer:bs]; cy+=12;

        ALGBlockButton *resp=ALGActionBtn(@"Respring",ALG_ACCENT,cy,panelW);
        resp.actionBlock=^{ ALGDoRespring(); };
        [resp addTarget:resp action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [home addSubview:resp]; cy+=52;

        // File browser + terminal links
        ALGBlockButton *fb=ALGNavCard(@"File Browser",@"folder",@"Browse filesystem",cy,panelW,
            [UIColor colorWithWhite:1 alpha:0.5f]);
        fb.actionBlock=^{ ALGShowFileBrowser(@"/"); };
        [fb addTarget:fb action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [home addSubview:fb]; cy+=66;

        if (gTerminalEnabled) {
            ALGBlockButton *tm=ALGNavCard(@"Terminal",@"terminal",@"Run commands",cy,panelW,
                [UIColor colorWithWhite:1 alpha:0.5f]);
            tm.actionBlock=^{ ALGShowTerminal(); };
            [tm addTarget:tm action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
            [home addSubview:tm]; cy+=66;
        }
    }
    [navContainer addSubview:home];

    // Pan to drag panel — gesture en el panel, no en una view que bloquee
    __weak UIView *wp=panel;
    __block UIPanGestureRecognizer *pan=nil;
    ALGBlockButton *panP=[ALGBlockButton new];
    panP.actionBlock=^{
        UIView *p=wp; if(!p||!pan) return;
        UIView *r=p.superview; if(!r) return;
        CGPoint d=[pan translationInView:r];
        CGRect f=p.frame;
        f.origin.x=MAX(4,MIN(f.origin.x+d.x,r.bounds.size.width-f.size.width-4));
        f.origin.y=MAX(20,MIN(f.origin.y+d.y,r.bounds.size.height-f.size.height-20));
        p.frame=f;
        for (UIView *v in r.subviews)
            if (v!=p && v.tag!=9998 && v.tag!=9999 && v.layer.shadowRadius>10)
                v.frame=f;
        [pan setTranslation:CGPointZero inView:r];
    };
    pan=[[UIPanGestureRecognizer alloc] initWithTarget:panP action:@selector(handleTap)];
    objc_setAssociatedObject(panel,"panP",panP,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [panel addGestureRecognizer:pan];

    [rootView addSubview:panel];

    gSettingsWindow.hidden=NO;
    gSettingsWindow.userInteractionEnabled=YES;
    [gSettingsWindow makeKeyAndVisible];

    // Entry animation
    panel.alpha=0; dim.alpha=0;
    panel.transform=CGAffineTransformConcat(CGAffineTransformMakeScale(0.9f,0.9f),CGAffineTransformMakeTranslation(0,12));
    [UIView animateWithDuration:0.38f delay:0 usingSpringWithDamping:0.78f initialSpringVelocity:0.6f
        options:UIViewAnimationOptionAllowUserInteraction animations:^{
        panel.alpha=1; panel.transform=CGAffineTransformIdentity;
        dim.alpha=1;
    } completion:nil];
}

// ─────────────────────────────────────────
// SETTINGS BUTTON — AssistiveTouch
// ─────────────────────────────────────────


@interface ALGFloatButton : UIView
@end
@implementation ALGFloatButton
- (void)handlePan:(UIPanGestureRecognizer *)g {
    CGPoint d = [g translationInView:self.superview];
    CGPoint c = CGPointMake(self.center.x+d.x, self.center.y+d.y);
    CGFloat r = self.bounds.size.width/2.0f;
    c.x = MAX(r+4, MIN(c.x, [UIScreen mainScreen].bounds.size.width-r-4));
    c.y = MAX(r+50, MIN(c.y, [UIScreen mainScreen].bounds.size.height-r-34));
    self.center = c;
    [g setTranslation:CGPointZero inView:self.superview];
    if (g.state == UIGestureRecognizerStateEnded) {
        CGFloat tw = c.x < [UIScreen mainScreen].bounds.size.width/2 ? r+4 : [UIScreen mainScreen].bounds.size.width-r-4;
        [UIView animateWithDuration:0.35f delay:0 usingSpringWithDamping:0.75f
              initialSpringVelocity:0.5f options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{ self.center=CGPointMake(tw, c.y); } completion:nil];
    }
}
- (void)handleTap:(UITapGestureRecognizer *)g { ALGShowSettingsPanel(); }
- (void)handleLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan)
        ALGShowFileBrowser(@"/var/mobile");
}
@end

static ALGPassthroughWindow *gButtonWindow = nil;

static void ALGSetupSettingsButton(void) {
    if (gButtonWindow) return;
    UIWindowScene *scene = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
        if ([s isKindOfClass:[UIWindowScene class]]) { scene=(UIWindowScene*)s; break; }
    if (@available(iOS 13.0, *))
        gButtonWindow = [[ALGPassthroughWindow alloc] initWithWindowScene:scene];
    else
        gButtonWindow = [[ALGPassthroughWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    gButtonWindow.windowLevel = UIWindowLevelNormal + 5;
    gButtonWindow.backgroundColor = [UIColor clearColor];
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    vc.view.userInteractionEnabled = YES;
    gButtonWindow.rootViewController = vc;

    CGFloat size = 48.0f;
    CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
    ALGFloatButton *btn = [[ALGFloatButton alloc] initWithFrame:CGRectMake(6, screenH*0.62f, size, size)];
    btn.userInteractionEnabled = YES;

    UIBlurEffect *blurEff;
    if (@available(iOS 13.0, *))
        blurEff = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    else
        blurEff = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *bv2 = [[UIVisualEffectView alloc] initWithEffect:blurEff];
    bv2.frame = CGRectMake(0,0,size,size);
    bv2.layer.cornerRadius = size/2; bv2.layer.masksToBounds = YES;
    bv2.alpha = 0.88f; bv2.userInteractionEnabled = NO;
    [btn addSubview:bv2];

    btn.layer.cornerRadius = size/2;
    btn.layer.borderWidth = 0.7f;
    btn.layer.borderColor = [UIColor colorWithWhite:1.0f alpha:0.35f].CGColor;
    btn.layer.shadowColor = [UIColor blackColor].CGColor;
    btn.layer.shadowOpacity = 0.25f;
    btn.layer.shadowRadius = 10.0f;
    btn.layer.shadowOffset = CGSizeMake(0,4);

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0,0,size,size)];
    lbl.text = @"*"; lbl.font = [UIFont systemFontOfSize:19];
    lbl.textColor = [UIColor whiteColor]; lbl.textAlignment = NSTextAlignmentCenter;
    lbl.userInteractionEnabled = NO;
    [btn addSubview:lbl];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:btn action:@selector(handlePan:)];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:btn action:@selector(handleTap:)];
    tap.numberOfTapsRequired = 1;
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:btn action:@selector(handleLongPress:)];
    lp.minimumPressDuration = 0.6;
    [pan requireGestureRecognizerToFail:tap];
    [btn addGestureRecognizer:pan];
    [btn addGestureRecognizer:tap];
    [btn addGestureRecognizer:lp];

    [vc.view addSubview:btn];
    gButtonWindow.hidden = NO;
    btn.alpha = 0;
    [UIView animateWithDuration:0.5f delay:0.2f options:0
                     animations:^{ btn.alpha=1; } completion:nil];
}


// ─────────────────────────────────────────
// ICONOS REDONDOS
// Jerarquia confirmada: SBIconView > SBIconImageView (60x60) + SBIconBadgeView (badge)
// Hookear SBIconView.layoutSubviews — aplicar radius a SBIconImageView, NO al padre
// ─────────────────────────────────────────

static void ALGApplyIconRadius(UIView *iconView) {
    iconView.layer.masksToBounds = NO;
    iconView.clipsToBounds = NO;
    for (UIView *sub in iconView.subviews) {
        // Badge — NO tocar
        if ([NSStringFromClass([sub class]) containsString:@"Badge"]) continue;
        // SBFTouchPassThroughView — no clipar, buscar dentro
        if ([NSStringFromClass([sub class]) containsString:@"TouchPass"]) {
            sub.layer.masksToBounds = NO;
            sub.clipsToBounds = NO;
            for (UIView *img in sub.subviews) {
                NSString *ic = NSStringFromClass([img class]);
                // Aplicar a cualquier view que sea imagen (no label)
                if (![ic containsString:@"Label"] && ![ic containsString:@"Badge"]) {
                    img.layer.cornerRadius = gIconRadius;
                    if (@available(iOS 13.0, *))
                        img.layer.cornerCurve = kCACornerCurveContinuous;
                    img.layer.masksToBounds = YES;
                }
            }
            // Si SBFTouchPassThroughView no tiene subviews aun,
            // aplicar a el mismo pero con un shape layer para no cortar el label
            if (sub.subviews.count == 0 && sub.bounds.size.width >= 40) {
                sub.layer.cornerRadius = gIconRadius;
                if (@available(iOS 13.0, *))
                    sub.layer.cornerCurve = kCACornerCurveContinuous;
                sub.layer.masksToBounds = YES;
            }
        }
    }
}

static IMP orig_iconViewLayout = NULL;
static void hooked_iconViewLayout(UIView *self, SEL _cmd) {
    ((void(*)(id,SEL))orig_iconViewLayout)(self, _cmd);
    self.layer.masksToBounds = NO;
    self.clipsToBounds = NO;
    // Aplicar inmediatamente
    ALGApplyIconRadius(self);
    // Y tambien despues de que termine el layout completo
    dispatch_async(dispatch_get_main_queue(), ^{
        ALGApplyIconRadius(self);
    });
}

static IMP orig_sbIconViewLayout = NULL;
static void hooked_sbIconViewLayout(UIView *self, SEL _cmd) {
    ((void(*)(id,SEL))orig_sbIconViewLayout)(self, _cmd);
}

// ─────────────────────────────────────────
// ANIMACIONES DE PAGINAS — estilo Cylinder
// Hook setContentOffset: en SBIconScrollView
// ─────────────────────────────────────────

static CATransform3D ALGCubeTransform(CGFloat t, CGFloat w) {
    CGFloat angle = t * (CGFloat)M_PI_2;
    CGFloat z = w / 2.0f;
    CATransform3D tr = CATransform3DIdentity;
    tr.m34 = -1.0f / 500.0f;
    tr = CATransform3DTranslate(tr, t * w / 2.0f, 0, -z);
    tr = CATransform3DRotate(tr, -angle, 0, 1, 0);
    tr = CATransform3DTranslate(tr, 0, 0, z);
    return tr;
}

static CATransform3D ALGWaveTransform(CGFloat t, CGFloat h) {
    CGFloat ty = -sinf((float)(t * M_PI)) * h * 0.18f;
    CGFloat scale = 1.0f - fabsf((float)t) * 0.15f;
    CATransform3D tr = CATransform3DIdentity;
    tr = CATransform3DTranslate(tr, 0, ty, 0);
    tr = CATransform3DScale(tr, scale, scale, 1);
    return tr;
}

static CATransform3D ALGTiltTransform(CGFloat t) {
    CGFloat angle = t * (CGFloat)M_PI / 6.0f;
    CATransform3D tr = CATransform3DIdentity;
    tr.m34 = -1.0f / 600.0f;
    tr = CATransform3DRotate(tr, angle, 0, 1, 0);
    CGFloat scale = 1.0f - fabsf((float)t) * 0.08f;
    tr = CATransform3DScale(tr, scale, scale, 1);
    return tr;
}

static CATransform3D ALGSpiralTransform(CGFloat t, CGFloat w) {
    CGFloat angle = t * (CGFloat)M_PI / 3.0f;
    CGFloat scale = 1.0f - fabsf((float)t) * 0.25f;
    CATransform3D tr = CATransform3DIdentity;
    tr.m34 = -1.0f / 500.0f;
    tr = CATransform3DTranslate(tr, t * w * 0.05f, 0, 0);
    tr = CATransform3DRotate(tr, angle, 0, 0, 1);
    tr = CATransform3DScale(tr, scale, scale, 1);
    return tr;
}

// Hook directo en setContentOffset: — se llama en cada frame del scroll
static IMP orig_setContentOffset = NULL;
static void hooked_setContentOffset(UIScrollView *self, SEL _cmd, CGPoint offset) {
    ((void(*)(id,SEL,CGPoint))orig_setContentOffset)(self, _cmd, offset);
    // None (7) — dejar iOS hacer su animacion nativa, sin tocar transforms
    if (!gAnimations || !gPageAnimEnabled || gPageAnim == 7) return;

    CGFloat pageW = self.frame.size.width;
    CGFloat pageH = self.frame.size.height;
    if (pageW <= 0) return;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    // Buscar páginas recursivamente — iOS 17 cambió la jerarquía
    NSMutableArray *pages = [NSMutableArray array];
    for (UIView *sub in self.subviews) {
        NSString *cn = NSStringFromClass([sub class]);
        if ([cn containsString:@"IconListView"] || [cn containsString:@"RootFolderView"])
            [pages addObject:sub];
    }
    // Si no encontró nada directo, buscar un nivel más adentro (iOS 17)
    if (pages.count == 0) {
        for (UIView *sub in self.subviews) {
            for (UIView *inner in sub.subviews) {
                if ([NSStringFromClass([inner class]) containsString:@"IconListView"])
                    [pages addObject:inner];
            }
        }
    }

    if (pages.count == 0) {
        [CATransaction commit];
        return;
    }
    for (UIView *sub in pages) {
        CGFloat t = (sub.frame.origin.x - offset.x) / pageW;
        CATransform3D tr = CATransform3DIdentity;
        CGFloat alpha = 1.0f;
        switch (gPageAnim) {
            case 0: tr = ALGCubeTransform(t, pageW); break;
            case 1: tr = ALGWaveTransform(t, pageH); break;
            case 2: tr = ALGTiltTransform(t); break;
            case 3: alpha = MAX(0.1f, 1.0f - fabsf((float)t) * 0.75f); break;
            case 4: tr = ALGSpiralTransform(t, pageW);
                    alpha = 1.0f - fabsf((float)t) * 0.3f; break;
            case 5: {
                CGFloat ty2 = fabsf((float)t) * pageH * 0.12f;
                CGFloat sc = 1.0f - fabsf((float)t) * 0.06f;
                tr = CATransform3DTranslate(tr, 0, ty2, 0);
                tr = CATransform3DScale(tr, sc, sc, 1);
                alpha = 1.0f - fabsf((float)t) * 0.2f;
                break;
            }
            case 6: {
                CGFloat ab2 = fabsf((float)t);
                CGFloat sc = 1.0f - ab2 * 0.12f;
                CGFloat tx = t * pageW * 0.04f;
                tr.m34 = -1.0f / 800.0f;
                tr = CATransform3DTranslate(tr, tx, 0, -ab2 * 30.0f);
                tr = CATransform3DScale(tr, sc, sc, 1);
                alpha = 1.0f - ab2 * 0.45f;
                break;
            }
            default: break;
        }
        sub.layer.transform = tr;
        sub.alpha = alpha;
    }
    [CATransaction commit];
}


static BOOL (*orig_isFloatingDockSupported)(id,SEL);
static BOOL hook_isFloatingDockSupported(id s,SEL c){return YES;}
static BOOL (*orig_isDockExternal)(id,SEL);
static BOOL hook_isDockExternal(id s,SEL c){return YES;}
static BOOL (*orig_fdockCtrl_isSupported)(id,SEL);
static BOOL hook_fdockCtrl_isSupported(id s,SEL c){return YES;}
static BOOL (*orig_isFloatingDockSupportedForIconManager)(id,SEL,id);
static BOOL hook_isFloatingDockSupportedForIconManager(id s,SEL c,id m){return YES;}
static BOOL (*orig_recentsEnabled)(id,SEL);
static BOOL hook_recentsEnabled(id s,SEL c){return YES;}
static void (*orig_setRecentsEnabled)(id,SEL,BOOL);
static void hook_setRecentsEnabled(id s,SEL c,BOOL v){orig_setRecentsEnabled(s,c,YES);}
static BOOL (*orig_appLibraryEnabled)(id,SEL);
static BOOL hook_appLibraryEnabled(id s,SEL c){return NO;}
static void (*orig_setAppLibraryEnabled)(id,SEL,BOOL);
static void hook_setAppLibraryEnabled(id s,SEL c,BOOL v){orig_setAppLibraryEnabled(s,c,NO);}
static unsigned long long (*orig_maxSuggestions)(id,SEL);
static unsigned long long hook_maxSuggestions(id s,SEL c){return 3;}
static unsigned long long (*orig_numberOfPortraitColumns)(id,SEL);
static unsigned long long hook_numberOfPortraitColumns(id s,SEL c){
    unsigned long long o=orig_numberOfPortraitColumns(s,c);
    if(((unsigned long long(*)(id,SEL))objc_msgSend)(s,sel_registerName("numberOfPortraitRows"))==1&&o==4)return 6;
    return o;
}
static unsigned long long (*orig_maximumIconCount)(id,SEL);
static unsigned long long hook_maximumIconCount(id s,SEL c){
    id loc=((id(*)(id,SEL))objc_msgSend)(s,sel_registerName("iconLocation"));
    if(loc&&([loc isEqual:@"SBIconLocationDock"]||[loc isEqual:@"SBIconLocationFloatingDock"]))return 6;
    return orig_maximumIconCount(s,c);
}
static void(*orig_configureBehaviorForFolder)(id,SEL,id,NSUInteger);
static void hook_configureBehaviorForFolder(id s,SEL c,id a,NSUInteger b){}
static BOOL(*orig_isFloatingDockGesturePossible)(id,SEL);
static BOOL hook_isFloatingDockGesturePossible(id s,SEL c){return NO;}
static BOOL(*orig_switcher_isFloatingDockSupported)(id,SEL);
static BOOL hook_switcher_isFloatingDockSupported(id s,SEL c){
    Class coord=objc_getClass("SBMainSwitcherControllerCoordinator");
    if(coord){id inst=((id(*)(id,SEL))objc_msgSend)((id)coord,sel_registerName("sharedInstance"));
    if(inst&&((BOOL(*)(id,SEL))objc_msgSend)(inst,sel_registerName("isAnySwitcherVisible")))return YES;}
    return NO;
}


static BOOL gDockActivated = NO;
static id g_fdockCtrl = nil;

// Forward declaration
static void ALGApplyGlassToDockView(UIView *dockView);

static IMP orig_nativeDockLayout = NULL;
static void hooked_nativeDockLayout(UIView *self, SEL _cmd) {
    ((void(*)(id,SEL))orig_nativeDockLayout)(self, _cmd);
    if (!gGlassEnabled) return;
    if (self.bounds.size.width < 10) return;
    @try {
        // Glass al dock
        ALGApplyGlassToDockView(self);

        // Arreglar spacing de iconos dentro del dock
        // Buscar las icon views y redistribuirlas uniformemente
        NSMutableArray *icons = [NSMutableArray array];
        for (UIView *sub in self.subviews) {
            NSString *cn = NSStringFromClass([sub class]);
            if ([cn containsString:@"IconView"] || [cn containsString:@"IconListView"])
                [icons addObject:sub];
        }
        if (icons.count >= 2) {
            CGFloat dockW = self.bounds.size.width;
            CGFloat iconW = ((UIView*)icons[0]).bounds.size.width;
            if (iconW < 10) iconW = 60;
            CGFloat totalW = iconW * icons.count;
            CGFloat spacing = (dockW - totalW - 24) / (icons.count + 1);
            spacing = MAX(spacing, 8);
            CGFloat x = spacing;
            for (UIView *icon in icons) {
                CGRect f = icon.frame;
                f.origin.x = x;
                icon.frame = f;
                x += iconW + spacing;
            }
        }
    } @catch(NSException *e) {}
}

// Hook para layout strategy en iOS 16/17
static IMP orig_dockIconLayout = NULL;
static void hooked_dockIconLayout(id self, SEL _cmd, UIView *dockView) {
    if (orig_dockIconLayout) ((void(*)(id,SEL,id))orig_dockIconLayout)(self, _cmd, dockView);
    // Después del layout, aplicar glass al dock view
    if (dockView && gGlassEnabled)
        dispatch_async(dispatch_get_main_queue(), ^{ ALGApplyGlassToDockView(dockView); });
}

static void ALGApplyGlassToDockView(UIView *dockView) {
    if (!dockView || dockView.frame.size.width < 10) return;
    // NO ocultar subviews — solo aplicar glass encima
    // Evitar duplicar
    for (CALayer *l in dockView.layer.sublayers)
        if ([l.name isEqualToString:@"LGSpecular"]) return;
    // Reducir la opacidad del material nativo en lugar de ocultarlo
    for (UIView *sub in dockView.subviews) {
        NSString *cn = NSStringFromClass([sub class]);
        if ([cn containsString:@"Material"] || [cn containsString:@"Background"])
            sub.alpha = 0.3f; // semi-transparente, no oculto
    }
    ALGApplyLiquidGlass(dockView, LGParamsDock);
}

static void ALGAnimateDockIcons(UIView *root);

static void activateDock(void) {
    @try {
        NSLog(@"[FDock] Activating...");
        id iconCtrl = ((id(*)(id,SEL))objc_msgSend)(
            (id)objc_getClass("SBIconController"), sel_registerName("sharedInstance"));
        id iconManager = ((id(*)(id,SEL))objc_msgSend)(iconCtrl, sel_registerName("iconManager"));

        // Step 1: Create floating dock via official path
        if (!g_fdockCtrl) {
            id homeScreenVC = ((id(*)(id,SEL))objc_msgSend)(iconCtrl, sel_registerName("homeScreenViewController"));
            UIWindowScene *windowScene = nil;
            if (homeScreenVC) {
                UIView *hsView = ((UIView*(*)(id,SEL))objc_msgSend)(homeScreenVC, @selector(view));
                windowScene = hsView.window.windowScene;
            }
            if (!windowScene) {
                for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
                    if ([s isKindOfClass:[UIWindowScene class]]) { windowScene=(UIWindowScene*)s; break; }
            }
            if (!windowScene) { NSLog(@"[FDock] no scene"); gDockActivated=NO; return; }
            g_fdockCtrl = ((id(*)(id,SEL,id))objc_msgSend)(iconCtrl,
                sel_registerName("createFloatingDockControllerForWindowScene:"), windowScene);
            NSLog(@"[FDock] Created controller: %s", g_fdockCtrl ? "YES" : "NO");
        }
        if (!g_fdockCtrl) { gDockActivated=NO; return; }

        // Step 2: Get fdockVC
        id fdockVC = ((id(*)(id,SEL))objc_msgSend)(g_fdockCtrl, sel_registerName("floatingDockViewController"));
        if (!fdockVC) { NSLog(@"[FDock] no fdockVC"); gDockActivated=NO; return; }

        // Step 3: Get dock view
        UIView *fdockVCView = ((UIView*(*)(id,SEL))objc_msgSend)(fdockVC, sel_registerName("view"));
        fdockVCView.frame = CGRectMake(0, 0, 430, 932);
        ((void(*)(id,SEL))objc_msgSend)(fdockVC, @selector(viewDidLayoutSubviews));
        UIView *dockView = ((UIView*(*)(id,SEL))objc_msgSend)(fdockVC, sel_registerName("dockView"));
        NSLog(@"[FDock] dockView: %s frame: %@", class_getName(object_getClass(dockView)), NSStringFromCGRect(dockView.frame));

        // Step 4: Hide floating dock window
        UIWindow *dockWindow = ((UIWindow*(*)(id,SEL))objc_msgSend)(g_fdockCtrl, sel_registerName("floatingDockWindow"));
        if (dockWindow) dockWindow.hidden = YES;

        // Step 5: Move fdockVC to root folder controller
        id rfc = ((id(*)(id,SEL))objc_msgSend)(iconManager, sel_registerName("rootFolderController"));
        UIViewController *rfcVC = (UIViewController*)rfc;
        UIView *rfcView = rfcVC.view;
        UIViewController *fdockVCasVC = (UIViewController*)fdockVC;

        [fdockVCasVC willMoveToParentViewController:nil];
        [fdockVCView removeFromSuperview];
        [fdockVCasVC removeFromParentViewController];
        [rfcVC addChildViewController:fdockVCasVC];

        CGFloat screenW = rfcView.bounds.size.width;
        CGFloat screenH = rfcView.bounds.size.height;
        CGFloat dockH = dockView.bounds.size.height > 0 ? dockView.bounds.size.height : 96;
        fdockVCView.frame = CGRectMake(0, screenH-dockH, screenW, dockH);
        fdockVCView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
        [rfcView addSubview:fdockVCView];
        [fdockVCasVC didMoveToParentViewController:rfcVC];
        ((void(*)(id,SEL))objc_msgSend)(fdockVC, @selector(viewDidLayoutSubviews));

        NSLog(@"[FDock] Added dockView to rfcView at %@", NSStringFromCGRect(dockView.frame));
        NSLog(@"[FDock] dockView subviews: %lu", (unsigned long)dockView.subviews.count);

        // Step 6: Hide stock dock
        if ([rfc respondsToSelector:sel_registerName("dockListView")]) {
            UIView *dlv = ((UIView*(*)(id,SEL))objc_msgSend)(rfc, sel_registerName("dockListView"));
            if (dlv) {
                dlv.hidden = YES;
                UIView *dockBG = dlv.superview;
                if (dockBG && [NSStringFromClass(object_getClass(dockBG)) containsString:@"DockView"])
                    dockBG.hidden = YES;
            }
        }

        // Glass al nuevo dock view
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.35*NSEC_PER_SEC)),
                       dispatch_get_main_queue(),^{ ALGApplyGlassToDockView(dockView); });

        NSLog(@"[FDock] Done!");
    } @catch(NSException *e) {
        NSLog(@"[FDock] EXCEPTION: %@", e);
    }
}

// ─────────────────────────────────────────
// DOCK ICONS animation
// ─────────────────────────────────────────
static void ALGAnimateDockIcons(UIView *root) {
    NSMutableArray *iconViews = [NSMutableArray new];
    NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
    while (queue.count > 0) {
        UIView *v = queue.firstObject; [queue removeObjectAtIndex:0];
        if ([NSStringFromClass([v class]) isEqualToString:@"SBIconView"]) {
            [iconViews addObject:v]; continue;
        }
        [queue addObjectsFromArray:v.subviews];
    }
    char b[64]; snprintf(b,sizeof(b),"[FDOCK] found %lu icons",(unsigned long)iconViews.count);
    if (iconViews.count == 0) return;

    for (UIView *icon in iconViews) {
        icon.alpha = 0.0f;
        icon.transform = CGAffineTransformConcat(
            CGAffineTransformMakeScale(0.75f, 0.75f),
            CGAffineTransformMakeTranslation(0, 8));
    }
    [iconViews enumerateObjectsUsingBlock:^(UIView *icon, NSUInteger i, BOOL *s) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(i*0.008*NSEC_PER_SEC)),
                       dispatch_get_main_queue(),^{
            [UIView animateWithDuration:0.32f delay:0 usingSpringWithDamping:0.7f
                  initialSpringVelocity:1.2f options:UIViewAnimationOptionAllowUserInteraction
                             animations:^{ icon.alpha=1.0f; icon.transform=CGAffineTransformIdentity; }
                             completion:nil];
        });
    }];
}


static IMP orig_fdockPresent = NULL;
static void hooked_fdockPresent(UIViewController *self, SEL _cmd) {
    ((void(*)(id,SEL))orig_fdockPresent)(self, _cmd);
    if (!gAnimations) return;
    // Verificar que es SBFloatingDockViewController y no otro VC
    if (![NSStringFromClass([self class]) containsString:@"FloatingDock"]) return;
    self.view.alpha = 0.0f;
    self.view.transform = CGAffineTransformMakeTranslation(0, 50);
    [UIView animateWithDuration:0.18f delay:0 usingSpringWithDamping:0.85f
          initialSpringVelocity:1.2f options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{ self.view.alpha=1.0f; self.view.transform=CGAffineTransformIdentity; }
                     completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.02*NSEC_PER_SEC)),
                   dispatch_get_main_queue(),^{ ALGAnimateDockIcons(self.view); });
}

static IMP orig_fdockDismiss = NULL;
static void hooked_fdockDismiss(UIViewController *self, SEL _cmd) {
    if (!gAnimations || ![NSStringFromClass([self class]) containsString:@"FloatingDock"]) {
        ((void(*)(id,SEL))orig_fdockDismiss)(self,_cmd); return;
    }
    [UIView animateWithDuration:0.3f delay:0 options:UIViewAnimationOptionCurveEaseIn
                     animations:^{ self.view.alpha=0.0f; self.view.transform=CGAffineTransformMakeTranslation(0,20); }
                     completion:^(BOOL done) {
        ((void(*)(id,SEL))orig_fdockDismiss)(self, _cmd);
        self.view.alpha = 1.0f;
        self.view.transform = CGAffineTransformIdentity;
    }];
}

static IMP orig_bannerLoad = NULL;
static void hooked_bannerLoad(UIViewController *self, SEL _cmd) {
    ((void(*)(id,SEL))orig_bannerLoad)(self, _cmd);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.15*NSEC_PER_SEC)),
                   dispatch_get_main_queue(),^{
        UIView *v = self.view;
        if (!v || v.frame.size.width < 10) return;
        if (!gGlassEnabled || !gBannerGlass) return;
        v.backgroundColor = [UIColor clearColor];
        // No usar masksToBounds — corta el contenido del banner
        // En su lugar solo aplicar glass sin clip
        LGParams p = LGParamsBanner;
        // Aplicar blur + glass sin clipear
        for (UIView *s in v.subviews)
            if ([s isKindOfClass:[UIVisualEffectView class]]) [s removeFromSuperview];
        UIBlurEffect *blur;
        if (@available(iOS 13.0, *))
            blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        else
            blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        UIVisualEffectView *bv = [[UIVisualEffectView alloc] initWithEffect:blur];
        bv.frame = v.bounds;
        bv.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        bv.layer.cornerRadius = p.cornerRadius;
        if (@available(iOS 13.0, *)) bv.layer.cornerCurve = kCACornerCurveContinuous;
        bv.layer.masksToBounds = YES; // solo el blur view clipa, no el padre
        bv.userInteractionEnabled = NO;
        [v insertSubview:bv atIndex:0];
        // Borde y sombra en el contenedor sin clipar
        v.layer.cornerRadius = p.cornerRadius;
        if (@available(iOS 13.0, *)) v.layer.cornerCurve = kCACornerCurveContinuous;
        v.layer.borderWidth = 0.8f;
        v.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3f].CGColor;
        v.layer.shadowColor = [UIColor colorWithWhite:0 alpha:0.25f].CGColor;
        v.layer.shadowOffset = CGSizeMake(0, 4);
        v.layer.shadowRadius = 12.0f;
        v.layer.shadowOpacity = 0.3f;
        // NO masksToBounds en el padre — así el contenido no se corta
    });
}

// ─────────────────────────────────────────
// BATTERY STYLE
// _UIBatteryView is ~25x12pt in status bar

static void ALGBatteryFillLogic(UIView *batteryView) {
    if (!gBatteryCustom) return;
    CALayer *fl = ((CALayer*(*)(id,SEL))objc_msgSend)(batteryView, sel_registerName("fillLayer"));
    if (!fl) return;
    // Solo ignorar thumbnails minúsculos
    CGFloat checkW = batteryView.bounds.size.width;
    CGFloat checkH = batteryView.bounds.size.height;
    if (checkW < 5 || checkH < 3) return;
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    float level = [UIDevice currentDevice].batteryLevel;
    if (level < 0) level = 0.5f;

    // Tamaño real de la battery view
    CGFloat vw = batteryView.bounds.size.width;
    CGFloat vh = batteryView.bounds.size.height;
    // En status bar la bateria suele ser ~25x13pt
    if (vw < 4) vw = 25;
    if (vh < 4) vh = 13;
    CGFloat innerX = 2, innerY = 1.5f;
    CGFloat innerW = vw - 6;
    CGFloat innerH = vh - 3.0f;

    // Eliminar overlay anterior nuestro (no tocar el fillLayer del sistema)
    for (CALayer *l in [batteryView.layer.sublayers copy])
        if ([l.name isEqualToString:@"ALGBattOverlay"]) [l removeFromSuperlayer];

    // Obtener dimensiones reales usando el superlayer del fillLayer
    // El superlayer ES la battery view layer — sus bounds son el area completa
    CALayer *battLayer = batteryView.layer;
    // Buscar el clip layer que contiene el fillLayer
    CGFloat trueX = innerX, trueY = innerY;
    CGFloat trueW = innerW, trueH = innerH;

    // El fillLayer vive dentro de un clip layer — su superlayer tiene el tamaño real
    if (fl.superlayer && fl.superlayer != battLayer) {
        CALayer *clip = fl.superlayer;
        trueX = clip.frame.origin.x;
        trueY = clip.frame.origin.y;
        trueW = clip.bounds.size.width  > 2 ? clip.bounds.size.width  : trueW;
        trueH = clip.bounds.size.height > 1 ? clip.bounds.size.height : trueH;
    } else {
        // Fallback: usar bounds de batteryView menos bordes tipicos
        trueW = vw > 8 ? vw - 6.5f : vw - 4.0f;
        trueH = vh > 5 ? vh - 3.5f : vh - 2.0f;
        if (fl.frame.origin.x > 0.5f) trueX = fl.frame.origin.x;
        if (fl.frame.origin.y > 0.5f) trueY = fl.frame.origin.y;
    }

    // Mismo tamaño exacto que el original — sin escalar
    CGFloat scaledW = trueW;
    CGFloat scaledH = trueH;
    CGFloat scaledX = trueX;
    CGFloat scaledY = trueY;

    CGFloat innerX2 = 0, innerY2 = 0;
    CGFloat innerW2 = scaledW;
    CGFloat innerH2 = scaledH;

    // Overlay principal — el fill va aquí
    CALayer *overlay = [CALayer layer];
    overlay.name = @"ALGBattOverlay";
    overlay.zPosition = 100;
    overlay.masksToBounds = YES;
    overlay.cornerRadius = scaledH * 0.28f; // mismo radio que el icono original
    overlay.frame = CGRectMake(scaledX, scaledY, scaledW, scaledH);

    // Dibujar contorno de pila encima (sin masksToBounds para que el terminal salga)
    CAShapeLayer *battOutline = [CAShapeLayer layer];
    battOutline.name = @"ALGBattOutline";
    battOutline.zPosition = 200;
    // Pila: cuerpo + terminal positivo a la derecha
    CGFloat bW = scaledW + 1.0f;  // un poco más grande que el fill
    CGFloat bH = scaledH + 1.0f;
    CGFloat bX = -0.5f; CGFloat bY = -0.5f;
    CGFloat bR = bH * 0.22f;      // corner radius del cuerpo
    CGFloat tipW = bH * 0.18f;    // ancho del terminal
    CGFloat tipH = bH * 0.42f;    // alto del terminal
    CGFloat tipX = bW;            // terminal justo a la derecha del cuerpo
    CGFloat tipY = (bH - tipH) / 2.0f;

    UIBezierPath *battPath = [UIBezierPath bezierPath];
    // Cuerpo con esquinas redondeadas
    [battPath appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(bX, bY, bW, bH)
                                                    cornerRadius:bR]];
    // Terminal positivo
    [battPath appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(tipX, tipY, tipW, tipH)
                                                    cornerRadius:tipH * 0.3f]];

    battOutline.path = battPath.CGPath;
    battOutline.fillColor = [UIColor clearColor].CGColor;
    battOutline.strokeColor = [UIColor colorWithWhite:1 alpha:0.7f].CGColor;
    battOutline.lineWidth = 0.6f;
    battOutline.frame = overlay.bounds;
    // No clipear — el terminal positivo sobresale a la derecha
    // Redefinir inner para este overlay
    #define iX innerX2
    #define iY innerY2
    #define iW innerW2
    #define iH innerH2

    switch (gBatteryStyle) {
        case 0: {
            CGFloat fillH = MAX(1, iH * level);
            overlay.frame = CGRectMake(iX, iY + (iH - fillH), iW, fillH);
            overlay.cornerRadius = 1.5f;
            UIColor *col = level > 0.5f ? [UIColor colorWithRed:0.3f green:0.85f blue:0.4f alpha:1.0f]
                         : level > 0.25f ? [UIColor colorWithRed:1.0f green:0.75f blue:0.0f alpha:1.0f]
                                         : [UIColor colorWithRed:1.0f green:0.25f blue:0.25f alpha:1.0f];
            overlay.backgroundColor = col.CGColor;
            break;
        }
        case 1: {
            CGFloat fillW = MAX(1, iW * level);
            overlay.frame = CGRectMake(iX, iY, fillW, iH);
            overlay.cornerRadius = 1.5f;
            UIColor *col = level > 0.5f ? [UIColor colorWithRed:0.3f green:0.85f blue:0.4f alpha:1.0f]
                         : level > 0.25f ? [UIColor colorWithRed:1.0f green:0.75f blue:0.0f alpha:1.0f]
                                         : [UIColor colorWithRed:1.0f green:0.25f blue:0.25f alpha:1.0f];
            overlay.backgroundColor = col.CGColor;
            break;
        }
        case 2: {
            [fl setFrame:CGRectMake(innerX, innerY, innerW, innerH)];
            fl.cornerRadius = 1.5f;
            fl.backgroundColor = [UIColor clearColor].CGColor;

            // Colored fill (left portion = charged)
            CGFloat fillW = MAX(1.0f, iW * level);
            CALayer *fillBg = [CALayer layer];
            fillBg.frame = CGRectMake(0, 0, fillW, iH);
            fillBg.cornerRadius = 1.5f;
            // Color matches reference: gray/dark fill
            UIColor *fillCol = level > 0.5f
                ? [UIColor colorWithWhite:0.55f alpha:0.85f]
                : level > 0.25f
                    ? [UIColor colorWithRed:0.9f green:0.6f blue:0.1f alpha:0.85f]
                    : [UIColor colorWithRed:0.85f green:0.2f blue:0.2f alpha:0.85f];
            fillBg.backgroundColor = fillCol.CGColor;
            [overlay addSublayer:fillBg];

            CGFloat cx = iW * 0.5f;
            CGFloat cy = iH * 0.48f;
            CGFloat eyeSize = iH * 0.18f;
            CGFloat eyeY = cy - iH * 0.08f;
            CGFloat eyeOffX = iW * 0.16f;

            CAShapeLayer *eL = [CAShapeLayer layer];
            eL.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(
                cx - eyeOffX - eyeSize, eyeY - eyeSize,
                eyeSize*2, eyeSize*2)].CGPath;
            eL.fillColor = [UIColor colorWithWhite:0.12f alpha:0.95f].CGColor;
            [overlay addSublayer:eL];

            // Right eye
            CAShapeLayer *eR = [CAShapeLayer layer];
            eR.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(
                cx + eyeOffX - eyeSize, eyeY - eyeSize,
                eyeSize*2, eyeSize*2)].CGPath;
            eR.fillColor = [UIColor colorWithWhite:0.12f alpha:0.95f].CGColor;
            [overlay addSublayer:eR];

            CAShapeLayer *mth = [CAShapeLayer layer];
            UIBezierPath *mp = [UIBezierPath bezierPath];
            CGFloat mouthW = innerW * 0.18f;
            CGFloat mouthX = cx - mouthW * 0.5f;
            CGFloat mouthY = cy + innerH * 0.12f;
            CGFloat mouthCurve = innerH * 0.12f;

            if (level > 0.5f) {
                // Happy smile :)
                [mp moveToPoint:CGPointMake(mouthX, mouthY)];
                [mp addQuadCurveToPoint:CGPointMake(mouthX + mouthW, mouthY)
                           controlPoint:CGPointMake(cx, mouthY + mouthCurve)];
            } else if (level > 0.25f) {
                // Neutral — straight line
                [mp moveToPoint:CGPointMake(mouthX, mouthY + mouthCurve*0.3f)];
                [mp addLineToPoint:CGPointMake(mouthX + mouthW, mouthY + mouthCurve*0.3f)];
            } else {
                // Sad frown :(
                [mp moveToPoint:CGPointMake(mouthX, mouthY + mouthCurve)];
                [mp addQuadCurveToPoint:CGPointMake(mouthX + mouthW, mouthY + mouthCurve)
                           controlPoint:CGPointMake(cx, mouthY)];
            }
            mth.path = mp.CGPath;
            mth.fillColor = [UIColor clearColor].CGColor;
            mth.strokeColor = [UIColor colorWithWhite:0.12f alpha:0.95f].CGColor;
            mth.lineWidth = MAX(0.7f, innerH * 0.09f);
            mth.lineCap = kCALineCapRound;
            [overlay addSublayer:mth];
            break;
        }
        case 3: {
            // Heart fill
            CGFloat fillW = MAX(2, innerW * level);
            [fl setFrame:CGRectMake(innerX, innerY, innerW, innerH)];
            fl.cornerRadius = 1.5f;

            CALayer *fillBg = [CALayer layer];
            fillBg.frame = CGRectMake(0, 0, fillW, innerH);
            fillBg.cornerRadius = 1.5f;
            fillBg.backgroundColor = [UIColor colorWithRed:1.0f green:0.3f blue:0.5f alpha:0.85f].CGColor;
            [overlay addSublayer:fillBg];

            // Small heart centered
            CGFloat s = innerH * 0.35f;
            CGFloat hcx = innerW/2, hcy = innerH/2 + s*0.08f;
            UIBezierPath *hrt = [UIBezierPath bezierPath];
            [hrt moveToPoint:CGPointMake(hcx, hcy+s*0.75f)];
            [hrt addCurveToPoint:CGPointMake(hcx-s, hcy-s*0.1f)
                   controlPoint1:CGPointMake(hcx-s*1.0f, hcy+s*0.55f)
                   controlPoint2:CGPointMake(hcx-s*1.0f, hcy-s*0.4f)];
            [hrt addArcWithCenter:CGPointMake(hcx-s*0.5f,hcy-s*0.1f) radius:s*0.5f startAngle:M_PI endAngle:0 clockwise:YES];
            [hrt addArcWithCenter:CGPointMake(hcx+s*0.5f,hcy-s*0.1f) radius:s*0.5f startAngle:M_PI endAngle:0 clockwise:YES];
            [hrt addCurveToPoint:CGPointMake(hcx, hcy+s*0.75f)
                   controlPoint1:CGPointMake(hcx+s*1.0f, hcy-s*0.4f)
                   controlPoint2:CGPointMake(hcx+s*1.0f, hcy+s*0.55f)];
            [hrt closePath];
            CAShapeLayer *hs = [CAShapeLayer layer];
            hs.path = hrt.CGPath;
            hs.fillColor = [UIColor colorWithWhite:1 alpha:0.9f].CGColor;
            [overlay addSublayer:hs];
            break;
        }
        case 4: {
            // Lightning bolt
            CGFloat fillW = MAX(2, innerW * level);
            [fl setFrame:CGRectMake(innerX, innerY, innerW, innerH)];
            fl.cornerRadius = 1.5f;

            CALayer *fillBg = [CALayer layer];
            fillBg.frame = CGRectMake(0, 0, fillW, innerH);
            fillBg.cornerRadius = 1.5f;
            UIColor *bc = level > 0.5f ? [UIColor colorWithRed:1 green:0.9f blue:0 alpha:0.9f]
                        : level > 0.25f ? [UIColor colorWithRed:1 green:0.55f blue:0 alpha:0.9f]
                                        : [UIColor colorWithRed:1 green:0.2f blue:0.2f alpha:0.9f];
            fillBg.backgroundColor = bc.CGColor;
            [overlay addSublayer:fillBg];

            // Bolt shape
            CGFloat bw = innerW*0.3f, bh = innerH*0.75f;
            CGFloat bx = (innerW-bw)/2.0f, by2 = (innerH-bh)/2.0f;
            UIBezierPath *bolt = [UIBezierPath bezierPath];
            [bolt moveToPoint:CGPointMake(bx+bw*0.65f, by2)];
            [bolt addLineToPoint:CGPointMake(bx+bw*0.2f, by2+bh*0.48f)];
            [bolt addLineToPoint:CGPointMake(bx+bw*0.5f, by2+bh*0.48f)];
            [bolt addLineToPoint:CGPointMake(bx+bw*0.35f, by2+bh)];
            [bolt addLineToPoint:CGPointMake(bx+bw*0.8f, by2+bh*0.52f)];
            [bolt addLineToPoint:CGPointMake(bx+bw*0.5f, by2+bh*0.52f)];
            [bolt closePath];
            CAShapeLayer *bs = [CAShapeLayer layer];
            bs.path = bolt.CGPath;
            bs.fillColor = [UIColor colorWithWhite:1 alpha:0.95f].CGColor;
            [overlay addSublayer:bs]; break;
        }
        case 5: {
            overlay.frame = CGRectMake(scaledX, scaledY, scaledW, scaledH);
            overlay.backgroundColor = [UIColor clearColor].CGColor;
            overlay.cornerRadius = scaledH * 0.28f;

            NSInteger pv = (NSInteger)(level * 100);

            CATextLayer *pct = [CATextLayer layer];

            CGFloat fs = pv >= 100 ? scaledH * 0.50f : scaledH * 0.62f;

            CGFloat textH = fs;
            CGFloat textY = (scaledH - textH) * 0.5f - (scaledH * 0.08f);

            pct.frame = CGRectMake(0, textY, scaledW, textH);

            pct.string = [NSString stringWithFormat:@"%ld", (long)pv];
            pct.font = (__bridge CFTypeRef)[UIFont systemFontOfSize:fs weight:UIFontWeightBold];
            pct.fontSize = fs;
            pct.alignmentMode = kCAAlignmentCenter;
            pct.foregroundColor = [UIColor whiteColor].CGColor;
            pct.contentsScale = [UIScreen mainScreen].scale;

            [overlay addSublayer:pct];
            break;
        }
    }
    #undef iX
    #undef iY
    #undef iW
    #undef iH
    [batteryView.layer addSublayer:overlay];
    for (CALayer *l in [batteryView.layer.sublayers copy])
        if ([l.name isEqualToString:@"ALGBattOutline"]) [l removeFromSuperlayer];
    battOutline.frame = overlay.frame; 
    [batteryView.layer addSublayer:battOutline];
}

static IMP orig_battLayout = NULL;
static IMP orig_setFillLayer = NULL;
static void hooked_setFillLayer(UIView *self, SEL _cmd, CALayer *layer) {
    ((void(*)(id,SEL,id))orig_setFillLayer)(self, _cmd, layer);
    if (!gBatteryCustom) return;
    // Ocultar todos los sublayers originales — solo mostrar el nuestro
    CALayer *fl = ((CALayer*(*)(id,SEL))objc_msgSend)(self, sel_registerName("fillLayer"));
    if (fl) fl.hidden = YES;
    for (CALayer *sub in self.layer.sublayers)
        if (![sub.name isEqualToString:@"ALGBattOverlay"]) sub.hidden = YES;
    ALGBatteryFillLogic(self);
}

static IMP orig_updateFillLayer = NULL;
static void hooked_updateFillLayer(UIView *self, SEL _cmd) {
    ((void(*)(id,SEL))orig_updateFillLayer)(self, _cmd);
    if (!gBatteryCustom) return;
    // Re-ocultar los layers del sistema tras update
    CALayer *fl = ((CALayer*(*)(id,SEL))objc_msgSend)(self, sel_registerName("fillLayer"));
    if (fl) fl.hidden = YES;
    for (CALayer *sub in self.layer.sublayers)
        if (![sub.name isEqualToString:@"ALGBattOverlay"]) sub.hidden = YES;
    ALGBatteryFillLogic(self);
}

// Hook layoutSubviews para ocultar subviews del sistema (bolt icon, etc)
static void hooked_battLayout(UIView *self, SEL _cmd) {
    ((void(*)(id,SEL))orig_battLayout)(self, _cmd);
    if (!gBatteryCustom) return;
    for (UIView *sub in self.subviews)
        if (![NSStringFromClass([sub class]) containsString:@"ALG"]) sub.hidden = YES;
}



// ═══════════════════════════════════════════════════════════════
// LOCKSCREEN CUSTOMIZER — v2.0 (Velvet2 style)
// ═══════════════════════════════════════════════════════════════

#define LS_SUITE @"com.aldazdev.lockscreen"

// ─── Prefs I/O ───────────────────────────────────────────────
static NSMutableDictionary *LSPrefs(void) {
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:LS_SUITE];
    NSDictionary *all = [ud dictionaryRepresentation];
    NSMutableDictionary *filtered = [NSMutableDictionary dictionary];
    for (NSString *k in all) {
        id v = all[k];
        if (v && ![v isKindOfClass:[NSNull class]] &&
            ([k hasPrefix:@"clock"] || [k hasPrefix:@"date"] ||
             [k hasPrefix:@"notif"] || [k hasPrefix:@"border"] ||
             [k hasPrefix:@"bg"] || [k hasPrefix:@"shadow"] ||
             [k hasPrefix:@"line"] || [k hasPrefix:@"theme"]))
            filtered[k] = v;
    }
    NSMutableDictionary *d = filtered.count > 1 ? filtered : nil;
    if (!d) d = [NSMutableDictionary dictionaryWithDictionary:@{
        @"clockFontSize":     @(70.0f),
        @"clockSplit":        @NO,
        @"clockMinsSize":     @(0.0f),
        @"clockAlign":        @(0),
        @"clockFontWeight":   @(1),
        @"clockAlpha":        @(1.0f),
        @"clockY":            @(0.38f),
        @"clockPX":           @(-1.0f),
        @"clockPY":           @(-1.0f),
        @"clockScale":        @(1.0f),
        @"dateFontSize":      @(18.0f),
        @"dateAlpha":         @(0.85f),
        @"datePX":            @(-1.0f),
        @"datePY":            @(-1.0f),
        @"dateScale":         @(1.0f),
        // Notif
        @"notifEnabled":      @YES,
        @"notifRadius":       @(16.0f),
        @"notifBlur":         @YES,
        @"notifTitleBold":    @YES,
        @"notifShowIcon":     @YES,
        @"notifAlpha":        @(0.95f),
        @"notifScale":        @(1.0f),
        // Border (Velvet2 style)
        @"borderEnabled":     @YES,
        @"borderType":        @"icon",   // icon | color
        @"borderWidth":       @(2.0f),
        @"borderIconAlpha":   @(85),     // 0-100
        // Background tint
        @"bgEnabled":         @YES,
        @"bgType":            @"icon",   // icon | color
        @"bgIconAlpha":       @(30),
        // Shadow (glow)
        @"shadowEnabled":     @YES,
        @"shadowType":        @"icon",
        @"shadowWidth":       @(8.0f),
        @"shadowIconAlpha":   @(100),
        // Line accent
        @"lineEnabled":       @YES,
        @"linePosition":      @"left",   // left|right|top|bottom
        @"lineWidth":         @(3.0f),
        @"lineType":          @"icon",
    }];
    return d;
}
static void LSSavePrefs(NSMutableDictionary *d) {
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:LS_SUITE];
    for (NSString *k in d) [ud setObject:d[k] forKey:k];
    [ud synchronize];
}

// ─── Globals ──────────────────────────────────────────────────
static CGFloat   gLSClockSize   = 70.0f;
static NSInteger gLSClockW      = 1;
static CGFloat   gLSClockAlpha  = 1.0f;
static BOOL      gLSClockSplit  = NO;
static CGFloat   gLSMinsSize    = 0.0f;
static NSInteger gLSClockAlign  = 0;
static CGFloat   gLSClockPX     = -1.0f;
static CGFloat   gLSClockPY     = -1.0f;
static CGFloat   gLSClockY      = 0.38f;
static CGFloat   gLSClockScale  = 1.0f;

static CGFloat   gLSDateSize    = 18.0f;
static CGFloat   gLSDateAlpha   = 0.85f;
static CGFloat   gLSDatePX      = -1.0f;
static CGFloat   gLSDatePY      = -1.0f;
static CGFloat   gLSDateScale   = 1.0f;

static BOOL      gLSNotifEnabled    = YES;
static CGFloat   gLSNotifRadius     = 16.0f;
static BOOL      gLSNotifBlur       = YES;
static BOOL      gLSNotifTitleBold  = YES;
static BOOL      gLSNotifShowIcon   = YES;
static CGFloat   gLSNotifAlpha      = 0.95f;
static CGFloat   gLSNotifScale      = 1.0f;

// Velvet2-style effect state (
static BOOL      gLSBorderEnabled   = YES;
static NSInteger gLSBorderType      = 0;   // 0=icon 1=color
static CGFloat   gLSBorderWidth     = 2.0f;
static CGFloat   gLSBorderIconAlpha = 0.85f;
static UIColor  *gLSBorderColor     = nil;

static BOOL      gLSBgEnabled       = YES;
static NSInteger gLSBgType          = 0;
static CGFloat   gLSBgIconAlpha     = 0.3f;
static UIColor  *gLSBgColor         = nil;

static BOOL      gLSShadowEnabled   = YES;
static NSInteger gLSShadowType      = 0;
static CGFloat   gLSShadowWidth     = 8.0f;
static CGFloat   gLSShadowIconAlpha = 1.0f;
static UIColor  *gLSShadowColor     = nil;

static BOOL      gLSLineEnabled     = YES;
static NSInteger gLSLinePosition    = 0;   // 0=left 1=right 2=top 3=bottom
static CGFloat   gLSLineWidth       = 3.0f;
static NSInteger gLSLineType        = 0;
static UIColor  *gLSLineColor       = nil;
static BOOL      gLSClockGradient      = NO;
static NSInteger gLSClockGradientStyle = 0;
static UIColor  *gLSClockGradColor1    = nil;
static UIColor  *gLSClockGradColor2    = nil;
static NSInteger gLSDateFormat = 0;
static NSInteger gLSClockFontIdx = 0;
static NSInteger gLSDateFontIdx  = 0;
static NSMutableArray *gLSCustomLabels = nil;

// ─── Helpers para leer color guardado ─────────────────────────
static UIColor *LSColorFromPrefs(NSMutableDictionary *p, NSString *key) {
    NSNumber *r = p[[key stringByAppendingString:@"R"]];
    NSNumber *g = p[[key stringByAppendingString:@"G"]];
    NSNumber *b = p[[key stringByAppendingString:@"B"]];
    if (r && g && b)
        return [UIColor colorWithRed:[r floatValue] green:[g floatValue] blue:[b floatValue] alpha:1.0f];
    return nil;
}

static void LSColorToPrefs(NSMutableDictionary *p, NSString *key, UIColor *color) {
    if (!color) {
        [p removeObjectForKey:[key stringByAppendingString:@"R"]];
        [p removeObjectForKey:[key stringByAppendingString:@"G"]];
        [p removeObjectForKey:[key stringByAppendingString:@"B"]];
        return;
    }
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    p[[key stringByAppendingString:@"R"]] = @(r);
    p[[key stringByAppendingString:@"G"]] = @(g);
    p[[key stringByAppendingString:@"B"]] = @(b);
}

// ─── Load prefs ───────────────────────────────────────────────
static void LSLoadPrefs(void) {
    NSMutableDictionary *p = LSPrefs();

    gLSClockSize   = [p[@"clockFontSize"]   floatValue] ?: 70.0f;
    gLSClockSplit  = p[@"clockSplit"]  ? [p[@"clockSplit"] boolValue]  : NO;
    gLSMinsSize    = [p[@"clockMinsSize"] floatValue];
    gLSClockAlign  = [p[@"clockAlign"] integerValue];
    gLSClockW      = [p[@"clockFontWeight"] integerValue];
    gLSClockAlpha  = [p[@"clockAlpha"]      floatValue] ?: 1.0f;
    gLSClockY      = [p[@"clockY"]          floatValue] ?: 0.38f;
    gLSClockPX     = p[@"clockPX"] ? [p[@"clockPX"] floatValue] : -1.0f;
    gLSClockPY     = p[@"clockPY"] ? [p[@"clockPY"] floatValue] : -1.0f;
    gLSClockScale  = p[@"clockScale"] ? [p[@"clockScale"] floatValue] : 1.0f;
    gLSDateSize    = [p[@"dateFontSize"]    floatValue] ?: 18.0f;
    gLSDateAlpha   = [p[@"dateAlpha"]       floatValue] ?: 0.85f;
    gLSDatePX      = p[@"datePX"] ? [p[@"datePX"] floatValue] : -1.0f;
    gLSDatePY      = p[@"datePY"] ? [p[@"datePY"] floatValue] : -1.0f;
    gLSDateScale   = p[@"dateScale"] ? [p[@"dateScale"] floatValue] : 1.0f;

    gLSNotifEnabled   = p[@"notifEnabled"]   ? [p[@"notifEnabled"]   boolValue] : YES;
    gLSNotifRadius    = [p[@"notifRadius"]   floatValue] ?: 16.0f;
    gLSNotifBlur      = p[@"notifBlur"]      ? [p[@"notifBlur"]      boolValue] : YES;
    gLSNotifTitleBold = p[@"notifTitleBold"] ? [p[@"notifTitleBold"] boolValue] : YES;
    gLSNotifShowIcon  = p[@"notifShowIcon"]  ? [p[@"notifShowIcon"]  boolValue] : YES;
    gLSNotifAlpha     = [p[@"notifAlpha"]    floatValue] ?: 0.95f;
    gLSNotifScale     = [p[@"notifScale"]    floatValue] ?: 1.0f;

    gLSBorderEnabled   = [p[@"borderEnabled"]   boolValue];
    gLSBorderType      = [[p[@"borderType"] isEqual:@"color"] ? @1 : @0 integerValue];
    gLSBorderWidth     = [p[@"borderWidth"]     floatValue] ?: 2.0f;
    gLSBorderIconAlpha = ([p[@"borderIconAlpha"] floatValue] ?: 85) / 100.0f;
    gLSBorderColor     = LSColorFromPrefs(p, @"borderColor");

    gLSBgEnabled    = [p[@"bgEnabled"]   boolValue];
    gLSBgType       = [[p[@"bgType"] isEqual:@"color"] ? @1 : @0 integerValue];
    gLSBgIconAlpha  = ([p[@"bgIconAlpha"] floatValue] ?: 30) / 100.0f;
    gLSBgColor      = LSColorFromPrefs(p, @"bgColor");

    gLSShadowEnabled   = [p[@"shadowEnabled"]   boolValue];
    gLSShadowType      = [[p[@"shadowType"] isEqual:@"color"] ? @1 : @0 integerValue];
    gLSShadowWidth     = [p[@"shadowWidth"]     floatValue] ?: 8.0f;
    gLSShadowIconAlpha = ([p[@"shadowIconAlpha"] floatValue] ?: 100) / 100.0f;
    gLSShadowColor     = LSColorFromPrefs(p, @"shadowColor");

    gLSLineEnabled   = [p[@"lineEnabled"]   boolValue];
    NSString *lpos   = p[@"linePosition"] ?: @"left";
    gLSLinePosition  = [@[@"left",@"right",@"top",@"bottom"] indexOfObject:lpos];
    if (gLSLinePosition == NSNotFound) gLSLinePosition = 0;
    gLSLineWidth     = [p[@"lineWidth"]     floatValue] ?: 3.0f;
    gLSLineType      = [[p[@"lineType"] isEqual:@"color"] ? @1 : @0 integerValue];
    gLSLineColor     = LSColorFromPrefs(p, @"lineColor");
    gLSClockGradient = p[@"clockGradient"] ? [p[@"clockGradient"] boolValue] : NO;
    gLSClockGradientStyle = [p[@"clockGradientStyle"] integerValue];
    gLSClockGradColor1 = LSColorFromPrefs(p, @"gradColor1");
    gLSClockGradColor2 = LSColorFromPrefs(p, @"gradColor2");
    gLSDateFormat = [p[@"dateFormat"] integerValue];
    gLSClockFontIdx = [p[@"clockFontIdx"] integerValue];
    gLSDateFontIdx = [p[@"dateFontIdx"] integerValue];
    NSArray *sl = p[@"customLabels"];
    gLSCustomLabels = [sl isKindOfClass:[NSArray class]] && sl.count > 0 ? [sl mutableCopy] : nil;
}

// ─── Dominant color (Velvet2 CCColorCube simplified) ──────────
static UIColor *LSExtractIconColor(UIImage *img) {
    if (!img) return nil;
    CGSize size = CGSizeMake(16, 16);
    UIGraphicsBeginImageContextWithOptions(size, NO, 1.0f);
    [img drawInRect:CGRectMake(0,0,size.width,size.height)];
    UIImage *small = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (!small) return nil;

    CGImageRef cg = small.CGImage;
    if (!cg) return nil;
    NSInteger w=16, h=16;
    unsigned char *data = (unsigned char*)calloc(w*h*4, 1);
    if (!data) return nil;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(data,w,h,8,w*4,cs,kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    if (!ctx) { free(data); return nil; }
    CGContextDrawImage(ctx, CGRectMake(0,0,w,h), cg);
    CGContextRelease(ctx);

    long rA=0, gA=0, bA=0, cnt=0;
    for (int i=0; i<w*h*4; i+=4) {
        unsigned char cr=data[i], cg2=data[i+1], cb=data[i+2];
        float bright = (cr+cg2+cb) / (3.0f*255.0f);
        float sat = (MAX(cr,MAX(cg2,cb)) - MIN(cr,MIN(cg2,cb))) / 255.0f;
        if (bright > 0.35f && bright < 0.92f && sat > 0.15f) {
            rA+=cr; gA+=cg2; bA+=cb; cnt++;
        }
    }
    free(data);
    if (cnt == 0) return [UIColor colorWithWhite:0.85f alpha:1.0f];
    return [UIColor colorWithRed:rA/(CGFloat)(cnt*255)
                           green:gA/(CGFloat)(cnt*255)
                            blue:bA/(CGFloat)(cnt*255)
                           alpha:1.0f];
}

// ─── Realtime update ──────────────────────────────────────────
static __weak UIView *gLSClockViewRef = nil;
static __weak UIView *gLSDateViewRef  = nil;

static void LSForceRealtime(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"ALGLockscreenUpdate" object:nil];
        if (gLSClockViewRef) { [gLSClockViewRef setNeedsLayout]; [gLSClockViewRef layoutIfNeeded]; }
        if (gLSDateViewRef)  { [gLSDateViewRef  setNeedsLayout]; [gLSDateViewRef  layoutIfNeeded]; }
    });
}

// ─── Helpers de peso de fuente ────────────────────────────────
static UIFontWeight lsWeightFor(NSInteger i) {
    switch(i) {
        case 0: return UIFontWeightThin;
        case 1: return UIFontWeightLight;
        case 2: return UIFontWeightRegular;
        case 3: return UIFontWeightMedium;
        case 4: return UIFontWeightBold;
        default: return UIFontWeightLight;
    }
}

// ─── HOOK: Reloj + Fecha — drag libre + pinch ────────────────
static const char kLSGestureSetup = 0;

// Quita constraints del padre que involucren esta vista
static void LSDisableConstraints(UIView *v) {
    if (!NSThread.isMainThread) return; // solo main thread
    if (objc_getAssociatedObject(v, "lsConstraintsOff")) return;
    @try {
        v.translatesAutoresizingMaskIntoConstraints = YES;
        UIView *parent = v.superview;
        if (parent) {
            NSMutableArray *toRemove = [NSMutableArray array];
            for (NSLayoutConstraint *con in parent.constraints)
                if (con.firstItem == v || con.secondItem == v) [toRemove addObject:con];
            [parent removeConstraints:toRemove];
        }
        objc_setAssociatedObject(v, "lsConstraintsOff", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch(NSException *e) {}
}

// Aplica font al label del reloj (punto size > 20)
static void lsApplyClockFont(UIView *v) {
    if ([v isKindOfClass:[UILabel class]]) {
        UILabel *l = (UILabel*)v;
        if (l.font.pointSize > 20) {
            l.font  = [UIFont systemFontOfSize:gLSClockSize weight:lsWeightFor(gLSClockW)];
            l.alpha = gLSClockAlpha;
            l.adjustsFontSizeToFitWidth = NO;
        }
    }
    for (UIView *s in v.subviews) lsApplyClockFont(s);
}

// Agrega gestos drag + pinch a una vista del lockscreen
// type 0 = reloj, 1 = fecha
static void LSAddGestures(UIView *v, int type);

@interface ALGLSGestureHandler : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, assign) int viewType; // 0=clock 1=date
@property (nonatomic, weak)   UIView *target;
@property (nonatomic, assign) CGFloat lastScale;
@end
@implementation ALGLSGestureHandler
- (void)handlePan:(UIPanGestureRecognizer *)g {
    UIView *v = self.target; if (!v) return;
    // Mover la gesture view (en overlay)
    UIView *gv = g.view;
    CGPoint d = [g translationInView:gv.superview];
    CGRect gf = gv.frame;
    gf.origin.x += d.x; gf.origin.y += d.y;
    CGSize screen = [UIScreen mainScreen].bounds.size;
    gf.origin.x = MAX(0, MIN(gf.origin.x, screen.width  - gf.size.width));
    gf.origin.y = MAX(20, MIN(gf.origin.y, screen.height - gf.size.height - 20));
    gv.frame = gf;
    [g setTranslation:CGPointZero inView:gv.superview];
    CGRect f = v.frame;
    f.origin.x = gf.origin.x;
    f.origin.y = gf.origin.y;
    v.frame = f;
    CGPoint center = CGPointMake(f.origin.x + f.size.width/2, f.origin.y + f.size.height/2);
    if (self.viewType == 0) { gLSClockPX = center.x; gLSClockPY = center.y; }
    else                    { gLSDatePX  = center.x; gLSDatePY  = center.y; }
    if (g.state == UIGestureRecognizerStateEnded) {
        NSMutableDictionary *pr = LSPrefs();
        if (self.viewType == 0) { pr[@"clockPX"]=@(center.x); pr[@"clockPY"]=@(center.y); }
        else                    { pr[@"datePX"] =@(center.x); pr[@"datePY"] =@(center.y); }
        LSSavePrefs(pr);
    }
}
- (void)handlePinch:(UIPinchGestureRecognizer *)g {
    UIView *v = self.target; if (!v) return;
    if (g.state == UIGestureRecognizerStateBegan) self.lastScale = 1.0f;
    CGFloat delta = g.scale / self.lastScale;
    self.lastScale = g.scale;
    if (self.viewType == 0) {
        gLSClockSize = MAX(30, MIN(gLSClockSize * delta, 130));
        [v setNeedsLayout]; [v layoutIfNeeded];
        for (UIView *s in v.subviews) lsApplyClockFont(s);
    } else {
        gLSDateSize = MAX(12, MIN(gLSDateSize * delta, 48));
        NSMutableArray *stack = [NSMutableArray arrayWithObject:v];
        while (stack.count > 0) {
            UIView *sv = stack.firstObject; [stack removeObjectAtIndex:0];
            if ([sv isKindOfClass:[UILabel class]]) {
                UILabel *l = (UILabel*)sv;
                l.font = [UIFont systemFontOfSize:gLSDateSize weight:UIFontWeightLight];
                l.adjustsFontSizeToFitWidth = NO;
            }
            [stack addObjectsFromArray:sv.subviews];
        }
    }
    if (g.state == UIGestureRecognizerStateEnded) {
        NSMutableDictionary *pr = LSPrefs();
        if (self.viewType == 0) pr[@"clockFontSize"] = @(gLSClockSize);
        else                    pr[@"dateFontSize"]  = @(gLSDateSize);
        LSSavePrefs(pr);
    }
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)a
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)b {
    return YES;
}
@end

static UIWindow *gLSEditOverlay       = nil;
static UIView   *gLSClockGestureView  = nil;
static UIView   *gLSDateGestureView   = nil;

static void LSSetupEditOverlay(void) {
    if (gLSEditOverlay) return;
    UIWindowScene *scene = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
        if ([s isKindOfClass:[UIWindowScene class]]) { scene=(UIWindowScene*)s; break; }
    if (@available(iOS 13.0,*))
        gLSEditOverlay = [[UIWindow alloc] initWithWindowScene:scene];
    else
        gLSEditOverlay = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    gLSEditOverlay.windowLevel = UIWindowLevelAlert + 198;
    gLSEditOverlay.backgroundColor = [UIColor clearColor];
    gLSEditOverlay.userInteractionEnabled = YES;
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    vc.view.userInteractionEnabled = YES;
    gLSEditOverlay.rootViewController = vc;
    gLSEditOverlay.hidden = YES;
}

static void LSSyncGestureView(UIView *gestureView, UIView *targetView) {
    if (!gestureView || !targetView) return;
    UIWindow *tw = targetView.window;
    UIWindow *ow = gLSEditOverlay;
    if (!tw || !ow) return;
    CGRect frameInScreen = [tw convertRect:targetView.frame fromView:targetView.superview];
    CGRect frameInOverlay = [ow convertRect:frameInScreen fromWindow:tw];
    gestureView.frame = frameInOverlay;
}

static BOOL gLSEditModeActive = NO;

static void LSAddGestures(UIView *v, int type) {
    if (objc_getAssociatedObject(v, &kLSGestureSetup)) return;
    objc_setAssociatedObject(v, &kLSGestureSetup, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    LSSetupEditOverlay();

    UIView *gv = [[UIView alloc] initWithFrame:v.frame];
    gv.backgroundColor = [UIColor clearColor];
    gv.userInteractionEnabled = NO;
    [gLSEditOverlay.rootViewController.view addSubview:gv];

    if (type == 0) gLSClockGestureView = gv;
    else           gLSDateGestureView  = gv;

    // Sincronizar posición ahora
    dispatch_async(dispatch_get_main_queue(), ^{
        LSSyncGestureView(gv, v);
    });

    ALGLSGestureHandler *h = [[ALGLSGestureHandler alloc] init];
    h.viewType = type; h.target = v; h.lastScale = 1.0f;
    UIPanGestureRecognizer   *pan   = [[UIPanGestureRecognizer alloc]   initWithTarget:h action:@selector(handlePan:)];
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:h action:@selector(handlePinch:)];
    pan.delegate = h; pinch.delegate = h;
    [gv addGestureRecognizer:pan];
    [gv addGestureRecognizer:pinch];
    objc_setAssociatedObject(gv, "lsGH", h, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void LSApplyLiquidGlass(UIView *container) {
    if (objc_getAssociatedObject(container, "lsGlass")) return;
    if (container.bounds.size.width < 10) return;

    UIView *pill = [[UIView alloc] initWithFrame:CGRectInset(container.bounds, -8, -6)];
    pill.center = CGPointMake(container.bounds.size.width/2, container.bounds.size.height/2);
    pill.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    pill.userInteractionEnabled = NO;
    pill.layer.cornerRadius = MIN(pill.bounds.size.width, pill.bounds.size.height) / 2.2f;
    if (@available(iOS 13.0,*)) pill.layer.cornerCurve = kCACornerCurveContinuous;
    pill.layer.masksToBounds = YES;
    pill.layer.borderWidth = 0.6f;
    pill.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.22f].CGColor;

    UIBlurEffect *blurEff;
    if (@available(iOS 13.0,*))
        blurEff = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    else
        blurEff = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *bv = [[UIVisualEffectView alloc] initWithEffect:blurEff];
    bv.frame = pill.bounds;
    bv.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    bv.alpha = 0.28f;
    [pill addSubview:bv];

    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame = pill.bounds;
    grad.name  = @"lsGrad";
    grad.colors = @[
        (id)[UIColor colorWithWhite:1 alpha:0.12f].CGColor,
        (id)[UIColor colorWithWhite:1 alpha:0.0f].CGColor,
    ];
    grad.startPoint = CGPointMake(0, 0);
    grad.endPoint   = CGPointMake(0.4f, 1.0f);
    [pill.layer addSublayer:grad];

    [container addSubview:pill];
    pill.layer.zPosition = -1;

    objc_setAssociatedObject(container, "lsGlass",     @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(container, "lsGlassPill", pill, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void LSRemoveLiquidGlass(UIView *container) {
    UIView *pill = objc_getAssociatedObject(container, "lsGlassPill");
    [pill removeFromSuperview];
    objc_setAssociatedObject(container, "lsGlass",     nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(container, "lsGlassPill", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Helper unificado — posiciona, agrega gestos y glass a una view LS
static void LSApplyViewPosition(UIView *v, int gestureType,
                                 CGFloat *pxRef, CGFloat *pyRef,
                                 CGFloat defaultCX, CGFloat defaultCY,
                                 CGFloat minW, CGFloat minH) {
    if (!v || v.bounds.size.width < 5) return;
    LSDisableConstraints(v);
    v.transform = CGAffineTransformIdentity;
    CGRect f = v.frame;
    if (f.size.height < minH) f.size.height = minH;
    if (f.size.width  < minW) f.size.width  = minW;
    CGFloat cx = (*pxRef > 0) ? *pxRef : defaultCX;
    CGFloat cy = (*pyRef > 0) ? *pyRef : defaultCY;
    f.origin.x = cx - f.size.width  / 2.0f;
    f.origin.y = cy - f.size.height / 2.0f;
    v.frame = f;

    // Long press 5s — activa drag directo sin necesitar el botón
    if (!objc_getAssociatedObject(v, "lsLongPress")) {
        int gtype = gestureType;
        ALGBlockButton *lpHelper = [ALGBlockButton new];
        lpHelper.actionBlock = ^{
            gLSEditModeActive = YES;
            // Mostrar overlay y activar gestos
            gLSEditOverlay.hidden = NO;
            gLSEditOverlay.userInteractionEnabled = YES;
            if (gLSClockGestureView) {
                gLSClockGestureView.userInteractionEnabled = YES;
                if (gLSClockViewRef) LSSyncGestureView(gLSClockGestureView, gLSClockViewRef);
            }
            if (gLSDateGestureView) {
                gLSDateGestureView.userInteractionEnabled = YES;
                if (gLSDateViewRef) LSSyncGestureView(gLSDateGestureView, gLSDateViewRef);
            }
            // Toast — confirma que el long press funcionó
            dispatch_async(dispatch_get_main_queue(), ^{
                UILabel *t = [[UILabel alloc] init];
                t.text = (gtype==0) ? @"Clock edit — drag to move" : @"Date edit — drag to move";
                t.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
                t.textColor = [UIColor whiteColor];
                t.textAlignment = NSTextAlignmentCenter;
                t.backgroundColor = (gtype==0)
                    ? [UIColor colorWithRed:0 green:0.38f blue:0.9f alpha:0.9f]
                    : [UIColor colorWithRed:0.1f green:0.7f blue:0.2f alpha:0.9f];
                t.layer.cornerRadius = 12; t.clipsToBounds = YES;
                [t sizeToFit];
                CGFloat tw = t.bounds.size.width+28, th = 32;
                CGFloat sw = [UIScreen mainScreen].bounds.size.width;
                CGFloat sh = [UIScreen mainScreen].bounds.size.height;
                t.frame = CGRectMake((sw-tw)/2, sh*0.87f, tw, th);
                t.alpha = 0;
                [gLSEditOverlay.rootViewController.view addSubview:t];
                [UIView animateWithDuration:0.25f animations:^{ t.alpha=1; }
                    completion:^(BOOL d){
                    [UIView animateWithDuration:0.3f delay:2.0f options:0
                        animations:^{ t.alpha=0; }
                        completion:^(BOOL d2){ [t removeFromSuperview]; }];
                }];
            });
            if (@available(iOS 10.0,*)) {
                [[UIImpactFeedbackGenerator new] impactOccurred];
            }
            NSLog(@"[AldazDev] LongPress edit mode type %d", gtype);
        };
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
            initWithTarget:lpHelper action:@selector(handleTap)];
        lp.minimumPressDuration = 5.0;
        objc_setAssociatedObject(lp, "lpHelper", lpHelper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [v addGestureRecognizer:lp];
        objc_setAssociatedObject(v, "lsLongPress", lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    LSAddGestures(v, gestureType);
    dispatch_async(dispatch_get_main_queue(), ^{
        LSRemoveLiquidGlass(v);
        LSApplyLiquidGlass(v);
        UIView *gv = (gestureType == 0) ? gLSClockGestureView : gLSDateGestureView;
        if (gv) LSSyncGestureView(gv, v);
    });
}

// ─── Vista custom superpuesta — se actualiza cada segundo ─────
static UILabel *gLSClockLabel  = nil;
static UILabel *gLSMinsLabel   = nil;
static UILabel *gLSDateLabel   = nil;
static UIWindow *gLSClockWindow = nil;

static NSString *lsCurrentTime(void) {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = @"H:mm";  // 24h; cambiar a "h:mm" para 12h
    return [f stringFromDate:[NSDate date]];
}
static NSString *lsCurrentDate(void) {
    NSDateFormatter *f=[[NSDateFormatter alloc]init];
    switch(gLSDateFormat){case 0:f.dateFormat=@"EEEE, MMMM d";break;case 1:f.dateFormat=@"EEE d";break;case 2:f.dateFormat=@"EEE";break;case 3:f.dateFormat=@"d MMMM";break;case 4:f.dateFormat=@"MMMM d";break;case 5:f.dateFormat=@"d/M";break;case 6:f.dateFormat=@"EEE, MMM d";break;default:f.dateFormat=@"EEEE, MMMM d";}
    return [[f stringFromDate:[NSDate date]] uppercaseString];
}

// Crear/actualizar la window custom del reloj
static void LSSetupClockWindow(void) {
    if (gLSClockWindow) return;
    UIWindowScene *scene = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
        if ([s isKindOfClass:[UIWindowScene class]]) { scene=(UIWindowScene*)s; break; }
    if (@available(iOS 13.0,*))
        gLSClockWindow = [[UIWindow alloc] initWithWindowScene:scene];
    else
        gLSClockWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    // Mismo nivel que el boton — ambos encima del lockscreen
    gLSClockWindow.windowLevel = UIWindowLevelAlert + 498;
    gLSClockWindow.backgroundColor = [UIColor clearColor];
    gLSClockWindow.userInteractionEnabled = NO; // NO intercepta toques por defecto
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    vc.view.userInteractionEnabled = YES;
    gLSClockWindow.rootViewController = vc;
    gLSClockWindow.hidden = YES;

    // Label del reloj
    gLSClockLabel = [[UILabel alloc] init];
    gLSClockLabel.textAlignment = NSTextAlignmentCenter;
    gLSClockLabel.textColor = [UIColor whiteColor];
    // Shadow para legibilidad en cualquier fondo
    gLSClockLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    gLSClockLabel.layer.shadowOffset = CGSizeZero;
    gLSClockLabel.layer.shadowRadius = 8.0f;
    gLSClockLabel.layer.shadowOpacity = 0.6f;
    gLSClockLabel.layer.shouldRasterize = YES;
    gLSClockLabel.layer.rasterizationScale = [UIScreen mainScreen].scale;
    gLSClockLabel.userInteractionEnabled = NO;
    gLSClockLabel.tag = 9001;
    [vc.view addSubview:gLSClockLabel];

    // Label de minutos (visible solo en modo split)
    gLSMinsLabel = [[UILabel alloc] init];
    gLSMinsLabel.textAlignment = NSTextAlignmentCenter;
    gLSMinsLabel.textColor = [UIColor whiteColor];
    gLSMinsLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    gLSMinsLabel.layer.shadowOffset = CGSizeZero;
    gLSMinsLabel.layer.shadowRadius = 8.0f;
    gLSMinsLabel.layer.shadowOpacity = 0.6f;
    gLSMinsLabel.layer.shouldRasterize = YES;
    gLSMinsLabel.layer.rasterizationScale = [UIScreen mainScreen].scale;
    gLSMinsLabel.userInteractionEnabled = NO;
    gLSMinsLabel.hidden = YES;
    gLSMinsLabel.tag = 9004;
    [vc.view addSubview:gLSMinsLabel];

    // Label de la fecha
    gLSDateLabel = [[UILabel alloc] init];
    gLSDateLabel.textAlignment = NSTextAlignmentCenter;
    gLSDateLabel.textColor = [UIColor whiteColor];
    gLSDateLabel.alpha = 0.85f;
    gLSDateLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    gLSDateLabel.layer.shadowOffset = CGSizeZero;
    gLSDateLabel.layer.shadowRadius = 6.0f;
    gLSDateLabel.layer.shadowOpacity = 0.5f;
    gLSDateLabel.layer.shouldRasterize = YES;
    gLSDateLabel.layer.rasterizationScale = [UIScreen mainScreen].scale;
    gLSDateLabel.userInteractionEnabled = NO;
    gLSDateLabel.tag = 9002;
    [vc.view addSubview:gLSDateLabel];

    // Vista de snapshot para detectar si el fondo es claro/oscuro
    UIView *bgSampleView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    bgSampleView.userInteractionEnabled = NO;
    bgSampleView.tag = 9003;
    [vc.view insertSubview:bgSampleView atIndex:0];
}

static BOOL lsIsBrightBackground(CGPoint center) {
    if (@available(iOS 13.0,*)) {
        UITraitCollection *tc = [UITraitCollection currentTraitCollection];
        return tc.userInterfaceStyle == UIUserInterfaceStyleLight;
    }
    return NO;
}

static NSArray *LSFontFams(void) { return @[@"System",@"Avenir Next",@"Futura",@"Helvetica Neue",@"Menlo",@"Courier New",@"Georgia",@"Gill Sans",@"DIN Alternate",@"Copperplate"]; }
static UIFont *LSFont(NSInteger idx, CGFloat sz, UIFontWeight w) {
    if (idx<=0||idx>=(NSInteger)LSFontFams().count) return [UIFont systemFontOfSize:sz weight:w];
    UIFont *f=[UIFont fontWithName:LSFontFams()[idx] size:sz]; return f?:[UIFont systemFontOfSize:sz weight:w];
}
static NSArray *LSGradPre(NSInteger s) {
    switch(s){case 0:return @[[UIColor colorWithRed:1 green:.4f blue:.2f alpha:1],[UIColor colorWithRed:1 green:.1f blue:.6f alpha:1]];case 1:return @[[UIColor colorWithRed:.1f green:.6f blue:1 alpha:1],[UIColor colorWithRed:.1f green:.9f blue:.8f alpha:1]];case 2:return @[[UIColor colorWithRed:.6f green:.1f blue:1 alpha:1],[UIColor colorWithRed:0 green:1 blue:.7f alpha:1]];case 3:return @[[UIColor colorWithRed:1 green:.2f blue:0 alpha:1],[UIColor colorWithRed:1 green:.8f blue:0 alpha:1]];case 4:return @[[UIColor colorWithRed:.7f green:.9f blue:1 alpha:1],[UIColor colorWithRed:.3f green:.5f blue:1 alpha:1]];default:return nil;}
}
static void LSGradLabel(UILabel *l, NSInteger style, UIColor *c1, UIColor *c2) {
    if (!l.text.length||l.bounds.size.width<2) return;
    CGSize sz=l.bounds.size;
    NSArray *pre=LSGradPre(style);
    UIColor *a=pre?pre[0]:(c1?:[UIColor whiteColor]), *b=pre?pre[1]:(c2?:[UIColor cyanColor]);
    UIGraphicsBeginImageContextWithOptions(sz,NO,[UIScreen mainScreen].scale);
    CGContextRef ctx=UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();
    CGGradientRef g=CGGradientCreateWithColors(cs,(__bridge CFArrayRef)@[(id)a.CGColor,(id)b.CGColor],NULL);
    CGContextDrawLinearGradient(ctx,g,CGPointZero,CGPointMake(sz.width,sz.height),0);
    CGGradientRelease(g);CGColorSpaceRelease(cs);
    UIImage *img=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();
    if(img) l.textColor=[UIColor colorWithPatternImage:img];
}
static void LSUpdateClockDisplay(void) {
    if (!gLSClockLabel || !gLSDateLabel) return;
    if (gLSEditModeActive) return;
    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    CGFloat sh = [UIScreen mainScreen].bounds.size.height;

    CGFloat clockCY = gLSClockPY > 0 ? gLSClockPY : sh * 0.38f;
    CGFloat clockX  = gLSClockPX > 0 ? gLSClockPX : sw * 0.5f;
    CGFloat dateX   = gLSDatePX  > 0 ? gLSDatePX  : sw * 0.5f;

    BOOL brightBG = lsIsBrightBackground(CGPointMake(clockX, clockCY));
    UIColor *textColor  = brightBG ? [UIColor colorWithWhite:0.08f alpha:1] : [UIColor whiteColor];
    UIColor *shadowCol  = brightBG ? [UIColor colorWithWhite:1 alpha:0.4f]  : [UIColor blackColor];

    // Alineacion del texto
    NSTextAlignment align = NSTextAlignmentCenter;
    if (gLSClockAlign == 1) align = NSTextAlignmentLeft;
    else if (gLSClockAlign == 2) align = NSTextAlignmentRight;

    // Obtener hora y minutos por separado
    NSDateFormatter *hf = [[NSDateFormatter alloc] init];
    hf.dateFormat = @"H"; // solo horas
    NSDateFormatter *mf = [[NSDateFormatter alloc] init];
    mf.dateFormat = @"mm"; // solo minutos

    NSString *hoursStr = [hf stringFromDate:[NSDate date]];
    NSString *minsStr  = [mf stringFromDate:[NSDate date]];
    CGFloat minsSize   = gLSMinsSize > 10 ? gLSMinsSize : gLSClockSize;

    UIFont *clockFont = LSFont(gLSClockFontIdx, gLSClockSize, lsWeightFor(gLSClockW));
    UIFont *minsFont  = LSFont(gLSClockFontIdx, minsSize, lsWeightFor(gLSClockW));

    void (^applyLabel)(UILabel*, NSString*, UIFont*) = ^(UILabel *l, NSString *txt, UIFont *f) {
        l.font = f; l.text = txt; l.textColor = textColor;
        l.textAlignment = align;
        l.layer.shadowColor = shadowCol.CGColor;
        l.alpha = gLSClockAlpha;
        [l sizeToFit];
    };

    if (gLSClockSplit && gLSMinsLabel) {
        gLSMinsLabel.hidden = NO;
        applyLabel(gLSClockLabel, hoursStr, clockFont);
        applyLabel(gLSMinsLabel,  minsStr,  minsFont);

        // Calcular el ancho maximo entre horas y minutos
        // Usar "00" como referencia para que siempre sea consistente
        CGSize refH = [@"00" sizeWithAttributes:@{NSFontAttributeName: clockFont}];
        CGSize refM = [@"00" sizeWithAttributes:@{NSFontAttributeName: minsFont}];
        CGFloat blockW = MAX(refH.width, refM.width) + 8; // padding

        CGFloat hH = gLSClockLabel.bounds.size.height;
        CGFloat mH = gLSMinsLabel.bounds.size.height;
        CGFloat gap = minsSize * 0.05f; // gap proporcional al tamaño
        CGFloat totalH = hH + mH + gap;
        CGFloat topY = clockCY - totalH / 2.0f;

        // Ambos labels con el mismo ancho y alineados igual
        gLSClockLabel.frame = CGRectMake(clockX - blockW/2, topY, blockW, hH);
        gLSMinsLabel.frame  = CGRectMake(clockX - blockW/2, topY + hH + gap, blockW, mH);

        // Alineacion dentro del bloque
        gLSClockLabel.textAlignment = align;
        gLSMinsLabel.textAlignment  = align;
    } else {
        // Modo normal: "10:29"
        if (gLSMinsLabel) gLSMinsLabel.hidden = YES;
        applyLabel(gLSClockLabel, lsCurrentTime(), clockFont);
        [gLSClockLabel sizeToFit];
        gLSClockLabel.center = CGPointMake(clockX, clockCY);
    }

    // Fecha — debajo del bloque del reloj
    CGFloat clockBottom = CGRectGetMaxY(gLSClockLabel.frame);
    if (gLSClockSplit && gLSMinsLabel && !gLSMinsLabel.hidden)
        clockBottom = CGRectGetMaxY(gLSMinsLabel.frame);
    CGFloat dateCY = gLSDatePY > 0 ? gLSDatePY : clockBottom + 10;

    gLSDateLabel.font  = LSFont(gLSDateFontIdx, gLSDateSize, UIFontWeightLight);
    gLSDateLabel.alpha = gLSDateAlpha;
    gLSDateLabel.text  = lsCurrentDate();
    gLSDateLabel.textColor = textColor;
    gLSDateLabel.textAlignment = align;
    gLSDateLabel.layer.shadowColor = shadowCol.CGColor;
    [gLSDateLabel sizeToFit];
    gLSDateLabel.center = CGPointMake(dateX, dateCY);
    // Gradient
    if (gLSClockGradient) {
        LSGradLabel(gLSClockLabel, gLSClockGradientStyle, gLSClockGradColor1, gLSClockGradColor2);
        if (gLSClockSplit && gLSMinsLabel && !gLSMinsLabel.hidden)
            LSGradLabel(gLSMinsLabel, gLSClockGradientStyle, gLSClockGradColor1, gLSClockGradColor2);
        LSGradLabel(gLSDateLabel, gLSClockGradientStyle, gLSClockGradColor1, gLSClockGradColor2);
    }
    // Custom labels
    UIView *clkRoot = gLSClockWindow.rootViewController.view;
    for (UIView *vv in [clkRoot.subviews copy]) if (vv.tag>=9500&&vv.tag<9600) [vv removeFromSuperview];
    if (gLSCustomLabels) for (NSInteger i=0;i<(NSInteger)gLSCustomLabels.count&&i<20;i++) {
        NSDictionary *ld=gLSCustomLabels[i]; if(![ld isKindOfClass:[NSDictionary class]])continue;
        UILabel *cl=[[UILabel alloc]init]; cl.text=ld[@"text"]?:@"Label";
        CGFloat csz=[ld[@"size"]floatValue]>0?[ld[@"size"]floatValue]:16;
        cl.font=LSFont(gLSClockFontIdx,csz,UIFontWeightMedium);
        cl.textColor=textColor; cl.alpha=[ld[@"alpha"]floatValue]>0?[ld[@"alpha"]floatValue]:1;
        cl.textAlignment=NSTextAlignmentCenter; cl.layer.shadowColor=shadowCol.CGColor;
        cl.layer.shadowOffset=CGSizeZero; cl.layer.shadowRadius=6; cl.layer.shadowOpacity=0.5f;
        [cl sizeToFit]; cl.center=CGPointMake([ld[@"x"]floatValue]>0?[ld[@"x"]floatValue]:sw*0.5f,[ld[@"y"]floatValue]>0?[ld[@"y"]floatValue]:sh*0.7f+i*30);
        cl.tag=9500+i; cl.userInteractionEnabled=NO;
        if(gLSClockGradient) LSGradLabel(cl,gLSClockGradientStyle,gLSClockGradColor1,gLSClockGradColor2);
        [clkRoot addSubview:cl];
    }
}

// Timer que actualiza el texto del reloj cada segundo
static NSTimer *gLSClockTimer = nil;

// ─── HOOK: Reloj (SBFLockScreenDateView) ─────────────────────
// Ocultar el reloj original y usar nuestro label custom
static IMP orig_lsClockLayout = NULL;
static void hooked_lsClockLayout(UIView *self, SEL _cmd) {
    gLSClockViewRef = self;
    @try {
        ((void(*)(id,SEL))orig_lsClockLayout)(self, _cmd);
        // Ocultar la vista original — usamos nuestro label
        self.hidden = YES;
        self.alpha = 0;
    } @catch(NSException *e) {}

    // Inicializar nuestra window la primera vez — pero NO mostrar todavia
    // Solo se muestra cuando aparece el lockscreen (hooked_lsDashAppear)
    if (!gLSClockWindow) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LSSetupClockWindow();
            gLSClockWindow.hidden = YES; // oculta hasta lockscreen
            LSUpdateClockDisplay();
            if (!gLSClockTimer) {
                gLSClockTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                    target:[NSBlockOperation blockOperationWithBlock:^{ LSUpdateClockDisplay(); }]
                    selector:@selector(main) userInfo:nil repeats:YES];
            }
        });
    }
}

// ─── HOOK: Fecha (SBFLockScreenDateSubtitleDateView) ─────────
// Ocultar la fecha original — usamos nuestro label
static IMP orig_lsDateLayout = NULL;
static void hooked_lsDateLayout(UIView *self, SEL _cmd) {
    gLSDateViewRef = self;
    @try {
        ((void(*)(id,SEL))orig_lsDateLayout)(self, _cmd);
        self.hidden = YES;
        self.alpha = 0;
    } @catch(NSException *e) {}
}

// ─── HOOK: Notificaciones — Velvet2 style ────────────────────
// ═══════════════════════════════════════════════════════════════
// NOTIFICACIONES — Velvet2 exact style
// Hook NCNotificationShortLookViewController
// ═══════════════════════════════════════════════════════════════

// Aplicar todos los efectos Velvet2 a una notif — llamado desde los hooks
static void LSApplyVelvetEffects(UIView *velvetView, UIView *materialView,
                                  UIImage *appIcon, CGFloat cornerRadius) {
    if (!velvetView || !gLSNotifEnabled) return;

    // ── Corner radius ──────────────────────────────────────
    materialView.layer.continuousCorners = (cornerRadius < materialView.frame.size.height / 2);
    materialView.layer.cornerRadius = MIN(cornerRadius, materialView.frame.size.height / 2);
    velvetView.layer.continuousCorners = (cornerRadius < velvetView.frame.size.height / 2);
    velvetView.layer.cornerRadius = MIN(cornerRadius, velvetView.frame.size.height / 2);

    UIColor *iconColor = LSExtractIconColor(appIcon);

    // ── Background tint ───────────────────────────────────
    if (gLSBgEnabled) {
        UIColor *bg = (gLSBgType == 1 && gLSBgColor)
            ? [gLSBgColor colorWithAlphaComponent:gLSBgIconAlpha]
            : [iconColor  colorWithAlphaComponent:gLSBgIconAlpha];
        velvetView.backgroundColor = bg;
        materialView.alpha = 0;   // ocultar blur nativo, usamos nuestro color
    } else {
        velvetView.backgroundColor = [UIColor clearColor];
        materialView.alpha = 1;
    }

    // ── Border ────────────────────────────────────────────
    if (gLSBorderEnabled) {
        UIColor *bc = (gLSBorderType == 1 && gLSBorderColor)
            ? [gLSBorderColor colorWithAlphaComponent:0.9f]
            : [iconColor colorWithAlphaComponent:gLSBorderIconAlpha];
        velvetView.layer.borderWidth = gLSBorderWidth;
        velvetView.layer.borderColor = bc.CGColor;
    } else {
        velvetView.layer.borderWidth = 0;
        velvetView.layer.borderColor = nil;
    }

    // ── Shadow / glow ─────────────────────────────────────
    if (gLSShadowEnabled) {
        UIColor *sc2 = (gLSShadowType == 1 && gLSShadowColor)
            ? gLSShadowColor
            : [iconColor colorWithAlphaComponent:gLSShadowIconAlpha];
        materialView.layer.shadowRadius  = gLSShadowWidth;
        materialView.layer.shadowOffset  = CGSizeZero;
        materialView.layer.shadowColor   = sc2.CGColor;
        materialView.layer.shadowOpacity = 1.0f;
    } else {
        materialView.layer.shadowOpacity = 0;
    }

    // ── Line accent ───────────────────────────────────────
    // Quitar layer anterior
    for (CALayer *l in [velvetView.layer.sublayers copy])
        if ([l.name isEqualToString:@"ALGVelvetLine"]) [l removeFromSuperlayer];

    if (gLSLineEnabled) {
        UIColor *lc = (gLSLineType == 1 && gLSLineColor)
            ? gLSLineColor : iconColor;
        CGFloat lw = gLSLineWidth;
        CGFloat fw = velvetView.bounds.size.width, fh = velvetView.bounds.size.height;
        CGRect lf;
        switch (gLSLinePosition) {
            case 0: lf = CGRectMake(0,     0,     lw, fh); break; // left
            case 1: lf = CGRectMake(fw-lw, 0,     lw, fh); break; // right
            case 2: lf = CGRectMake(0,     0,     fw, lw); break; // top
            case 3: lf = CGRectMake(0,     fh-lw, fw, lw); break; // bottom
            default: lf = CGRectMake(0,0,lw,fh);
        }
        CALayer *ll = [CALayer layer];
        ll.name = @"ALGVelvetLine";
        ll.frame = lf; ll.backgroundColor = lc.CGColor;
        [velvetView.layer addSublayer:ll];
    }
}

// ── velvetView asociado a cada NCNotificationShortLookViewController ──
static const char kVelvetViewKey = 0;

// Helper: obtener velvetView (lo crea si no existe, igual que Velvet2 viewDidLoad)
static UIView *LSGetOrCreateVelvetView(UIViewController *vc) {
    UIView *vv = objc_getAssociatedObject(vc, &kVelvetViewKey);
    if (vv) return vv;

    NCNotificationShortLookView *shortLookView =
        (NCNotificationShortLookView *)[vc valueForKey:@"viewForPreview"];
    if (!shortLookView) return nil;
    UIView *materialView = shortLookView.backgroundMaterialView;
    if (!materialView) return nil;

    vv = [[UIView alloc] init];
    // Insertar justo encima del materialView (index 1, igual que Velvet2)
    [materialView.superview insertSubview:vv atIndex:1];
    vv.clipsToBounds = YES;
    objc_setAssociatedObject(vc, &kVelvetViewKey, vv, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return vv;
}

// ── Hook: viewDidLayoutSubviews ────────────────────────────────
static IMP orig_ncLayoutSubviews = NULL;
static void hooked_ncLayoutSubviews(UIViewController *self, SEL _cmd) {
    if (orig_ncLayoutSubviews) ((void(*)(id,SEL))orig_ncLayoutSubviews)(self, _cmd);
    @try {
        // Registrar observer de actualización en tiempo real — una sola vez
        if (!objc_getAssociatedObject(self, "ncVelvetObs")) {
            [[NSNotificationCenter defaultCenter] addObserverForName:@"ALGVelvetUpdateStyle"
                object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
                // Forzar re-layout que re-aplicará los efectos
                [self.view setNeedsLayout];
                [self.view layoutIfNeeded];
            }];
            objc_setAssociatedObject(self, "ncVelvetObs", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        NCNotificationShortLookView *shortLookView =
            (NCNotificationShortLookView *)[self valueForKey:@"viewForPreview"];
        if (!shortLookView || shortLookView.frame.size.width == 0) return;

        UIView *velvetView = LSGetOrCreateVelvetView(self);
        UIView *materialView = shortLookView.backgroundMaterialView;
        if (!velvetView || !materialView) return;

        velvetView.frame = materialView.frame;

        NCNotificationSeamlessContentView *contentView =
            (NCNotificationSeamlessContentView *)[shortLookView valueForKey:@"notificationContentView"];
        UIImage *appIcon = contentView.prominentIcon ?: contentView.subordinateIcon;

        CGFloat defRadius = 19.0f;
        if (@available(iOS 16.0,*)) defRadius = 23.5f;
        CGFloat cornerRadius = gLSNotifRadius ?: defRadius;

        LSApplyVelvetEffects(velvetView, materialView, appIcon, cornerRadius);
        self.view.alpha = gLSNotifAlpha;

    } @catch(NSException *e) {
    }
}

// ── Hook: viewDidAppear — para title/message/date/icon (igual Velvet2) ──
static IMP orig_ncViewDidAppear = NULL;
static void hooked_ncViewDidAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_ncViewDidAppear) ((void(*)(id,SEL,BOOL))orig_ncViewDidAppear)(self, _cmd, animated);
    @try {
        if (!gLSNotifEnabled) return;

        NCNotificationShortLookView *shortLookView =
            (NCNotificationShortLookView *)[self valueForKey:@"viewForPreview"];
        NCNotificationSeamlessContentView *contentView =
            (NCNotificationSeamlessContentView *)[shortLookView valueForKey:@"notificationContentView"];

        // Title bold
        UILabel *title   = (UILabel *)[contentView valueForKey:@"primaryTextLabel"];
        UILabel *message = (UILabel *)[contentView valueForKey:@"secondaryTextElement"];
        UILabel *date    = (UILabel *)[contentView valueForKey:@"dateLabel"];

        if (gLSNotifTitleBold && title)
            title.font = [UIFont systemFontOfSize:title.font.pointSize weight:UIFontWeightSemibold];

        // Ícono
        NCBadgedIconView *badgeView =
            (NCBadgedIconView *)[contentView valueForKey:@"badgedIconView"];
        UIView *iconView = badgeView.iconView;
        if (iconView) {
            if (!gLSNotifShowIcon) {
                iconView.alpha = 0; iconView.hidden = YES;
                // Mover labels a la izquierda — igual que Velvet2 toggleAppIconVisibility
                CGFloat shift = iconView.frame.size.width + 8;
                title.frame   = CGRectMake(title.frame.origin.x   - shift, title.frame.origin.y,
                                           title.frame.size.width  + shift, title.frame.size.height);
                message.frame = CGRectMake(message.frame.origin.x - shift, message.frame.origin.y,
                                           message.frame.size.width+ shift, message.frame.size.height);
            } else if (iconView.hidden) {
                iconView.alpha = 1; iconView.hidden = NO;
            }
        }

        // Date filter (Velvet2 lo hace igual)
        if (date) date.layer.filters = nil;

    } @catch(NSException *e) {
    }
}

// ── Hook: NCNotificationSummaryPlatterView.layoutSubviews ──────
// Para las notificaciones agrupadas (stacked) — igual que Velvet2
static IMP orig_summaryLayout = NULL;
static void hooked_summaryLayout(UIView *self, SEL _cmd) {
    if (orig_summaryLayout) ((void(*)(id,SEL))orig_summaryLayout)(self, _cmd);
    @try {
        if (!gLSNotifEnabled) return;
        UIView *materialView = self.subviews.count > 0 ? self.subviews[0] : nil;
        if (!materialView || self.frame.size.width == 0) return;

        // velvetView asociado al platter
        UIView *vv = objc_getAssociatedObject(self, &kVelvetViewKey);
        if (!vv) {
            vv = [[UIView alloc] init];
            [self insertSubview:vv atIndex:1];
            vv.clipsToBounds = YES;
            objc_setAssociatedObject(self, &kVelvetViewKey, vv, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        vv.frame = materialView.frame;

        CGFloat defRadius = 19.0f;
        if (@available(iOS 16.0,*)) defRadius = 23.5f;
        CGFloat cornerRadius = gLSNotifRadius ?: defRadius;
        LSApplyVelvetEffects(vv, materialView, nil, cornerRadius);

    } @catch(NSException *e) {
    }
}

// Notification para actualizar en tiempo real desde el panel (igual que Velvet2)
static void LSPostUpdateNotification(void) {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"ALGVelvetUpdateStyle" object:nil];
}

// ═══════════════════════════════════════════════════════════════
// PANEL DE CONFIGURACIÓN LS — rediseñado
// ═══════════════════════════════════════════════════════════════

static ALGPassthroughWindow *gLSWindow = nil;
static UIWindow *gLSButtonWindow = nil;

// ─── Paleta de colores preset ────────────────────────────────
static NSArray *LSPresetColors(void) {
    return @[
        [UIColor colorWithWhite:1 alpha:0],               // Auto (icon)
        [UIColor colorWithRed:1   green:1   blue:1   alpha:1], // White
        [UIColor colorWithRed:.95f green:.25f blue:.3f  alpha:1], // Red
        [UIColor colorWithRed:.2f  green:.6f  blue:1   alpha:1], // Blue
        [UIColor colorWithRed:.15f green:.9f  blue:.5f  alpha:1], // Green
        [UIColor colorWithRed:1   green:.8f  blue:0   alpha:1], // Gold
        [UIColor colorWithRed:.75f green:.2f  blue:1   alpha:1], // Purple
        [UIColor colorWithRed:1   green:.45f blue:.1f  alpha:1], // Orange
        [UIColor colorWithRed:.0f  green:.9f  blue:.9f  alpha:1], // Cyan
        [UIColor colorWithRed:1   green:.4f  blue:.7f  alpha:1], // Pink
    ];
}
static NSArray *LSPresetNames(void) {
    return @[@"Auto",@"White",@"Red",@"Blue",@"Green",@"Gold",@"Purple",@"Orange",@"Cyan",@"Pink"];
}

// ─── Helpers de UI ───────────────────────────────────────────
static UILabel *LSMakeLabel(NSString *text, CGFloat size, UIFontWeight w, UIColor *color, CGRect f) {
    UILabel *l = [[UILabel alloc] initWithFrame:f];
    l.text = text; l.font = [UIFont systemFontOfSize:size weight:w];
    l.textColor = color; l.userInteractionEnabled = NO;
    return l;
}

// Separador fino
static UIView *LSSep(CGFloat x, CGFloat y, CGFloat w) {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(x,y,w,0.5f)];
    v.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1f];
    v.userInteractionEnabled = NO; return v;
}

// Crea un toggle row y devuelve el UISwitch
static UISwitch *LSToggleRow(UIView *parent, NSString *title, BOOL on, CGFloat x, CGFloat y, CGFloat w) {
    UILabel *l = LSMakeLabel(title, 14, UIFontWeightRegular, [UIColor whiteColor],
                             CGRectMake(x, y+10, w-70, 18));
    [parent addSubview:l];
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(x+w-60, y+6, 51, 31)];
    sw.on = on; [parent addSubview:sw]; return sw;
}

// Crea slider row y devuelve el UISlider
static UISlider *LSSliderRow(UIView *parent, NSString *title, CGFloat minV, CGFloat maxV,
                              CGFloat val, CGFloat x, CGFloat y, CGFloat w) {
    UILabel *cap = LSMakeLabel(title, 10, UIFontWeightRegular,
                               [UIColor colorWithWhite:1 alpha:0.45f], CGRectMake(x,y,w,12));
    [parent addSubview:cap];
    UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(x, y+14, w, 28)];
    sl.minimumValue = minV; sl.maximumValue = maxV; sl.value = val;
    [parent addSubview:sl]; return sl;
}

// Color picker row — devuelve el tag base de los botones
static NSInteger LSColorPickerRow(UIView *parent, NSString *title, CGFloat x, CGFloat y,
                                   CGFloat pw, NSInteger tagBase,
                                   NSString *prefKey,
                                   UIColor * __strong *globalColorRef) {
    UILabel *cap = LSMakeLabel(title, 10, UIFontWeightSemibold,
                               [UIColor colorWithWhite:1 alpha:0.4f],
                               CGRectMake(x, y, pw, 12));
    [parent addSubview:cap]; y += 14;

    NSArray *colors = LSPresetColors();
    CGFloat bw = (pw) / (CGFloat)colors.count;
    for (NSInteger i = 0; i < (NSInteger)colors.count; i++) {
        ALGBlockButton *btn = [ALGBlockButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(x + i*bw, y, bw-2, 22);
        btn.layer.cornerRadius = 6;
        if (@available(iOS 13.0,*)) btn.layer.cornerCurve = kCACornerCurveContinuous;
        if (i == 0) {
            // Auto
            btn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12f];
            btn.layer.borderWidth = 0.8f;
            btn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.3f].CGColor;
            UILabel *al = LSMakeLabel(@"A", 10, UIFontWeightBold, [UIColor whiteColor],
                                     CGRectMake(0,0,bw-2,22));
            al.textAlignment = NSTextAlignmentCenter; [btn addSubview:al];
        } else {
            btn.backgroundColor = [colors[i] colorWithAlphaComponent:0.8f];
        }
        btn.tag = tagBase + i;
        UIColor *selectedColor = colors[i];
        UIColor * __strong *gRef = globalColorRef;
        __weak UIView *wp = parent;
        NSString *pk = prefKey;
        btn.actionBlock = ^{
            NSMutableDictionary *pr = LSPrefs();
            if (i == 0) {
                [pr removeObjectForKey:[pk stringByAppendingString:@"Type"]];
                LSColorToPrefs(pr, pk, nil);
                if (gRef) *gRef = nil;
            } else {
                pr[pk] = @"color";
                LSColorToPrefs(pr, pk, selectedColor);
                if (gRef) *gRef = selectedColor;
            }
            LSSavePrefs(pr);
            // Feedback visual
            for (NSInteger j=0; j<(NSInteger)[LSPresetColors() count]; j++) {
                UIView *o = [wp viewWithTag:tagBase+j];
                o.layer.borderWidth = (j==i) ? 2.0f : (j==0 ? 0.8f : 0);
                o.layer.borderColor = [UIColor whiteColor].CGColor;
            }
        };
        [btn addTarget:btn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [parent addSubview:btn];
    }
    return tagBase;
}

// ─── Sección header dentro de un scroll page ─────────────────
static UILabel *LSSectionHeader(UIView *parent, NSString *text, CGFloat x, CGFloat y, CGFloat w) {
    UILabel *l = LSMakeLabel(text, 10, UIFontWeightSemibold,
                             [UIColor colorWithWhite:1 alpha:0.38f],
                             CGRectMake(x,y,w,13));
    [parent addSubview:l]; return l;
}

// ─── Cerrar panel ────────────────────────────────────────────
static BOOL gLSPanelOpen = NO;
static NSInteger gLSNavDepth = 0;
static void LSClosePanel(void) {
    if (!gLSPanelOpen) return; gLSPanelOpen = NO; gLSNavDepth = 0;
    UIView *panel=[gLSWindow.rootViewController.view viewWithTag:9999];
    UIView *dim=[gLSWindow.rootViewController.view viewWithTag:9998];
    if (!panel){gLSWindow.hidden=YES;return;}
    [UIView animateWithDuration:0.18f delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        panel.alpha=0;panel.transform=CGAffineTransformMakeScale(0.94f,0.94f);if(dim)dim.alpha=0;
    } completion:^(BOOL d){gLSWindow.hidden=YES;gLSWindow.userInteractionEnabled=NO;[panel removeFromSuperview];[dim removeFromSuperview];
        dispatch_async(dispatch_get_main_queue(),^{gLSButtonWindow.hidden=NO;if(gLSClockWindow)gLSClockWindow.hidden=NO;});}];
}


static void LSPush(UIView *c,UIView *pg,CGFloat pw){pg.frame=CGRectMake(pw,0,c.bounds.size.width,c.bounds.size.height);pg.tag=8900+(++gLSNavDepth);pg.backgroundColor=[UIColor colorWithRed:.02f green:.02f blue:.08f alpha:1];[c addSubview:pg];[UIView animateWithDuration:.32f delay:0 usingSpringWithDamping:.88f initialSpringVelocity:.5f options:UIViewAnimationOptionAllowUserInteraction animations:^{for(UIView *v in c.subviews)if(v.tag>=8900&&v.tag<pg.tag)v.frame=CGRectMake(-pw*.3f,0,v.bounds.size.width,v.bounds.size.height);pg.frame=CGRectMake(0,0,c.bounds.size.width,c.bounds.size.height);}completion:^(BOOL d){for(UIView *v in c.subviews)if(v.tag>=8900&&v.tag<pg.tag)v.hidden=YES;}];}
static void LSPop(UIView *c,CGFloat pw){UIView *top=nil,*prev=nil;for(UIView *v in c.subviews)if(v.tag>=8900){if(!top||v.tag>top.tag){prev=top;top=v;}else if(!prev||v.tag>prev.tag)prev=v;}if(!top)return;gLSNavDepth--;if(prev){prev.hidden=NO;prev.frame=CGRectMake(-pw*.3f,0,prev.bounds.size.width,prev.bounds.size.height);}[UIView animateWithDuration:.28f delay:0 usingSpringWithDamping:.9f initialSpringVelocity:.4f options:UIViewAnimationOptionAllowUserInteraction animations:^{top.frame=CGRectMake(pw,0,top.bounds.size.width,top.bounds.size.height);if(prev)prev.frame=CGRectMake(0,0,prev.bounds.size.width,prev.bounds.size.height);}completion:^(BOOL d){[top removeFromSuperview];}];}
static UIView *LSPgHdr(NSString *t,CGFloat w,UIView *nc,CGFloat pw){UIView *h=[[UIView alloc]initWithFrame:CGRectMake(0,0,w,48)];CAGradientLayer *s=[CAGradientLayer layer];s.frame=CGRectMake(0,47.5f,w,.5f);s.colors=@[(id)[UIColor colorWithWhite:1 alpha:0].CGColor,(id)[UIColor colorWithWhite:1 alpha:.18f].CGColor,(id)[UIColor colorWithWhite:1 alpha:0].CGColor];s.startPoint=CGPointMake(0,.5f);s.endPoint=CGPointMake(1,.5f);[h.layer addSublayer:s];ALGBlockButton *b=[ALGBlockButton buttonWithType:UIButtonTypeCustom];b.frame=CGRectMake(4,6,60,36);if(@available(iOS 13.0,*)){UIImageView *cv=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"chevron.left" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold]]];cv.frame=CGRectMake(12,10,14,16);cv.tintColor=[UIColor colorWithRed:.6f green:.2f blue:1 alpha:1];cv.userInteractionEnabled=NO;[b addSubview:cv];}__weak UIView *wc=nc;b.actionBlock=^{LSPop(wc,pw);};[b addTarget:b action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[h addSubview:b];UILabel *l=[[UILabel alloc]initWithFrame:CGRectMake(60,6,w-120,36)];l.text=t;l.font=[UIFont systemFontOfSize:16 weight:UIFontWeightBold];l.textColor=[UIColor whiteColor];l.textAlignment=NSTextAlignmentCenter;l.userInteractionEnabled=NO;[h addSubview:l];return h;}
static ALGBlockButton *LSCd(NSString *t,NSString *ic,NSString *sub,CGFloat y,CGFloat w,UIColor *col){ALGBlockButton *b=[ALGBlockButton buttonWithType:UIButtonTypeCustom];b.frame=CGRectMake(12,y,w-24,58);b.backgroundColor=[UIColor colorWithWhite:1 alpha:.045f];b.layer.cornerRadius=14;if(@available(iOS 13.0,*))b.layer.cornerCurve=kCACornerCurveContinuous;if(@available(iOS 13.0,*)){UIImageView *iv=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:ic withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold]]];iv.frame=CGRectMake(16,18,22,22);iv.tintColor=col;iv.contentMode=UIViewContentModeScaleAspectFit;iv.userInteractionEnabled=NO;[b addSubview:iv];}UILabel *l=[[UILabel alloc]initWithFrame:CGRectMake(48,sub?10:0,w-24-80,sub?22:58)];l.text=t;l.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];l.textColor=[UIColor whiteColor];l.userInteractionEnabled=NO;[b addSubview:l];if(sub){UILabel *s=[[UILabel alloc]initWithFrame:CGRectMake(48,30,w-24-80,16)];s.text=sub;s.font=[UIFont systemFontOfSize:11];s.textColor=[UIColor colorWithWhite:1 alpha:.38f];s.userInteractionEnabled=NO;[b addSubview:s];}if(@available(iOS 13.0,*)){UIImageView *cv=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"chevron.right" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightMedium]]];cv.frame=CGRectMake(w-24-28,21,14,14);cv.tintColor=[UIColor colorWithWhite:1 alpha:.22f];cv.userInteractionEnabled=NO;[b addSubview:cv];}return b;}
static ALGBlockButton *LSGBtn(NSString *t,NSString *sf,NSArray *gc,CGRect fr){ALGBlockButton *b=[ALGBlockButton buttonWithType:UIButtonTypeCustom];b.frame=fr;b.layer.cornerRadius=14;if(@available(iOS 13.0,*))b.layer.cornerCurve=kCACornerCurveContinuous;b.layer.borderWidth=.5f;b.layer.borderColor=[UIColor colorWithWhite:1 alpha:.18f].CGColor;UIVisualEffectView *bv=[[UIVisualEffectView alloc]initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];bv.frame=CGRectMake(0,0,fr.size.width,fr.size.height);bv.layer.cornerRadius=14;if(@available(iOS 13.0,*))bv.layer.cornerCurve=kCACornerCurveContinuous;bv.layer.masksToBounds=YES;bv.userInteractionEnabled=NO;[b addSubview:bv];CAGradientLayer *gl=[CAGradientLayer layer];gl.frame=CGRectMake(0,0,fr.size.width,fr.size.height);gl.cornerRadius=14;NSMutableArray *cg=[NSMutableArray array];for(UIColor *c in gc)[cg addObject:(id)c.CGColor];gl.colors=cg;gl.startPoint=CGPointMake(0,0);gl.endPoint=CGPointMake(1,1);[b.layer addSublayer:gl];UILabel *l=[[UILabel alloc]init];l.text=t;l.font=[UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];l.textColor=[UIColor whiteColor];l.userInteractionEnabled=NO;[l sizeToFit];if(@available(iOS 13.0,*)){UIImageView *iv=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:sf withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightMedium]]];iv.tintColor=[UIColor whiteColor];iv.userInteractionEnabled=NO;CGFloat tw=16+5+l.bounds.size.width,sx=(fr.size.width-tw)/2;iv.frame=CGRectMake(sx,(fr.size.height-16)/2,16,16);l.frame=CGRectMake(sx+21,(fr.size.height-l.bounds.size.height)/2,l.bounds.size.width,l.bounds.size.height);[b addSubview:iv];}else{l.frame=fr;l.textAlignment=NSTextAlignmentCenter;}[b addSubview:l];return b;}
// Font picker row
static void LSFontRow(UIScrollView *sc,CGFloat pad,CGFloat *y,CGFloat cw,NSInteger cur,NSInteger tag,NSInteger *gRef){
    NSArray *ff=LSFontFams();CGFloat bw=(cw-4)/3.0f;
    for(NSInteger i=0;i<(NSInteger)ff.count;i++){ALGBlockButton *fb=[ALGBlockButton buttonWithType:UIButtonTypeCustom];fb.frame=CGRectMake(pad+(i%3)*(bw+2),*y+(i/3)*30,bw,26);[fb setTitle:ff[i] forState:UIControlStateNormal];fb.titleLabel.font=[UIFont systemFontOfSize:9 weight:UIFontWeightMedium];fb.titleLabel.adjustsFontSizeToFitWidth=YES;fb.layer.cornerRadius=7;fb.backgroundColor=cur==i?[UIColor colorWithRed:.22f green:.55f blue:1 alpha:.85f]:[UIColor colorWithWhite:1 alpha:.1f];[fb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];fb.tag=tag+i;NSInteger fi=i;__weak UIScrollView *ws=sc;NSInteger *gr=gRef;fb.actionBlock=^{for(NSInteger j=0;j<(NSInteger)ff.count;j++)((UIButton*)[ws viewWithTag:tag+j]).backgroundColor=[UIColor colorWithWhite:1 alpha:.1f];((UIButton*)[ws viewWithTag:tag+fi]).backgroundColor=[UIColor colorWithRed:.22f green:.55f blue:1 alpha:.85f];if(gr)*gr=fi;LSForceRealtime();};[fb addTarget:fb action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[sc addSubview:fb];}
    *y+=((ff.count+2)/3)*30+6;
}

#define ROWH 44.0f
static void LSShowPanel(void) {
    if (!gLSWindow) return; gLSWindow.hidden=NO;gLSWindow.userInteractionEnabled=YES;
    UIView *root=gLSWindow.rootViewController.view;
    if (gLSPanelOpen){LSClosePanel();return;} gLSPanelOpen=YES;gLSNavDepth=0;
    for(UIView *v in [root.subviews copy])[v removeFromSuperview];
    CGFloat sw=[UIScreen mainScreen].bounds.size.width,sh=[UIScreen mainScreen].bounds.size.height;
    CGFloat pw=MIN(sw-32,340),ph=MIN(sh*.82f,620),px=(sw-pw)/2,py=(sh-ph)/2;
    UIView *dim=[[UIView alloc]initWithFrame:[UIScreen mainScreen].bounds];dim.backgroundColor=[UIColor colorWithWhite:0 alpha:.35f];dim.tag=9998;dim.alpha=0;
    ALGBlockButton *db=[ALGBlockButton buttonWithType:UIButtonTypeCustom];db.frame=dim.bounds;db.actionBlock=^{LSClosePanel();};[db addTarget:db action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[dim addSubview:db];[root addSubview:dim];
    UIView *shd=[[UIView alloc]initWithFrame:CGRectMake(px,py,pw,ph)];shd.backgroundColor=[UIColor clearColor];shd.layer.cornerRadius=28;shd.layer.shadowColor=[UIColor colorWithRed:.3f green:.1f blue:.7f alpha:.5f].CGColor;shd.layer.shadowOpacity=.8f;shd.layer.shadowRadius=28;shd.layer.shadowOffset=CGSizeMake(0,10);shd.userInteractionEnabled=NO;shd.tag=8800;[root addSubview:shd];
    UIView *panel=ALGMakeGlassPanel(CGRectMake(px,py,pw,ph));panel.tag=9999;
    UIView *nc=[[UIView alloc]initWithFrame:CGRectMake(0,0,pw,ph)];nc.clipsToBounds=YES;nc.userInteractionEnabled=YES;[panel addSubview:nc];
    UIView *home=[[UIView alloc]initWithFrame:CGRectMake(0,0,pw,ph)];home.tag=8900;home.userInteractionEnabled=YES;
    {
        UIView *pill=[[UIView alloc]initWithFrame:CGRectMake((pw-36)/2,8,36,4)];pill.backgroundColor=[UIColor colorWithWhite:1 alpha:.2f];pill.layer.cornerRadius=2;[home addSubview:pill];
        UILabel *ttl=[[UILabel alloc]initWithFrame:CGRectMake(0,20,pw,24)];ttl.text=@"Lockscreen";ttl.font=[UIFont systemFontOfSize:18 weight:UIFontWeightBold];ttl.textColor=[UIColor whiteColor];ttl.textAlignment=NSTextAlignmentCenter;ttl.userInteractionEnabled=NO;[home addSubview:ttl];
        UILabel *sub=[[UILabel alloc]initWithFrame:CGRectMake(0,44,pw,14)];sub.text=@"by AldazDev";sub.font=[UIFont systemFontOfSize:11];sub.textColor=[UIColor colorWithWhite:1 alpha:.3f];sub.textAlignment=NSTextAlignmentCenter;sub.userInteractionEnabled=NO;[home addSubview:sub];
        CAGradientLayer *hs=[CAGradientLayer layer];hs.frame=CGRectMake(0,65,pw,.5f);hs.colors=@[(id)[UIColor colorWithWhite:1 alpha:0].CGColor,(id)[UIColor colorWithWhite:1 alpha:.18f].CGColor,(id)[UIColor colorWithWhite:1 alpha:0].CGColor];hs.startPoint=CGPointMake(0,.5f);hs.endPoint=CGPointMake(1,.5f);[home.layer addSublayer:hs];
        ALGBlockButton *xBtn=[ALGBlockButton buttonWithType:UIButtonTypeCustom];xBtn.frame=CGRectMake(pw-44,12,34,34);xBtn.layer.cornerRadius=17;xBtn.backgroundColor=[UIColor colorWithWhite:1 alpha:.08f];UILabel *xL=[[UILabel alloc]initWithFrame:CGRectMake(0,0,34,34)];xL.text=@"\u2715";xL.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];xL.textColor=[UIColor colorWithWhite:1 alpha:.45f];xL.textAlignment=NSTextAlignmentCenter;xL.userInteractionEnabled=NO;[xBtn addSubview:xL];xBtn.actionBlock=^{LSClosePanel();};[xBtn addTarget:xBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[home addSubview:xBtn];
        CGFloat cy=80;__weak UIView *wnc=nc;
        // ══ CLOCK ══
        ALGBlockButton *c1=LSCd(@"Clock",@"clock.fill",@"Size, weight, split, font, gradient",cy,pw,[UIColor colorWithRed:.22f green:.55f blue:1 alpha:1]);
        c1.actionBlock=^{
            UIView *pg=[[UIView alloc]initWithFrame:CGRectMake(0,0,pw,ph)];pg.userInteractionEnabled=YES;[pg addSubview:LSPgHdr(@"Clock",pw,wnc,pw)];
            UIScrollView *sc=[[UIScrollView alloc]initWithFrame:CGRectMake(0,48,pw,ph-48)];sc.showsVerticalScrollIndicator=NO;sc.bounces=YES;[pg addSubview:sc];
            CGFloat y=12,pad=16,cw=pw-pad*2; UIColor *ac=[UIColor colorWithRed:.22f green:.55f blue:1 alpha:1];
            LSSectionHeader(sc,@"SIZE",pad,y,cw);y+=22;
            UISlider *sl=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];sl.minimumValue=30;sl.maximumValue=120;sl.value=gLSClockSize;sl.minimumTrackTintColor=ac;ALGBlockButton *p0=[ALGBlockButton new];p0.actionBlock=^{gLSClockSize=sl.value;LSForceRealtime();};[sl addTarget:p0 action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(sl,"p",p0,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[sc addSubview:sl];y+=34;
            NSArray *wts=@[@"Thin",@"Light",@"Reg",@"Med",@"Bold"];CGFloat wbw=cw/5;
            for(NSInteger i=0;i<5;i++){ALGBlockButton *wb=[ALGBlockButton buttonWithType:UIButtonTypeCustom];wb.frame=CGRectMake(pad+i*wbw,y,wbw-3,26);[wb setTitle:wts[i] forState:UIControlStateNormal];wb.titleLabel.font=[UIFont systemFontOfSize:10 weight:UIFontWeightMedium];wb.layer.cornerRadius=8;wb.backgroundColor=gLSClockW==i?ac:[UIColor colorWithWhite:1 alpha:.1f];[wb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];wb.tag=200+i;NSInteger wi=i;__weak UIScrollView *ws=sc;wb.actionBlock=^{for(NSInteger j=0;j<5;j++)((UIButton*)[ws viewWithTag:200+j]).backgroundColor=[UIColor colorWithWhite:1 alpha:.1f];((UIButton*)[ws viewWithTag:200+wi]).backgroundColor=ac;gLSClockW=wi;LSForceRealtime();};[wb addTarget:wb action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[sc addSubview:wb];}y+=34;
            // Split
            [sc addSubview:LSSep(pad,y,cw)];y+=10;LSSectionHeader(sc,@"LAYOUT",pad,y,cw);y+=22;
            UISwitch *swSp=LSToggleRow(sc,@"Split hours / minutes",gLSClockSplit,pad,y,cw);y+=ROWH;
            ALGBlockButton *sp=[ALGBlockButton new];sp.actionBlock=^{gLSClockSplit=swSp.on;LSUpdateClockDisplay();};[swSp addTarget:sp action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(swSp,"p",sp,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            NSArray *als=@[@"Center",@"Left",@"Right"];CGFloat abw=cw/3;
            for(NSInteger i=0;i<3;i++){ALGBlockButton *ab=[ALGBlockButton buttonWithType:UIButtonTypeCustom];ab.frame=CGRectMake(pad+i*abw,y,abw-3,26);[ab setTitle:als[i] forState:UIControlStateNormal];ab.titleLabel.font=[UIFont systemFontOfSize:11 weight:UIFontWeightMedium];ab.layer.cornerRadius=8;ab.backgroundColor=gLSClockAlign==i?ac:[UIColor colorWithWhite:1 alpha:.1f];[ab setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];ab.tag=300+i;NSInteger ai=i;__weak UIScrollView *ws=sc;ab.actionBlock=^{for(NSInteger j=0;j<3;j++)((UIButton*)[ws viewWithTag:300+j]).backgroundColor=[UIColor colorWithWhite:1 alpha:.1f];((UIButton*)[ws viewWithTag:300+ai]).backgroundColor=ac;gLSClockAlign=ai;LSUpdateClockDisplay();};[ab addTarget:ab action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[sc addSubview:ab];}y+=34;
            // Opacity
            [sc addSubview:LSSep(pad,y,cw)];y+=10;LSSectionHeader(sc,@"OPACITY",pad,y,cw);y+=22;
            UISlider *slA=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];slA.minimumValue=.1f;slA.maximumValue=1;slA.value=gLSClockAlpha;slA.minimumTrackTintColor=ac;ALGBlockButton *pa=[ALGBlockButton new];pa.actionBlock=^{gLSClockAlpha=slA.value;LSForceRealtime();};[slA addTarget:pa action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(slA,"p",pa,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[sc addSubview:slA];y+=38;
            // Font
            [sc addSubview:LSSep(pad,y,cw)];y+=10;LSSectionHeader(sc,@"FONT",pad,y,cw);y+=22;
            LSFontRow(sc,pad,&y,cw,gLSClockFontIdx,800,&gLSClockFontIdx);
            // ═══ GRADIENT ═══
            [sc addSubview:LSSep(pad,y,cw)];y+=10;LSSectionHeader(sc,@"GRADIENT",pad,y,cw);y+=22;
            UISwitch *swG=LSToggleRow(sc,@"Enable gradient",gLSClockGradient,pad,y,cw);y+=ROWH;
            ALGBlockButton *sg=[ALGBlockButton new];sg.actionBlock=^{gLSClockGradient=swG.on;LSForceRealtime();};[swG addTarget:sg action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(swG,"p",sg,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            // Preset buttons
            NSArray *gN=@[@"Sunset",@"Ocean",@"Neon",@"Fire",@"Ice"];
            NSArray *gC=@[[UIColor colorWithRed:1 green:.3f blue:.4f alpha:.9f],[UIColor colorWithRed:.1f green:.6f blue:1 alpha:.9f],[UIColor colorWithRed:.6f green:.1f blue:1 alpha:.9f],[UIColor colorWithRed:1 green:.4f blue:0 alpha:.9f],[UIColor colorWithRed:.5f green:.8f blue:1 alpha:.9f]];
            CGFloat gbw=cw/5;
            for(NSInteger i=0;i<5;i++){ALGBlockButton *gb=[ALGBlockButton buttonWithType:UIButtonTypeCustom];gb.frame=CGRectMake(pad+i*gbw,y,gbw-3,30);[gb setTitle:gN[i] forState:UIControlStateNormal];gb.titleLabel.font=[UIFont systemFontOfSize:9 weight:UIFontWeightSemibold];gb.layer.cornerRadius=8;gb.backgroundColor=gC[i];gb.layer.borderWidth=gLSClockGradientStyle==i?2:0;gb.layer.borderColor=[UIColor whiteColor].CGColor;[gb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];gb.tag=400+i;NSInteger gi=i;__weak UIScrollView *ws=sc;gb.actionBlock=^{for(NSInteger j=0;j<5;j++)[ws viewWithTag:400+j].layer.borderWidth=0;[ws viewWithTag:400+gi].layer.borderWidth=2;gLSClockGradientStyle=gi;LSForceRealtime();};[gb addTarget:gb action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[sc addSubview:gb];}y+=40;
            // ═══ COLOR WHEEL 1 ═══
            LSSectionHeader(sc,@"CUSTOM COLOR 1",pad,y,cw);y+=18;
            CGFloat whlSz=MIN(cw,130);
            ALGColorWheel *wh1=[[ALGColorWheel alloc]initWithFrame:CGRectMake(pad+(cw-whlSz)/2,y,whlSz,whlSz)];
            if(gLSClockGradColor1){CGFloat h2,s2,b2,a2;if([gLSClockGradColor1 getHue:&h2 saturation:&s2 brightness:&b2 alpha:&a2]){wh1.curHue=h2;wh1.curSat=s2;wh1.selectedColor=gLSClockGradColor1;}}
            wh1.onColorChanged=^(UIColor *color){
                gLSClockGradColor1=color; gLSClockGradientStyle=5; // custom
                for(NSInteger j=0;j<5;j++)[sc viewWithTag:400+j].layer.borderWidth=0;
                NSMutableDictionary *pr=LSPrefs();LSColorToPrefs(pr,@"gradColor1",color);pr[@"clockGradientStyle"]=@(5);LSSavePrefs(pr);
                LSForceRealtime();
            };
            [sc addSubview:wh1];y+=whlSz+10;
            // ═══ COLOR WHEEL 2 ═══
            LSSectionHeader(sc,@"CUSTOM COLOR 2",pad,y,cw);y+=18;
            ALGColorWheel *wh2=[[ALGColorWheel alloc]initWithFrame:CGRectMake(pad+(cw-whlSz)/2,y,whlSz,whlSz)];
            if(gLSClockGradColor2){CGFloat h2,s2,b2,a2;if([gLSClockGradColor2 getHue:&h2 saturation:&s2 brightness:&b2 alpha:&a2]){wh2.curHue=h2;wh2.curSat=s2;wh2.selectedColor=gLSClockGradColor2;}}
            wh2.onColorChanged=^(UIColor *color){
                gLSClockGradColor2=color; gLSClockGradientStyle=5;
                for(NSInteger j=0;j<5;j++)[sc viewWithTag:400+j].layer.borderWidth=0;
                NSMutableDictionary *pr=LSPrefs();LSColorToPrefs(pr,@"gradColor2",color);pr[@"clockGradientStyle"]=@(5);LSSavePrefs(pr);
                LSForceRealtime();
            };
            [sc addSubview:wh2];y+=whlSz+10;
            UILabel *gNote=LSMakeLabel(@"Pick 2 colors above for custom gradient, or tap a preset.",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.3f],CGRectMake(pad,y,cw,20));[sc addSubview:gNote];y+=28;
            sc.contentSize=CGSizeMake(pw,y+20);LSPush(wnc,pg,pw);
        };[c1 addTarget:c1 action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[home addSubview:c1];cy+=66;
        // ══ DATE ══
        ALGBlockButton *c2=LSCd(@"Date & Day",@"calendar",@"Format, size, font",cy,pw,[UIColor colorWithRed:.2f green:.8f blue:.4f alpha:1]);
        c2.actionBlock=^{UIView *pg=[[UIView alloc]initWithFrame:CGRectMake(0,0,pw,ph)];pg.userInteractionEnabled=YES;[pg addSubview:LSPgHdr(@"Date & Day",pw,wnc,pw)];UIScrollView *sc=[[UIScrollView alloc]initWithFrame:CGRectMake(0,48,pw,ph-48)];sc.showsVerticalScrollIndicator=NO;sc.bounces=YES;[pg addSubview:sc];CGFloat y=12,pad=16,cw=pw-pad*2;UIColor *ac=[UIColor colorWithRed:.2f green:.8f blue:.4f alpha:1];LSSectionHeader(sc,@"FORMAT",pad,y,cw);y+=22;NSArray *fN=@[@"Sunday, March 9",@"SUN 9",@"SUN",@"9 MARCH",@"MARCH 9",@"9/3",@"SUN, MAR 9"];CGFloat fbw=(cw-4)/2;for(NSInteger i=0;i<(NSInteger)fN.count;i++){ALGBlockButton *fb=[ALGBlockButton buttonWithType:UIButtonTypeCustom];fb.frame=CGRectMake(pad+(i%2)*(fbw+4),y+(i/2)*32,fbw,28);[fb setTitle:fN[i] forState:UIControlStateNormal];fb.titleLabel.font=[UIFont systemFontOfSize:10 weight:UIFontWeightMedium];fb.titleLabel.adjustsFontSizeToFitWidth=YES;fb.layer.cornerRadius=8;fb.backgroundColor=gLSDateFormat==i?ac:[UIColor colorWithWhite:1 alpha:.1f];[fb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];fb.tag=500+i;NSInteger fi=i;__weak UIScrollView *ws=sc;fb.actionBlock=^{for(NSInteger j=0;j<(NSInteger)fN.count;j++)((UIButton*)[ws viewWithTag:500+j]).backgroundColor=[UIColor colorWithWhite:1 alpha:.1f];((UIButton*)[ws viewWithTag:500+fi]).backgroundColor=ac;gLSDateFormat=fi;LSForceRealtime();};[fb addTarget:fb action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[sc addSubview:fb];}y+=((fN.count+1)/2)*32+8;[sc addSubview:LSSep(pad,y,cw)];y+=10;LSSectionHeader(sc,@"SIZE & OPACITY",pad,y,cw);y+=22;UISlider *slDS=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];slDS.minimumValue=12;slDS.maximumValue=36;slDS.value=gLSDateSize;slDS.minimumTrackTintColor=ac;ALGBlockButton *pd=[ALGBlockButton new];pd.actionBlock=^{gLSDateSize=slDS.value;LSForceRealtime();};[slDS addTarget:pd action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(slDS,"p",pd,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[sc addSubview:slDS];y+=38;UISlider *slDA=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];slDA.minimumValue=.1f;slDA.maximumValue=1;slDA.value=gLSDateAlpha;slDA.minimumTrackTintColor=ac;ALGBlockButton *pda=[ALGBlockButton new];pda.actionBlock=^{gLSDateAlpha=slDA.value;LSForceRealtime();};[slDA addTarget:pda action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(slDA,"p",pda,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[sc addSubview:slDA];y+=42;[sc addSubview:LSSep(pad,y,cw)];y+=10;LSSectionHeader(sc,@"FONT",pad,y,cw);y+=22;LSFontRow(sc,pad,&y,cw,gLSDateFontIdx,850,&gLSDateFontIdx);sc.contentSize=CGSizeMake(pw,y+20);LSPush(wnc,pg,pw);};[c2 addTarget:c2 action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[home addSubview:c2];cy+=66;
        // ══ LABELS ══
        ALGBlockButton *c6=LSCd(@"Custom Labels",@"textformat.alt",@"Add text labels",cy,pw,[UIColor colorWithRed:.9f green:.6f blue:.1f alpha:1]);
        c6.actionBlock=^{UIView *pg=[[UIView alloc]initWithFrame:CGRectMake(0,0,pw,ph)];pg.userInteractionEnabled=YES;[pg addSubview:LSPgHdr(@"Labels",pw,wnc,pw)];UIScrollView *sc=[[UIScrollView alloc]initWithFrame:CGRectMake(0,48,pw,ph-48)];sc.showsVerticalScrollIndicator=NO;sc.bounces=YES;[pg addSubview:sc];CGFloat pad=16,cw=pw-pad*2;if(!gLSCustomLabels)gLSCustomLabels=[NSMutableArray array];__block void(^rebuild)(void)=^{for(UIView *v in [sc.subviews copy])[v removeFromSuperview];CGFloat y2=12;LSSectionHeader(sc,@"YOUR LABELS",pad,y2,cw);y2+=20;UILabel *nt=LSMakeLabel(@"Labels use Clock font & gradient. Drag in Edit mode.",11,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.35f],CGRectMake(pad,y2,cw,28));nt.numberOfLines=2;[sc addSubview:nt];y2+=32;for(NSInteger i=0;i<(NSInteger)gLSCustomLabels.count;i++){NSDictionary *ld=gLSCustomLabels[i];UIView *row=[[UIView alloc]initWithFrame:CGRectMake(pad,y2,cw,40)];row.backgroundColor=[UIColor colorWithWhite:1 alpha:.06f];row.layer.cornerRadius=10;[sc addSubview:row];UILabel *tl=[[UILabel alloc]initWithFrame:CGRectMake(12,8,cw-80,24)];tl.text=ld[@"text"]?:@"Label";tl.font=[UIFont systemFontOfSize:14];tl.textColor=[UIColor whiteColor];tl.userInteractionEnabled=NO;[row addSubview:tl];ALGBlockButton *del=[ALGBlockButton buttonWithType:UIButtonTypeCustom];del.frame=CGRectMake(cw-44,4,32,32);del.layer.cornerRadius=8;del.backgroundColor=[UIColor colorWithRed:1 green:.3f blue:.3f alpha:.5f];[del setTitle:@"\u2715" forState:UIControlStateNormal];del.titleLabel.font=[UIFont systemFontOfSize:12];NSInteger di=i;del.actionBlock=^{if(di<(NSInteger)gLSCustomLabels.count){[gLSCustomLabels removeObjectAtIndex:di];NSMutableDictionary *pr=LSPrefs();pr[@"customLabels"]=[gLSCustomLabels copy];LSSavePrefs(pr);LSForceRealtime();rebuild();}};[del addTarget:del action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[row addSubview:del];y2+=46;}ALGBlockButton *addB=[ALGBlockButton buttonWithType:UIButtonTypeCustom];addB.frame=CGRectMake(pad,y2+8,cw,38);addB.backgroundColor=[UIColor colorWithRed:.9f green:.6f blue:.1f alpha:.6f];addB.layer.cornerRadius=12;[addB setTitle:@"+ Add Label" forState:UIControlStateNormal];addB.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];addB.actionBlock=^{CGFloat csw=[UIScreen mainScreen].bounds.size.width,csh=[UIScreen mainScreen].bounds.size.height;[gLSCustomLabels addObject:[@{@"text":@"Label",@"size":@(16),@"x":@(csw*.5f),@"y":@(csh*.72f),@"alpha":@(1)} mutableCopy]];NSMutableDictionary *pr=LSPrefs();pr[@"customLabels"]=[gLSCustomLabels copy];LSSavePrefs(pr);LSForceRealtime();rebuild();};[addB addTarget:addB action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[sc addSubview:addB];sc.contentSize=CGSizeMake(pw,y2+60);};rebuild=[rebuild copy];objc_setAssociatedObject(sc,"rb",rebuild,OBJC_ASSOCIATION_COPY_NONATOMIC);rebuild();LSPush(wnc,pg,pw);};[c6 addTarget:c6 action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[home addSubview:c6];cy+=66;
        // ══ NOTIFS ══
        ALGBlockButton *c3=LSCd(@"Notifications",@"bell.badge.fill",@"Radius, opacity, scale",cy,pw,[UIColor colorWithRed:1 green:.55f blue:.2f alpha:1]);
        c3.actionBlock=^{UIView *pg=[[UIView alloc]initWithFrame:CGRectMake(0,0,pw,ph)];pg.userInteractionEnabled=YES;[pg addSubview:LSPgHdr(@"Notifications",pw,wnc,pw)];UIScrollView *sc=[[UIScrollView alloc]initWithFrame:CGRectMake(0,48,pw,ph-48)];sc.showsVerticalScrollIndicator=NO;sc.bounces=YES;[pg addSubview:sc];CGFloat y=12,pad=16,cw=pw-pad*2;UIColor *ac=[UIColor colorWithRed:1 green:.55f blue:.2f alpha:1];LSSectionHeader(sc,@"NOTIFICATIONS",pad,y,cw);y+=22;UISwitch *swE=LSToggleRow(sc,@"Enable",gLSNotifEnabled,pad,y,cw);y+=ROWH;ALGBlockButton *se=[ALGBlockButton new];se.actionBlock=^{gLSNotifEnabled=swE.on;LSPostUpdateNotification();};[swE addTarget:se action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(swE,"p",se,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[sc addSubview:LSSep(pad,y,cw)];y+=8;[sc addSubview:LSMakeLabel(@"Corner radius",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))];y+=14;UISlider *slR=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];slR.minimumValue=4;slR.maximumValue=28;slR.value=gLSNotifRadius;slR.minimumTrackTintColor=ac;ALGBlockButton *sr=[ALGBlockButton new];sr.actionBlock=^{gLSNotifRadius=slR.value;LSPostUpdateNotification();};[slR addTarget:sr action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(slR,"p",sr,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[sc addSubview:slR];y+=38;[sc addSubview:LSMakeLabel(@"Opacity",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))];y+=14;UISlider *slAn=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];slAn.minimumValue=.3f;slAn.maximumValue=1;slAn.value=gLSNotifAlpha;slAn.minimumTrackTintColor=ac;ALGBlockButton *sa=[ALGBlockButton new];sa.actionBlock=^{gLSNotifAlpha=slAn.value;LSPostUpdateNotification();};[slAn addTarget:sa action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(slAn,"p",sa,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[sc addSubview:slAn];y+=38;[sc addSubview:LSMakeLabel(@"Scale",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))];y+=14;UISlider *slSc=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];slSc.minimumValue=.7f;slSc.maximumValue=1;slSc.value=gLSNotifScale;slSc.minimumTrackTintColor=ac;ALGBlockButton *ssc=[ALGBlockButton new];ssc.actionBlock=^{gLSNotifScale=slSc.value;LSPostUpdateNotification();};[slSc addTarget:ssc action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(slSc,"p",ssc,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[sc addSubview:slSc];y+=38;[sc addSubview:LSSep(pad,y,cw)];y+=8;UISwitch *swB=LSToggleRow(sc,@"Blur background",gLSNotifBlur,pad,y,cw);y+=ROWH;ALGBlockButton *sb=[ALGBlockButton new];sb.actionBlock=^{gLSNotifBlur=swB.on;LSPostUpdateNotification();};[swB addTarget:sb action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(swB,"p",sb,OBJC_ASSOCIATION_RETAIN_NONATOMIC);UISwitch *swBd=LSToggleRow(sc,@"Bold title",gLSNotifTitleBold,pad,y,cw);y+=ROWH;ALGBlockButton *sbd=[ALGBlockButton new];sbd.actionBlock=^{gLSNotifTitleBold=swBd.on;LSPostUpdateNotification();};[swBd addTarget:sbd action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(swBd,"p",sbd,OBJC_ASSOCIATION_RETAIN_NONATOMIC);UISwitch *swI=LSToggleRow(sc,@"Show icon",gLSNotifShowIcon,pad,y,cw);y+=ROWH;ALGBlockButton *si=[ALGBlockButton new];si.actionBlock=^{gLSNotifShowIcon=swI.on;LSPostUpdateNotification();};[swI addTarget:si action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(swI,"p",si,OBJC_ASSOCIATION_RETAIN_NONATOMIC);sc.contentSize=CGSizeMake(pw,y+20);LSPush(wnc,pg,pw);};[c3 addTarget:c3 action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[home addSubview:c3];cy+=66;
        // ══ EFFECTS ══
        ALGBlockButton *c4=LSCd(@"Effects",@"sparkles",@"Border, glow, tint, line",cy,pw,[UIColor colorWithRed:.6f green:.2f blue:1 alpha:1]);
        c4.actionBlock=^{UIView *pg=[[UIView alloc]initWithFrame:CGRectMake(0,0,pw,ph)];pg.userInteractionEnabled=YES;[pg addSubview:LSPgHdr(@"Effects",pw,wnc,pw)];UIScrollView *sc=[[UIScrollView alloc]initWithFrame:CGRectMake(0,48,pw,ph-48)];sc.showsVerticalScrollIndicator=NO;sc.bounces=YES;[pg addSubview:sc];CGFloat y=12,pad=16,cw=pw-pad*2;UIColor *ac=[UIColor colorWithRed:.6f green:.2f blue:1 alpha:1];LSSectionHeader(sc,@"BORDER",pad,y,cw);y+=22;UISwitch *swBo=LSToggleRow(sc,@"Enable",gLSBorderEnabled,pad,y,cw);y+=ROWH;ALGBlockButton *sbr=[ALGBlockButton new];sbr.actionBlock=^{gLSBorderEnabled=swBo.on;LSPostUpdateNotification();};[swBo addTarget:sbr action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(swBo,"p",sbr,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[sc addSubview:LSMakeLabel(@"Thickness",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))];y+=14;UISlider *slBW=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];slBW.minimumValue=.5f;slBW.maximumValue=5;slBW.value=gLSBorderWidth;slBW.minimumTrackTintColor=ac;ALGBlockButton *sbw=[ALGBlockButton new];sbw.actionBlock=^{gLSBorderWidth=slBW.value;LSPostUpdateNotification();};[slBW addTarget:sbw action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(slBW,"p",sbw,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[sc addSubview:slBW];y+=38;LSColorPickerRow(sc,@"Color",pad,y,cw,1400,@"borderColor",&gLSBorderColor);y+=38;[sc addSubview:LSSep(pad,y,cw)];y+=12;LSSectionHeader(sc,@"BACKGROUND TINT",pad,y,cw);y+=22;UISwitch *swBg=LSToggleRow(sc,@"Enable",gLSBgEnabled,pad,y,cw);y+=ROWH;ALGBlockButton *sbg=[ALGBlockButton new];sbg.actionBlock=^{gLSBgEnabled=swBg.on;LSPostUpdateNotification();};[swBg addTarget:sbg action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(swBg,"p",sbg,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[sc addSubview:LSMakeLabel(@"Intensity",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))];y+=14;UISlider *slBgA=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];slBgA.minimumValue=.05f;slBgA.maximumValue=.7f;slBgA.value=gLSBgIconAlpha;slBgA.minimumTrackTintColor=ac;ALGBlockButton *sbga=[ALGBlockButton new];sbga.actionBlock=^{gLSBgIconAlpha=slBgA.value;LSPostUpdateNotification();};[slBgA addTarget:sbga action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(slBgA,"p",sbga,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[sc addSubview:slBgA];y+=38;LSColorPickerRow(sc,@"Color",pad,y,cw,1500,@"bgColor",&gLSBgColor);y+=38;[sc addSubview:LSSep(pad,y,cw)];y+=12;LSSectionHeader(sc,@"GLOW",pad,y,cw);y+=22;UISwitch *swSh=LSToggleRow(sc,@"Enable",gLSShadowEnabled,pad,y,cw);y+=ROWH;ALGBlockButton *ssh=[ALGBlockButton new];ssh.actionBlock=^{gLSShadowEnabled=swSh.on;LSPostUpdateNotification();};[swSh addTarget:ssh action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(swSh,"p",ssh,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[sc addSubview:LSMakeLabel(@"Radius",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))];y+=14;UISlider *slSW=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];slSW.minimumValue=2;slSW.maximumValue=20;slSW.value=gLSShadowWidth;slSW.minimumTrackTintColor=ac;ALGBlockButton *ssw=[ALGBlockButton new];ssw.actionBlock=^{gLSShadowWidth=slSW.value;LSPostUpdateNotification();};[slSW addTarget:ssw action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(slSW,"p",ssw,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[sc addSubview:slSW];y+=38;LSColorPickerRow(sc,@"Color",pad,y,cw,1600,@"shadowColor",&gLSShadowColor);y+=38;[sc addSubview:LSSep(pad,y,cw)];y+=12;LSSectionHeader(sc,@"LINE",pad,y,cw);y+=22;UISwitch *swLn=LSToggleRow(sc,@"Enable",gLSLineEnabled,pad,y,cw);y+=ROWH;ALGBlockButton *sln=[ALGBlockButton new];sln.actionBlock=^{gLSLineEnabled=swLn.on;LSPostUpdateNotification();};[swLn addTarget:sln action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(swLn,"p",sln,OBJC_ASSOCIATION_RETAIN_NONATOMIC);NSArray *lp=@[@"L",@"R",@"T",@"B"];CGFloat lpw=cw/4;for(NSInteger i=0;i<4;i++){ALGBlockButton *lb=[ALGBlockButton buttonWithType:UIButtonTypeCustom];lb.frame=CGRectMake(pad+i*lpw,y,lpw-3,26);[lb setTitle:lp[i] forState:UIControlStateNormal];lb.titleLabel.font=[UIFont systemFontOfSize:11 weight:UIFontWeightMedium];lb.layer.cornerRadius=8;lb.backgroundColor=gLSLinePosition==i?ac:[UIColor colorWithWhite:1 alpha:.1f];[lb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];lb.tag=1700+i;NSInteger li=i;__weak UIScrollView *ws=sc;lb.actionBlock=^{for(NSInteger j=0;j<4;j++)((UIButton*)[ws viewWithTag:1700+j]).backgroundColor=[UIColor colorWithWhite:1 alpha:.1f];((UIButton*)[ws viewWithTag:1700+li]).backgroundColor=ac;gLSLinePosition=li;};[lb addTarget:lb action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[sc addSubview:lb];}y+=34;[sc addSubview:LSMakeLabel(@"Thickness",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))];y+=14;UISlider *slLW=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];slLW.minimumValue=1;slLW.maximumValue=8;slLW.value=gLSLineWidth;slLW.minimumTrackTintColor=ac;ALGBlockButton *slwp=[ALGBlockButton new];slwp.actionBlock=^{gLSLineWidth=slLW.value;LSPostUpdateNotification();};[slLW addTarget:slwp action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(slLW,"p",slwp,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[sc addSubview:slLW];y+=38;LSColorPickerRow(sc,@"Color",pad,y,cw,1750,@"lineColor",&gLSLineColor);y+=48;sc.contentSize=CGSizeMake(pw,y+20);LSPush(wnc,pg,pw);};[c4 addTarget:c4 action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[home addSubview:c4];cy+=66;
        // ══ THEMES ══
        ALGBlockButton *c5=LSCd(@"Themes",@"paintpalette.fill",@"One-tap presets",cy,pw,[UIColor colorWithRed:1 green:.4f blue:.7f alpha:1]);
        c5.actionBlock=^{UIView *pg=[[UIView alloc]initWithFrame:CGRectMake(0,0,pw,ph)];pg.userInteractionEnabled=YES;[pg addSubview:LSPgHdr(@"Themes",pw,wnc,pw)];CGFloat y=60,pad=16,cw=pw-pad*2;NSArray *th=@[@{@"n":@"Stock",@"border":@NO,@"bg":@NO,@"shadow":@NO,@"line":@NO,@"clkSz":@(70),@"clkW":@(1),@"clkA":@(1),@"clkY":@(.38f)},@{@"n":@"Velvet",@"border":@YES,@"borderW":@(2),@"bg":@NO,@"shadow":@NO,@"line":@NO,@"clkSz":@(72),@"clkW":@(0),@"clkA":@(1),@"clkY":@(.36f)},@{@"n":@"Neon",@"border":@YES,@"borderW":@(1.5f),@"bg":@NO,@"shadow":@YES,@"shadowW":@(12),@"line":@NO,@"clkSz":@(76),@"clkW":@(2),@"clkA":@(1),@"clkY":@(.38f)},@{@"n":@"Minimal",@"border":@NO,@"bg":@NO,@"shadow":@NO,@"line":@NO,@"clkSz":@(90),@"clkW":@(0),@"clkA":@(.9f),@"clkY":@(.40f)},@{@"n":@"Frosted",@"border":@YES,@"borderW":@(.8f),@"bg":@YES,@"bgA":@(.18f),@"shadow":@NO,@"line":@NO,@"clkSz":@(68),@"clkW":@(1),@"clkA":@(.85f),@"clkY":@(.35f)},@{@"n":@"Line",@"border":@NO,@"bg":@NO,@"shadow":@NO,@"line":@YES,@"linePos":@(0),@"lineW":@(3),@"clkSz":@(70),@"clkW":@(1),@"clkA":@(1),@"clkY":@(.38f)}];NSArray *tA=@[[UIColor colorWithWhite:.3f alpha:.6f],[UIColor colorWithRed:.6f green:.2f blue:1 alpha:.85f],[UIColor colorWithRed:.1f green:.9f blue:.9f alpha:.85f],[UIColor colorWithWhite:.5f alpha:.4f],[UIColor colorWithRed:.3f green:.7f blue:1 alpha:.7f],[UIColor colorWithRed:.2f green:.8f blue:.5f alpha:.85f]];CGFloat tbw=cw/3;for(NSInteger i=0;i<6;i++){NSDictionary *t=th[i];ALGBlockButton *tb=[ALGBlockButton buttonWithType:UIButtonTypeCustom];tb.frame=CGRectMake(pad+(i%3)*tbw,y+(i/3)*72,tbw-6,62);tb.backgroundColor=tA[i];tb.layer.cornerRadius=14;if(@available(iOS 13.0,*))tb.layer.cornerCurve=kCACornerCurveContinuous;tb.layer.borderWidth=.6f;tb.layer.borderColor=[UIColor colorWithWhite:1 alpha:.2f].CGColor;UILabel *nm=LSMakeLabel(t[@"n"],12,UIFontWeightSemibold,[UIColor whiteColor],CGRectMake(0,20,tbw-6,22));nm.textAlignment=NSTextAlignmentCenter;[tb addSubview:nm];tb.tag=9200+i;NSInteger ti=i;__weak UIView *wp=pg;tb.actionBlock=^{NSDictionary *tt=th[ti];gLSBorderEnabled=[tt[@"border"]boolValue];gLSBorderWidth=tt[@"borderW"]?[tt[@"borderW"]floatValue]:2;gLSBgEnabled=[tt[@"bg"]boolValue];gLSBgIconAlpha=tt[@"bgA"]?[tt[@"bgA"]floatValue]:.2f;gLSShadowEnabled=[tt[@"shadow"]boolValue];gLSShadowWidth=tt[@"shadowW"]?[tt[@"shadowW"]floatValue]:8;gLSLineEnabled=[tt[@"line"]boolValue];gLSLinePosition=tt[@"linePos"]?[tt[@"linePos"]integerValue]:0;gLSLineWidth=tt[@"lineW"]?[tt[@"lineW"]floatValue]:3;gLSClockSize=[tt[@"clkSz"]floatValue];gLSClockW=[tt[@"clkW"]integerValue];gLSClockAlpha=[tt[@"clkA"]floatValue];gLSClockY=[tt[@"clkY"]floatValue];LSForceRealtime();LSPostUpdateNotification();for(NSInteger j=0;j<6;j++){UIView *o=[wp viewWithTag:9200+j];[UIView animateWithDuration:.2f animations:^{o.layer.borderWidth=j==ti?2:.6f;o.layer.borderColor=j==ti?[UIColor whiteColor].CGColor:[UIColor colorWithWhite:1 alpha:.2f].CGColor;o.transform=j==ti?CGAffineTransformMakeScale(1.04f,1.04f):CGAffineTransformIdentity;}];}if(@available(iOS 10.0,*))[[UIImpactFeedbackGenerator new]impactOccurred];};[tb addTarget:tb action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[pg addSubview:tb];}LSPush(wnc,pg,pw);};[c5 addTarget:c5 action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[home addSubview:c5];cy+=66;
        // ── BOTTOM ──
        cy+=8;CAGradientLayer *bs=[CAGradientLayer layer];bs.frame=CGRectMake(20,cy,pw-40,.5f);bs.colors=@[(id)[UIColor colorWithWhite:1 alpha:0].CGColor,(id)[UIColor colorWithWhite:1 alpha:.15f].CGColor,(id)[UIColor colorWithWhite:1 alpha:0].CGColor];bs.startPoint=CGPointMake(0,.5f);bs.endPoint=CGPointMake(1,.5f);[home.layer addSublayer:bs];cy+=12;
        CGFloat bw2=(pw-16*2-8)/2;
        ALGBlockButton *eBtn=LSGBtn(@"Edit layout",@"arrow.up.and.down.and.arrow.left.and.right",@[[UIColor colorWithRed:.38f green:.12f blue:.88f alpha:.75f],[UIColor colorWithRed:.22f green:.05f blue:.58f alpha:.6f]],CGRectMake(16,cy,bw2,38));
        eBtn.actionBlock=^{gLSEditModeActive=YES;LSClosePanel();if(!gLSClockWindow)return;gLSClockWindow.userInteractionEnabled=YES;if(!objc_getAssociatedObject(gLSClockLabel,"lsDrag")){ALGBlockButton *cp=[ALGBlockButton new];__block UIPanGestureRecognizer *cpan=nil;cp.actionBlock=^{if(!cpan)return;CGPoint d=[cpan translationInView:gLSClockLabel.superview];CGPoint c=gLSClockLabel.center;c.x=MAX(30,MIN(c.x+d.x,[UIScreen mainScreen].bounds.size.width-30));c.y=MAX(60,MIN(c.y+d.y,[UIScreen mainScreen].bounds.size.height-60));gLSClockLabel.center=c;[cpan setTranslation:CGPointZero inView:gLSClockLabel.superview];gLSClockPX=c.x;gLSClockPY=c.y;if(cpan.state==UIGestureRecognizerStateEnded){NSMutableDictionary *pr=LSPrefs();pr[@"clockPX"]=@(gLSClockPX);pr[@"clockPY"]=@(gLSClockPY);LSSavePrefs(pr);}};cpan=[[UIPanGestureRecognizer alloc]initWithTarget:cp action:@selector(handleTap)];objc_setAssociatedObject(gLSClockLabel,"lsDrag",cp,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[gLSClockLabel addGestureRecognizer:cpan];}if(!objc_getAssociatedObject(gLSDateLabel,"lsDrag")){ALGBlockButton *dp=[ALGBlockButton new];__block UIPanGestureRecognizer *dpan=nil;dp.actionBlock=^{if(!dpan)return;CGPoint d=[dpan translationInView:gLSDateLabel.superview];CGPoint c=gLSDateLabel.center;c.x=MAX(30,MIN(c.x+d.x,[UIScreen mainScreen].bounds.size.width-30));c.y=MAX(60,MIN(c.y+d.y,[UIScreen mainScreen].bounds.size.height-60));gLSDateLabel.center=c;[dpan setTranslation:CGPointZero inView:gLSDateLabel.superview];gLSDatePX=c.x;gLSDatePY=c.y;if(dpan.state==UIGestureRecognizerStateEnded){NSMutableDictionary *pr=LSPrefs();pr[@"datePX"]=@(gLSDatePX);pr[@"datePY"]=@(gLSDatePY);LSSavePrefs(pr);}};dpan=[[UIPanGestureRecognizer alloc]initWithTarget:dp action:@selector(handleTap)];objc_setAssociatedObject(gLSDateLabel,"lsDrag",dp,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[gLSDateLabel addGestureRecognizer:dpan];}gLSClockLabel.userInteractionEnabled=YES;gLSDateLabel.userInteractionEnabled=YES;gLSClockLabel.layer.borderColor=[UIColor colorWithRed:.2f green:.6f blue:1 alpha:.8f].CGColor;gLSClockLabel.layer.borderWidth=2;gLSClockLabel.layer.cornerRadius=8;gLSDateLabel.layer.borderColor=[UIColor colorWithRed:.2f green:.9f blue:.4f alpha:.8f].CGColor;gLSDateLabel.layer.borderWidth=1.5f;gLSDateLabel.layer.cornerRadius=6;UILabel *toast=[[UILabel alloc]init];toast.text=@"Drag clock & date";toast.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];toast.textColor=[UIColor whiteColor];toast.textAlignment=NSTextAlignmentCenter;toast.backgroundColor=[UIColor colorWithRed:.1f green:.4f blue:.9f alpha:.9f];toast.layer.cornerRadius=14;toast.clipsToBounds=YES;[toast sizeToFit];CGFloat tsw=[UIScreen mainScreen].bounds.size.width,tsh=[UIScreen mainScreen].bounds.size.height;toast.frame=CGRectMake((tsw-toast.bounds.size.width-28)/2,tsh*.88f,toast.bounds.size.width+28,34);toast.alpha=0;[gLSClockWindow.rootViewController.view addSubview:toast];[UIView animateWithDuration:.25f animations:^{toast.alpha=1;}completion:^(BOOL d2){[UIView animateWithDuration:.3f delay:2.5f options:0 animations:^{toast.alpha=0;}completion:^(BOOL d3){[toast removeFromSuperview];}];}];ALGBlockButton *doneBtn=[ALGBlockButton buttonWithType:UIButtonTypeCustom];doneBtn.frame=CGRectMake((tsw-120)/2,tsh*.92f,120,40);UIVisualEffectView *doneBV=[[UIVisualEffectView alloc]initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];doneBV.frame=CGRectMake(0,0,120,40);doneBV.layer.cornerRadius=20;if(@available(iOS 13.0,*))doneBV.layer.cornerCurve=kCACornerCurveContinuous;doneBV.layer.masksToBounds=YES;doneBV.userInteractionEnabled=NO;[doneBtn addSubview:doneBV];CAGradientLayer *dg=[CAGradientLayer layer];dg.frame=CGRectMake(0,0,120,40);dg.cornerRadius=20;dg.colors=@[(id)[UIColor colorWithRed:0 green:.75f blue:.35f alpha:.85f].CGColor,(id)[UIColor colorWithRed:0 green:.5f blue:.25f alpha:.7f].CGColor];dg.startPoint=CGPointMake(0,0);dg.endPoint=CGPointMake(1,1);[doneBtn.layer addSublayer:dg];UILabel *dl=[[UILabel alloc]initWithFrame:CGRectMake(0,0,120,40)];dl.text=@"Done";dl.textAlignment=NSTextAlignmentCenter;dl.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];dl.textColor=[UIColor whiteColor];dl.userInteractionEnabled=NO;[doneBtn addSubview:dl];doneBtn.layer.cornerRadius=20;doneBtn.layer.borderWidth=.5f;doneBtn.layer.borderColor=[UIColor colorWithWhite:1 alpha:.3f].CGColor;doneBtn.tag=8881;doneBtn.actionBlock=^{gLSEditModeActive=NO;gLSClockWindow.userInteractionEnabled=NO;gLSClockLabel.userInteractionEnabled=NO;gLSDateLabel.userInteractionEnabled=NO;gLSClockLabel.layer.borderWidth=0;gLSDateLabel.layer.borderWidth=0;UIView *dbb=[gLSClockWindow.rootViewController.view viewWithTag:8881];[UIView animateWithDuration:.2f animations:^{dbb.alpha=0;dbb.transform=CGAffineTransformMakeScale(.9f,.9f);}completion:^(BOOL d2){[dbb removeFromSuperview];}];};[doneBtn addTarget:doneBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[gLSClockWindow.rootViewController.view addSubview:doneBtn];doneBtn.alpha=0;doneBtn.transform=CGAffineTransformMakeScale(.8f,.8f);[UIView animateWithDuration:.3f delay:.1f usingSpringWithDamping:.7f initialSpringVelocity:.5f options:0 animations:^{doneBtn.alpha=1;doneBtn.transform=CGAffineTransformIdentity;}completion:nil];};
        [eBtn addTarget:eBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[home addSubview:eBtn];
        ALGBlockButton *sBtn=LSGBtn(@"Save",@"checkmark.circle.fill",@[[UIColor colorWithRed:0 green:.5f blue:1 alpha:.75f],[UIColor colorWithRed:0 green:.3f blue:.75f alpha:.6f]],CGRectMake(16+bw2+8,cy,bw2,38));
        sBtn.actionBlock=^{NSMutableDictionary *pr=LSPrefs();pr[@"clockFontSize"]=@(gLSClockSize);pr[@"clockAlpha"]=@(gLSClockAlpha);pr[@"clockY"]=@(gLSClockY);pr[@"clockFontWeight"]=@(gLSClockW);pr[@"clockSplit"]=@(gLSClockSplit);pr[@"clockMinsSize"]=@(gLSMinsSize);pr[@"clockAlign"]=@(gLSClockAlign);pr[@"clockPX"]=@(gLSClockPX);pr[@"clockPY"]=@(gLSClockPY);pr[@"clockScale"]=@(gLSClockScale);pr[@"dateFontSize"]=@(gLSDateSize);pr[@"dateAlpha"]=@(gLSDateAlpha);pr[@"datePX"]=@(gLSDatePX);pr[@"datePY"]=@(gLSDatePY);pr[@"dateScale"]=@(gLSDateScale);pr[@"notifEnabled"]=@(gLSNotifEnabled);pr[@"notifRadius"]=@(gLSNotifRadius);pr[@"notifAlpha"]=@(gLSNotifAlpha);pr[@"notifScale"]=@(gLSNotifScale);pr[@"notifBlur"]=@(gLSNotifBlur);pr[@"notifTitleBold"]=@(gLSNotifTitleBold);pr[@"notifShowIcon"]=@(gLSNotifShowIcon);pr[@"borderEnabled"]=@(gLSBorderEnabled);pr[@"borderWidth"]=@(gLSBorderWidth);pr[@"bgEnabled"]=@(gLSBgEnabled);pr[@"bgIconAlpha"]=@(gLSBgIconAlpha*100);pr[@"shadowEnabled"]=@(gLSShadowEnabled);pr[@"shadowWidth"]=@(gLSShadowWidth);pr[@"lineEnabled"]=@(gLSLineEnabled);pr[@"lineWidth"]=@(gLSLineWidth);pr[@"linePosition"]=@[@"left",@"right",@"top",@"bottom"][gLSLinePosition];pr[@"clockGradient"]=@(gLSClockGradient);pr[@"clockGradientStyle"]=@(gLSClockGradientStyle);pr[@"dateFormat"]=@(gLSDateFormat);pr[@"clockFontIdx"]=@(gLSClockFontIdx);pr[@"dateFontIdx"]=@(gLSDateFontIdx);if(gLSCustomLabels)pr[@"customLabels"]=[gLSCustomLabels copy];LSSavePrefs(pr);LSLoadPrefs();LSForceRealtime();LSPostUpdateNotification();LSClosePanel();};
        [sBtn addTarget:sBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];[home addSubview:sBtn];
    }
    [nc addSubview:home];
    __weak UIView *wp=panel;__block UIPanGestureRecognizer *pan=nil;ALGBlockButton *panP=[ALGBlockButton new];panP.actionBlock=^{UIView *p=wp;if(!p||!pan)return;UIView *r=p.superview;if(!r)return;CGPoint d=[pan translationInView:r];CGRect f=p.frame;f.origin.x=MAX(4,MIN(f.origin.x+d.x,r.bounds.size.width-f.size.width-4));f.origin.y=MAX(20,MIN(f.origin.y+d.y,r.bounds.size.height-f.size.height-20));p.frame=f;for(UIView *v in r.subviews)if(v.tag==8800)v.frame=f;[pan setTranslation:CGPointZero inView:r];};pan=[[UIPanGestureRecognizer alloc]initWithTarget:panP action:@selector(handleTap)];objc_setAssociatedObject(panel,"panP",panP,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[panel addGestureRecognizer:pan];
    [root addSubview:panel];gLSWindow.hidden=NO;gLSWindow.userInteractionEnabled=YES;
    panel.alpha=0;dim.alpha=0;panel.transform=CGAffineTransformConcat(CGAffineTransformMakeScale(.9f,.9f),CGAffineTransformMakeTranslation(0,12));
    [UIView animateWithDuration:.38f delay:0 usingSpringWithDamping:.78f initialSpringVelocity:.6f options:UIViewAnimationOptionAllowUserInteraction animations:^{panel.alpha=1;panel.transform=CGAffineTransformIdentity;dim.alpha=1;}completion:nil];
}


// ═══════════════════════════════════════════════════════════════
// BOTÓN FLOTANTE LS — igual que ALGFloatButton del homescreen
// Draggable, snap a bordes, con blur
// ═══════════════════════════════════════════════════════════════

// Reutilizamos la misma clase ALGFloatButton pero con su propia window y acción
@interface ALGLSFloatButton : UIView
@end
@implementation ALGLSFloatButton
- (void)handlePan:(UIPanGestureRecognizer *)g {
    CGPoint d = [g translationInView:self.superview];
    CGPoint c = CGPointMake(self.center.x+d.x, self.center.y+d.y);
    CGFloat r = self.bounds.size.width/2.0f;
    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    CGFloat sh = [UIScreen mainScreen].bounds.size.height;
    c.x = MAX(r+6, MIN(c.x, sw-r-6));
    c.y = MAX(r+50, MIN(c.y, sh-r-40));
    self.center = c;
    [g setTranslation:CGPointZero inView:self.superview];
    if (g.state == UIGestureRecognizerStateEnded) {
        CGFloat target = c.x < sw/2.0f ? r+6 : sw-r-6;
        [UIView animateWithDuration:0.38f delay:0
             usingSpringWithDamping:0.72f initialSpringVelocity:0.4f
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{ self.center=CGPointMake(target, c.y); }
                         completion:nil];
    }
}
- (void)handleTap:(UITapGestureRecognizer *)g {
    if (gLSEditModeActive) {
        // En modo edicion — tap en el boton guarda y sale del modo
        gLSEditModeActive = NO;
        if (gLSClockWindow) {
            gLSClockWindow.userInteractionEnabled = NO;
            if (gLSClockLabel) {
                gLSClockLabel.userInteractionEnabled = NO;
                gLSClockLabel.layer.borderWidth = 0;
            }
            if (gLSDateLabel) {
                gLSDateLabel.userInteractionEnabled = NO;
                gLSDateLabel.layer.borderWidth = 0;
            }
        }
        // Guardar posicion
        NSMutableDictionary *pr = LSPrefs();
        pr[@"clockPX"]=@(gLSClockPX); pr[@"clockPY"]=@(gLSClockPY);
        pr[@"datePX"] =@(gLSDatePX);  pr[@"datePY"] =@(gLSDatePY);
        LSSavePrefs(pr);
        // Haptic
        if (@available(iOS 10.0,*)) [[UIImpactFeedbackGenerator new] impactOccurred];
    } else {
        LSShowPanel();
    }
}
@end

// Window dedicada para el boton flotante LS
// hitTest devuelve nil en todo EXCEPTO el boton — evita pasar toques al lockscreen
@interface ALGLSButtonWindow : UIWindow
@property (nonatomic, weak) UIView *buttonView;
@end
@implementation ALGLSButtonWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    // Solo capturar toques exactamente sobre el boton
    if (self.buttonView) {
        CGPoint p = [self.buttonView convertPoint:point fromView:self];
        if ([self.buttonView pointInside:p withEvent:event])
            return [self.buttonView hitTest:p withEvent:event];
    }
    // Todo lo demas — pasar al lockscreen sin consumirlo
    return nil;
}
@end

static void LSSetupFloatingButton(void) {
    if (gLSButtonWindow) return;

    UIWindowScene *scene = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
        if ([s isKindOfClass:[UIWindowScene class]]) { scene=(UIWindowScene*)s; break; }

    // Ventana del panel (si no existe)
    if (!gLSWindow) {
        if (@available(iOS 13.0,*))
            gLSWindow = [[ALGPassthroughWindow alloc] initWithWindowScene:scene];
        else
            gLSWindow = [[ALGPassthroughWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        gLSWindow.windowLevel = UIWindowLevelAlert + 499;
        gLSWindow.backgroundColor = [UIColor clearColor];
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.userInteractionEnabled = YES;
        gLSWindow.rootViewController = vc;
        gLSWindow.hidden = YES;
    }

    // Ventana del botón flotante — clase dedicada con hitTest preciso
    if (@available(iOS 13.0,*))
        gLSButtonWindow = [[ALGLSButtonWindow alloc] initWithWindowScene:scene];
    else
        gLSButtonWindow = [[ALGLSButtonWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    // windowLevel encima del lockscreen para capturar toques primero
    gLSButtonWindow.windowLevel = UIWindowLevelAlert + 500;
    gLSButtonWindow.backgroundColor = [UIColor clearColor];
    UIViewController *bvc = [[UIViewController alloc] init];
    bvc.view.backgroundColor = [UIColor clearColor];
    bvc.view.userInteractionEnabled = YES;
    gLSButtonWindow.rootViewController = bvc;

    // ── Botón draggable ────────────────────────────────────
    CGFloat sh = [UIScreen mainScreen].bounds.size.height;
    CGFloat sw = [UIScreen mainScreen].bounds.size.width;

    ALGLSFloatButton *btn = [[ALGLSFloatButton alloc]
        initWithFrame:CGRectMake(sw-54-12, sh*0.72f, 54, 54)];
    btn.userInteractionEnabled = YES;

    // Fondo blur oscuro
    UIBlurEffect *blurEff;
    if (@available(iOS 13.0,*))
        blurEff = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    else
        blurEff = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurV = [[UIVisualEffectView alloc] initWithEffect:blurEff];
    blurV.frame = CGRectMake(0,0,54,54);
    blurV.layer.cornerRadius = 27; blurV.layer.masksToBounds = YES;
    blurV.userInteractionEnabled = NO;
    [btn addSubview:blurV];

    // Gradiente sutil encima del blur
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame = CGRectMake(0,0,54,54);
    grad.cornerRadius = 27;
    grad.colors = @[
        (id)[UIColor colorWithWhite:1 alpha:0.18f].CGColor,
        (id)[UIColor colorWithWhite:1 alpha:0.04f].CGColor,
    ];
    grad.startPoint = CGPointMake(0.5f, 0);
    grad.endPoint = CGPointMake(0.5f, 1);
    [btn.layer addSublayer:grad];

    // Borde y sombra
    btn.layer.cornerRadius = 27;
    btn.layer.borderWidth = 0.5f;
    btn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.3f].CGColor;
    btn.layer.shadowColor = [UIColor blackColor].CGColor;
    btn.layer.shadowOpacity = 0.35f;
    btn.layer.shadowRadius = 12;
    btn.layer.shadowOffset = CGSizeMake(0,4);

    // Icono SF Symbol — sliders
    if (@available(iOS 13.0,*)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration
            configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
        UIImage *img = [UIImage systemImageNamed:@"slider.horizontal.3"
                        withConfiguration:cfg];
        UIImageView *iv = [[UIImageView alloc] initWithImage:img];
        iv.frame = CGRectMake(14, 14, 26, 26);
        iv.tintColor = [UIColor whiteColor];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.userInteractionEnabled = NO;
        [btn addSubview:iv];
    } else {
        UILabel *icon = [[UILabel alloc] initWithFrame:CGRectMake(0,0,54,54)];
        icon.text = @"LS"; icon.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        icon.textColor = [UIColor whiteColor]; icon.textAlignment = NSTextAlignmentCenter;
        icon.userInteractionEnabled = NO; [btn addSubview:icon];
    }

    // Pan para arrastrar el boton
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:btn action:@selector(handlePan:)];
    // Tap simple — abrir panel
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:btn action:@selector(handleTap:)];
    tap.numberOfTapsRequired = 1;
    // editProxy — se usa desde el panel, no desde gestos del boton
    ALGBlockButton *editProxy = [ALGBlockButton new];

    // Bloque de edición — reutilizado por doubleTap
    void (^toggleEditMode)(void) = ^{
        BOOL editing = ![objc_getAssociatedObject(btn, "lsEditMode") boolValue];
        objc_setAssociatedObject(btn, "lsEditMode", @(editing), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        gLSEditModeActive = editing;

        // Mostrar u ocultar la overlay de gestos
        gLSEditOverlay.hidden = !editing;
        gLSEditOverlay.userInteractionEnabled = editing;
        // Habilitar drag directo en los labels custom
        if (gLSClockWindow) {
            // IMPORTANTE: userInteractionEnabled en la WINDOW, no solo en los labels
            gLSClockWindow.userInteractionEnabled = editing;
            if (editing) {
                // Hacer window key para capturar toques antes que el lockscreen
                [gLSClockWindow makeKeyWindow];
            }
            gLSClockLabel.userInteractionEnabled = editing;
            gLSDateLabel.userInteractionEnabled = editing;
            if (editing) {
                // Hacer labels mas faciles de tocar — padding visual
                gLSClockLabel.layer.borderColor = [UIColor colorWithRed:0 green:0.6f blue:1 alpha:0.7f].CGColor;
                gLSClockLabel.layer.borderWidth = 1.5f;
                gLSClockLabel.layer.cornerRadius = 6.0f;
                gLSDateLabel.layer.borderColor = [UIColor colorWithRed:0.2f green:0.9f blue:0.4f alpha:0.7f].CGColor;
                gLSDateLabel.layer.borderWidth = 1.5f;
                gLSDateLabel.layer.cornerRadius = 4.0f;
                // Agregar pan a clock label si no tiene
                if (!objc_getAssociatedObject(gLSClockLabel, "lsDrag")) {
                    ALGBlockButton *cp = [ALGBlockButton new];
                    __block UIPanGestureRecognizer *cpan = nil;
                    cp.actionBlock = ^{
                        if (!cpan) return;
                        CGPoint d = [cpan translationInView:gLSClockLabel.superview];
                        CGPoint c = gLSClockLabel.center;
                        c.x += d.x; c.y += d.y;
                        // Limitar a pantalla
                        c.x = MAX(gLSClockLabel.bounds.size.width/2,
                                  MIN(c.x, [UIScreen mainScreen].bounds.size.width - gLSClockLabel.bounds.size.width/2));
                        c.y = MAX(40, MIN(c.y, [UIScreen mainScreen].bounds.size.height - 40));
                        gLSClockLabel.center = c;
                        [cpan setTranslation:CGPointZero inView:gLSClockLabel.superview];
                        gLSClockPX = c.x; gLSClockPY = c.y;
                    };
                    cpan = [[UIPanGestureRecognizer alloc] initWithTarget:cp action:@selector(handleTap)];
                    objc_setAssociatedObject(gLSClockLabel, "lsDrag", cp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    objc_setAssociatedObject(gLSClockLabel, "lsDragGR", cpan, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    [gLSClockLabel addGestureRecognizer:cpan];
                }
                // Agregar pan a date label si no tiene
                if (!objc_getAssociatedObject(gLSDateLabel, "lsDrag")) {
                    ALGBlockButton *dp = [ALGBlockButton new];
                    __block UIPanGestureRecognizer *dpan = nil;
                    dp.actionBlock = ^{
                        if (!dpan) return;
                        CGPoint d = [dpan translationInView:gLSDateLabel.superview];
                        CGPoint c = gLSDateLabel.center;
                        c.x += d.x; c.y += d.y;
                        c.x = MAX(gLSDateLabel.bounds.size.width/2,
                                  MIN(c.x, [UIScreen mainScreen].bounds.size.width - gLSDateLabel.bounds.size.width/2));
                        c.y = MAX(40, MIN(c.y, [UIScreen mainScreen].bounds.size.height - 40));
                        gLSDateLabel.center = c;
                        [dpan setTranslation:CGPointZero inView:gLSDateLabel.superview];
                        gLSDatePX = c.x; gLSDatePY = c.y;
                    };
                    dpan = [[UIPanGestureRecognizer alloc] initWithTarget:dp action:@selector(handleTap)];
                    objc_setAssociatedObject(gLSDateLabel, "lsDrag", dp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    objc_setAssociatedObject(gLSDateLabel, "lsDragGR", dpan, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    [gLSDateLabel addGestureRecognizer:dpan];
                }
                // Highlight ya aplicado arriba
            } else {
                gLSClockLabel.layer.borderWidth = 0;
                gLSDateLabel.layer.borderWidth = 0;
                // Devolver interaccion normal
                gLSClockWindow.userInteractionEnabled = NO;
                // Guardar posicion
                NSMutableDictionary *pr = LSPrefs();
                pr[@"clockPX"] = @(gLSClockPX); pr[@"clockPY"] = @(gLSClockPY);
                pr[@"datePX"]  = @(gLSDatePX);  pr[@"datePY"]  = @(gLSDatePY);
                pr[@"clockFontSize"] = @(gLSClockSize);
                pr[@"dateFontSize"]  = @(gLSDateSize);
                LSSavePrefs(pr);
            }
        }
        if (gLSClockGestureView) {
            gLSClockGestureView.userInteractionEnabled = editing;
        }
        if (gLSDateGestureView) {
            gLSDateGestureView.userInteractionEnabled = editing;
        }

        // Overlay instrucciones en bvc.view
        UIView *overlay = [bvc.view viewWithTag:8877];
        if (overlay) { [UIView animateWithDuration:0.2f animations:^{ overlay.alpha=0; }
                         completion:^(BOOL d){ [overlay removeFromSuperview]; }]; overlay = nil; }

        // Cambiar ícono del botón para indicar modo
        UIImageView *lockIV = nil;
        for (UIView *v in btn.subviews)
            if ([v isKindOfClass:[UIImageView class]]) { lockIV = (UIImageView*)v; break; }

        if (editing) {
            if (@available(iOS 13.0,*))
                lockIV.image = [UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right"];
            btn.backgroundColor = [UIColor colorWithRed:0 green:0.48f blue:1 alpha:0.7f];

            CGFloat sw2 = [UIScreen mainScreen].bounds.size.width;
            CGFloat sh2 = [UIScreen mainScreen].bounds.size.height;
            UIView *ov = [[UIView alloc] initWithFrame:CGRectMake(sw2/2-150, sh2-100, 300, 56)];
            ov.tag = 8877;
            ov.userInteractionEnabled = NO;
            UIBlurEffect *be;
            if (@available(iOS 13.0,*)) be=[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
            else be=[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            UIVisualEffectView *bev = [[UIVisualEffectView alloc] initWithEffect:be];
            bev.frame = ov.bounds;
            bev.layer.cornerRadius = 18;
            if (@available(iOS 13.0,*)) bev.layer.cornerCurve = kCACornerCurveContinuous;
            bev.layer.masksToBounds = YES;
            bev.layer.borderWidth = 0.5f;
            bev.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.2f].CGColor;
            [ov addSubview:bev];
            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0,0,300,56)];
            lbl.text = @"Edit mode\nDrag · Pinch to resize · Double tap to exit";
            lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
            lbl.textColor = [UIColor colorWithWhite:1 alpha:0.9f];
            lbl.textAlignment = NSTextAlignmentCenter;
            lbl.numberOfLines = 2;
            [ov addSubview:lbl];
            ov.alpha = 0;
            [bvc.view addSubview:ov];
            [UIView animateWithDuration:0.3f animations:^{ ov.alpha=1; }];

            // Highlight reloj (azul) y fecha (verde)
            if (gLSClockViewRef) {
                gLSClockViewRef.layer.borderColor = [UIColor colorWithRed:0 green:0.6f blue:1 alpha:0.8f].CGColor;
                gLSClockViewRef.layer.borderWidth = 1.5f;
            }
            if (gLSDateViewRef) {
                gLSDateViewRef.layer.borderColor = [UIColor colorWithRed:0.3f green:0.9f blue:0.4f alpha:0.8f].CGColor;
                gLSDateViewRef.layer.borderWidth = 1.5f;
            }
        } else {
            if (@available(iOS 13.0,*))
                lockIV.image = [UIImage systemImageNamed:@"lock.fill"];
            btn.backgroundColor = [UIColor clearColor];

            if (gLSClockViewRef) { gLSClockViewRef.layer.borderWidth=0; [gLSClockViewRef.layer removeAllAnimations]; }
            if (gLSDateViewRef)  { gLSDateViewRef.layer.borderWidth=0;  [gLSDateViewRef.layer  removeAllAnimations]; }

            // Guardar posición y tamaño al salir del modo edición
            NSMutableDictionary *pr = LSPrefs();
            if (gLSClockPX > 0) { pr[@"clockPX"]=@(gLSClockPX); pr[@"clockPY"]=@(gLSClockPY); }
            if (gLSDatePX  > 0) { pr[@"datePX"] =@(gLSDatePX);  pr[@"datePY"] =@(gLSDatePY);  }
            pr[@"clockFontSize"] = @(gLSClockSize);
            pr[@"dateFontSize"]  = @(gLSDateSize);
            LSSavePrefs(pr);
        }
    };

    editProxy.actionBlock = toggleEditMode;
    objc_setAssociatedObject(btn, "editProxy", editProxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // Solo pan y tap — sin triple tap que desbloquea el lockscreen
    [btn addGestureRecognizer:pan];
    [btn addGestureRecognizer:tap];

    [bvc.view addSubview:btn];
    ((ALGLSButtonWindow *)gLSButtonWindow).buttonView = btn;
    gLSButtonWindow.hidden = YES; // oculto hasta que aparezca lockscreen
}

// ─── Hooks visibilidad lockscreen ─────────────────────────────
static IMP orig_lsDashAppear = NULL;
static void hooked_lsDashAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_lsDashAppear) ((void(*)(id,SEL,BOOL))orig_lsDashAppear)(self, _cmd, animated);
    dispatch_async(dispatch_get_main_queue(), ^{
        gLSButtonWindow.hidden = NO;
        if (gLSWindow) gLSWindow.hidden = YES;
        // Mostrar clock window custom
        if (gLSClockWindow) {
            LSUpdateClockDisplay();
            gLSClockWindow.hidden = NO;
            gLSClockWindow.rootViewController.view.alpha = 0;
            [UIView animateWithDuration:0.45f delay:0.1f
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{ gLSClockWindow.rootViewController.view.alpha = 1; }
                             completion:nil];
        }
        // Sincronizar gesture views pero NO mostrar overlay (solo activa con triple tap)
        if (gLSEditOverlay) {
            gLSEditOverlay.hidden = YES; // oculto — solo se muestra con triple tap
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (gLSClockViewRef && gLSClockGestureView)
                    LSSyncGestureView(gLSClockGestureView, gLSClockViewRef);
                if (gLSDateViewRef && gLSDateGestureView)
                    LSSyncGestureView(gLSDateGestureView, gLSDateViewRef);
            });
        }
    });
}

static IMP orig_lsDashDisappear = NULL;
static void hooked_lsDashDisappear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_lsDashDisappear) ((void(*)(id,SEL,BOOL))orig_lsDashDisappear)(self, _cmd, animated);
    // Solo ocultar si el panel LS NO está abierto (evitar que desaparezca al abrir panel)
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL panelOpen = gLSWindow && !gLSWindow.hidden;
        if (!panelOpen) {
            gLSButtonWindow.hidden = YES;
            if (gLSEditOverlay) gLSEditOverlay.hidden = YES;
            if (gLSClockWindow) {
                UIView *cv = gLSClockWindow.rootViewController.view;
                [UIView animateWithDuration:0.25f delay:0
                                    options:UIViewAnimationOptionCurveEaseIn
                                 animations:^{ cv.alpha = 0; }
                                 completion:^(BOOL d) {
                    gLSClockWindow.hidden = YES;
                    cv.alpha = 1;
                }];
            }
        }
    });
}

// ─────────────────────────────────────────
// Constructor
// ─────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════
// CONTROL CENTER — Liquid Glass + Apple Button
// ═══════════════════════════════════════════════════════════════

static UIWindow *gCCAppleWindow = nil;

// Obtener info del dispositivo
#include <sys/utsname.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <sys/sysctl.h>


static NSString *ALGGetMachine(void) {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);

    char *machine = malloc(size);
    if (!machine) return @"Unknown";

    sysctlbyname("hw.machine", machine, &size, NULL, 0);

    NSString *result = [NSString stringWithUTF8String:machine];
    free(machine);

    return result ?: @"Unknown";
}

static NSString *ALGGetIPAddress(void) {
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    NSString *address = @"N/A";

    if (getifaddrs(&interfaces) == 0) {
        temp_addr = interfaces;

        while (temp_addr != NULL) {
            if (temp_addr->ifa_addr->sa_family == AF_INET) {
                NSString *name = [NSString stringWithUTF8String:temp_addr->ifa_name];

                // WiFi interface
                if ([name isEqualToString:@"en0"]) {
                    address = [NSString stringWithUTF8String:
                        inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }

    freeifaddrs(interfaces);
    return address;
}

static NSString *ALGDeviceInfoStringSafe(NSDictionary *info) {
    NSMutableString *s = [NSMutableString string];
    for (NSString *k in info) {
        [s appendFormat:@"%@: %@\n", k, info[k]];
    }
    return s;
}
static NSString *ALGBatteryStateString(UIDeviceBatteryState state) {
    switch (state) {
        case UIDeviceBatteryStateCharging: return @"Charging";
        case UIDeviceBatteryStateFull: return @"Full";
        case UIDeviceBatteryStateUnplugged: return @"Unplugged";
        default: return @"Unknown";
    }
}

static NSDictionary *ALGDeviceInfo(void) {
    NSLog(@"[ALG] START");

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    UIDevice *dev = [UIDevice currentDevice];
    NSProcessInfo *proc = [NSProcessInfo processInfo];

    @try {

        // Básico
        info[@"name"] = dev.name ?: @"Unknown";
        info[@"model"] = dev.localizedModel ?: @"Unknown";
        info[@"system"] = [NSString stringWithFormat:@"%@ %@", dev.systemName, dev.systemVersion];
        info[@"machine"] = ALGGetMachine() ?: @"Unknown";

        // Idioma / tipo
        info[@"deviceType"] = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? @"iPad" : @"iPhone";

        // Orientación
        switch (dev.orientation) {
            case UIDeviceOrientationPortrait: info[@"orientation"] = @"Portrait"; break;
            case UIDeviceOrientationLandscapeLeft: info[@"orientation"] = @"LandscapeLeft"; break;
            case UIDeviceOrientationLandscapeRight: info[@"orientation"] = @"LandscapeRight"; break;
            default: info[@"orientation"] = @"Other"; break;
        }

        // Proceso
        info[@"process"] = proc.processName ?: @"Unknown";
        info[@"host"] = proc.hostName ?: @"Unknown";

        // Batería
        dev.batteryMonitoringEnabled = YES;
        float bat = dev.batteryLevel;

        info[@"battery"] = (bat >= 0)
            ? [NSString stringWithFormat:@"%d%%", (int)(bat * 100)]
            : @"N/A";

        info[@"batteryState"] = ALGBatteryStateString(dev.batteryState) ?: @"Unknown";
        info[@"lowPowerMode"] = proc.isLowPowerModeEnabled ? @"ON" : @"OFF";

        // CPU
        info[@"cpuCores"] = @(proc.activeProcessorCount);

        // Thermal
        switch (proc.thermalState) {
            case NSProcessInfoThermalStateNominal: info[@"thermal"] = @"Nominal"; break;
            case NSProcessInfoThermalStateFair: info[@"thermal"] = @"Fair"; break;
            case NSProcessInfoThermalStateSerious: info[@"thermal"] = @"Serious"; break;
            case NSProcessInfoThermalStateCritical: info[@"thermal"] = @"Critical"; break;
            default: info[@"thermal"] = @"Unknown"; break;
        }

        // Uptime
        info[@"uptime"] = [NSString stringWithFormat:@"%.0f sec", proc.systemUptime];

        // RAM
        double gb = proc.physicalMemory / 1073741824.0;
        info[@"memory"] = [NSString stringWithFormat:@"%.0f GB", gb];

        // Storage
        NSError *err = nil;
        NSDictionary *attrs = [[NSFileManager defaultManager]
            attributesOfFileSystemForPath:@"/var/mobile"
            error:&err];

        if (attrs) {
            double total = [attrs[NSFileSystemSize] doubleValue] / 1073741824.0;
            double free  = [attrs[NSFileSystemFreeSize] doubleValue] / 1073741824.0;

            info[@"storage"] = [NSString stringWithFormat:@"%.0fGB (%.0fGB free)", total, free];
        } else {
            info[@"storage"] = @"N/A";
        }

        // IP local
        info[@"ip"] = ALGGetIPAddress();

    } @catch (NSException *e) {
        NSLog(@"[ALG] EXCEPTION: %@", e);
    }

    NSLog(@"[ALG] DONE");
    return info;
}

static void ALGShowDeviceInfoModal(void) {
    if (!gCCAppleWindow) {
        UIWindowScene *scene = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if ([s isKindOfClass:[UIWindowScene class]]) { scene=(UIWindowScene*)s; break; }
        if (@available(iOS 13.0,*))
            gCCAppleWindow = [[UIWindow alloc] initWithWindowScene:scene];
        else
            gCCAppleWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        gCCAppleWindow.windowLevel = UIWindowLevelAlert + 600;
        gCCAppleWindow.backgroundColor = [UIColor clearColor];
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        gCCAppleWindow.rootViewController = vc;
    }
    gCCAppleWindow.frame = [UIScreen mainScreen].bounds;
    gCCAppleWindow.rootViewController.view.frame = [UIScreen mainScreen].bounds;
    gCCAppleWindow.hidden = NO;
    gCCAppleWindow.userInteractionEnabled = YES;

    UIView *root = gCCAppleWindow.rootViewController.view;
    for (UIView *v in [root.subviews copy]) [v removeFromSuperview];

    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    CGFloat sh = [UIScreen mainScreen].bounds.size.height;
    CGFloat mw = MIN(sw - 40, 300);
    CGFloat mh = 420;
    CGFloat mx = (sw - mw) / 2.0f;
    CGFloat my = (sh - mh) / 2.0f;

    // Fondo tap-to-dismiss
    UIControl *bg = [[UIControl alloc] initWithFrame:[UIScreen mainScreen].bounds];
    bg.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45f];
    bg.alpha = 0;
    ALGBlockButton *bgBtn = [ALGBlockButton buttonWithType:UIButtonTypeCustom];
    bgBtn.frame = bg.bounds;
    __weak UIWindow *ww = gCCAppleWindow;
    bgBtn.actionBlock = ^{
        [UIView animateWithDuration:0.22f animations:^{ bg.alpha=0; }
                         completion:^(BOOL d){
            ww.hidden = YES;
            for (UIView *v in [root.subviews copy]) [v removeFromSuperview];
        }];
    };
    [bgBtn addTarget:bgBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    [bg addSubview:bgBtn];
    [root addSubview:bg];

    // Modal
    UIView *modal = [[UIView alloc] initWithFrame:CGRectMake(mx, my, mw, mh)];
    modal.layer.cornerRadius = 28;
    if (@available(iOS 13.0,*)) modal.layer.cornerCurve = kCACornerCurveContinuous;
    modal.clipsToBounds = YES;
    modal.layer.shadowColor = [UIColor blackColor].CGColor;
    modal.layer.shadowRadius = 30; modal.layer.shadowOpacity = 0.5f;
    modal.layer.shadowOffset = CGSizeMake(0,10);

    // Blur base
    UIBlurEffect *blr;
    if (@available(iOS 13.0,*))
        blr = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    else blr = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blrV = [[UIVisualEffectView alloc] initWithEffect:blr];
    blrV.frame = CGRectMake(0,0,mw,mh); blrV.userInteractionEnabled = NO;
    [modal addSubview:blrV];

    // Tint oscuro glass
    UIView *tnt = [[UIView alloc] initWithFrame:CGRectMake(0,0,mw,mh)];
    tnt.backgroundColor = [UIColor colorWithRed:0.04f green:0.04f blue:0.12f alpha:0.7f];
    tnt.userInteractionEnabled = NO; [modal addSubview:tnt];

    // Gradiente
    CAGradientLayer *grd = [CAGradientLayer layer];
    grd.frame = CGRectMake(0,0,mw,mh);
    grd.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.10f].CGColor,
                   (id)[UIColor colorWithWhite:1 alpha:0.0f].CGColor,
                   (id)[UIColor colorWithWhite:0 alpha:0.05f].CGColor];
    grd.locations = @[@0, @0.4f, @1];
    grd.startPoint = CGPointMake(0.5f,0); grd.endPoint = CGPointMake(0.5f,1);
    [modal.layer addSublayer:grd];

    // Borde gradiente
    CAGradientLayer *brd = [CAGradientLayer layer];
    brd.frame = CGRectMake(0,0,mw,mh);
    brd.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.40f].CGColor,
                   (id)[UIColor colorWithWhite:1 alpha:0.06f].CGColor,
                   (id)[UIColor colorWithWhite:1 alpha:0.16f].CGColor];
    brd.locations = @[@0, @0.5f, @1];
    brd.startPoint = CGPointMake(0.5f,0); brd.endPoint = CGPointMake(0.5f,1);
    CAShapeLayer *bm = [CAShapeLayer layer];
    UIBezierPath *bo = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0,0,mw,mh) cornerRadius:28];
    UIBezierPath *bi = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(CGRectMake(0,0,mw,mh),0.65f,0.65f) cornerRadius:27.35f];
    [bo appendPath:bi]; bo.usesEvenOddFillRule = YES;
    bm.path = bo.CGPath; bm.fillRule = kCAFillRuleEvenOdd;
    brd.mask = bm;
    [modal.layer addSublayer:brd];

    // Logo Apple
    UILabel *appleIcon = [[UILabel alloc] initWithFrame:CGRectMake(0, 28, mw, 48)];
    appleIcon.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0,*)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration
            configurationWithPointSize:40 weight:UIImageSymbolWeightThin];
        UIImage *img = [UIImage systemImageNamed:@"applelogo" withConfiguration:cfg];
        if (!img) img = [UIImage systemImageNamed:@"apple.logo" withConfiguration:cfg];
        if (img) {
            UIImageView *iv = [[UIImageView alloc] initWithImage:img];
            iv.frame = CGRectMake((mw-40)/2, 28, 40, 48);
            iv.tintColor = [UIColor whiteColor];
            iv.contentMode = UIViewContentModeScaleAspectFit;
            [modal addSubview:iv];
        } else {
            appleIcon.text = @""; // SF Symbol no disponible
            appleIcon.font = [UIFont systemFontOfSize:40];
            appleIcon.textColor = [UIColor whiteColor];
            [modal addSubview:appleIcon];
        }
    }

    // Info del dispositivo
    NSDictionary *info = ALGDeviceInfo();
    CGFloat y = 88;

    // Nombre del device grande
    UILabel *nameLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, y, mw-32, 32)];
    nameLbl.text = info[@"name"];
    nameLbl.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    nameLbl.textColor = [UIColor whiteColor];
    nameLbl.textAlignment = NSTextAlignmentCenter;
    [modal addSubview:nameLbl]; y += 34;

    UILabel *modelLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, y, mw-32, 18)];
    modelLbl.text = info[@"model"];
    modelLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightLight];
    modelLbl.textColor = [UIColor colorWithWhite:1 alpha:0.55f];
    modelLbl.textAlignment = NSTextAlignmentCenter;
    [modal addSubview:modelLbl]; y += 30;

    // Separador
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(20, y, mw-40, 0.5f)];
    sep.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12f];
    [modal addSubview:sep]; y += 16;

    // Filas de info
    NSArray *rows = @[
        @[@"system.fill",   @"Sistema",    info[@"system"]],
        @[@"memorychip",    @"Memoria",    info[@"memory"]],
        @[@"internaldrive", @"Disco",      info[@"storage"]],
        @[@"battery.100",   @"Battery",    info[@"battery"]],
    ];

    for (NSArray *row in rows) {
        UIView *rowV = [[UIView alloc] initWithFrame:CGRectMake(16, y, mw-32, 36)];
        if (@available(iOS 13.0,*)) {
            UIImage *ic = [UIImage systemImageNamed:row[0]
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightRegular]];
            UIImageView *icV = [[UIImageView alloc] initWithImage:ic];
            icV.frame = CGRectMake(0, 10, 18, 18);
            icV.tintColor = [UIColor colorWithWhite:1 alpha:0.45f];
            icV.contentMode = UIViewContentModeScaleAspectFit;
            [rowV addSubview:icV];
        }
        UILabel *keyL = [[UILabel alloc] initWithFrame:CGRectMake(26, 8, 80, 20)];
        keyL.text = row[1];
        keyL.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        keyL.textColor = [UIColor colorWithWhite:1 alpha:0.45f];
        [rowV addSubview:keyL];
        UILabel *valL = [[UILabel alloc] initWithFrame:CGRectMake(110, 8, mw-32-110, 20)];
        valL.text = row[2];
        valL.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
        valL.textColor = [UIColor whiteColor];
        valL.textAlignment = NSTextAlignmentRight;
        [rowV addSubview:valL];
        // Linea separadora
        UIView *rl = [[UIView alloc] initWithFrame:CGRectMake(0, 35.5f, mw-32, 0.5f)];
        rl.backgroundColor = [UIColor colorWithWhite:1 alpha:0.07f];
        [rowV addSubview:rl];
        [modal addSubview:rowV];
        y += 38;
    }

    y += 8;
    // Boton cerrar
    ALGBlockButton *closeBtn = [ALGBlockButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake((mw-120)/2, y, 120, 38);
    closeBtn.layer.cornerRadius = 19;
    if (@available(iOS 13.0,*)) closeBtn.layer.cornerCurve = kCACornerCurveContinuous;
    UIVisualEffectView *cbV = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    cbV.frame = CGRectMake(0,0,120,38);
    cbV.layer.cornerRadius = 19; cbV.layer.masksToBounds = YES;
    cbV.userInteractionEnabled = NO; [closeBtn addSubview:cbV];
    CAGradientLayer *cbG = [CAGradientLayer layer];
    cbG.frame = CGRectMake(0,0,120,38); cbG.cornerRadius = 19;
    cbG.colors = @[(id)[UIColor colorWithRed:0.3f green:0.3f blue:0.9f alpha:0.7f].CGColor,
                   (id)[UIColor colorWithRed:0.2f green:0.2f blue:0.7f alpha:0.55f].CGColor];
    cbG.startPoint = CGPointMake(0,0); cbG.endPoint = CGPointMake(1,1);
    [closeBtn.layer addSublayer:cbG];
    UILabel *cbL = [[UILabel alloc] initWithFrame:CGRectMake(0,0,120,38)];
    cbL.text = @"Cerrar"; cbL.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    cbL.textColor = [UIColor whiteColor]; cbL.textAlignment = NSTextAlignmentCenter;
    cbL.userInteractionEnabled = NO; [closeBtn addSubview:cbL];
    __weak UIView *wBg = bg;
    closeBtn.actionBlock = ^{
        [UIView animateWithDuration:0.22f animations:^{ wBg.alpha=0; modal.alpha=0; modal.transform=CGAffineTransformMakeScale(0.92f,0.92f); }
                         completion:^(BOOL d){
            ww.hidden = YES;
            for (UIView *v in [root.subviews copy]) [v removeFromSuperview];
        }];
    };
    [closeBtn addTarget:closeBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    [modal addSubview:closeBtn];

    [root addSubview:modal];

    // Animacion entrada
    modal.alpha = 0; bg.alpha = 0;
    modal.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(0.88f,0.88f), CGAffineTransformMakeTranslation(0,-12));
    [UIView animateWithDuration:0.42f delay:0 usingSpringWithDamping:0.78f initialSpringVelocity:0.5f
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{ modal.alpha=1; bg.alpha=1; modal.transform=CGAffineTransformIdentity; }
                     completion:nil];
}

// Liquid glass para CC modules
static CGFloat ALGCCModuleRadius(UIView *v) {
    CGFloat w = v.frame.size.width, h = v.frame.size.height;
    if (w < 100 && h < 100 && w == h) return w / 2;
    if (w != h) return fminf(w, h) / 2;
    return 65.0f;
}

static void ALGApplyGlassToCC(UIView *view) {
    if (!view || view.bounds.size.width < 10) return;
    CGFloat r = ALGCCModuleRadius(view);
    // Usar ALGApplyLiquidGlass que ya existe en el proyecto
    LGParams p = LGParamsCC;
    p.cornerRadius = r;
    ALGApplyLiquidGlass(view, p);
    view.layer.continuousCorners = YES;
}

// Hook layoutSubviews de CCUIContentModuleContentContainerView
static IMP orig_ccModuleLayout = NULL;
static void hooked_ccModuleLayout(UIView *self, SEL _cmd) {
    if (orig_ccModuleLayout) ((void(*)(id,SEL))orig_ccModuleLayout)(self, _cmd);
    dispatch_async(dispatch_get_main_queue(), ^{
        @try { ALGApplyGlassToCC(self); } @catch(...) {}
    });
}

// Hook setPresentationState — se llama cuando el CC abre/cierra
// state=1: abriendo, state=3: cerrando
static IMP orig_ccPresentationState = NULL;
static void hooked_ccPresentationState(UIViewController *self, SEL _cmd, NSInteger state) {
    if (orig_ccPresentationState) ((void(*)(id,SEL,NSInteger))orig_ccPresentationState)(self, _cmd, state);
    if (state != 1) return; // solo al abrir
    if (![NSStringFromClass([self class]) isEqualToString:@"CCUIModularControlCenterOverlayViewController"]) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.25*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIView *ccView = self.view;
        if (!ccView) return;
        if (ccView.bounds.size.height < 200) return;
        // Remover botones anteriores para refrescar estado (terminal toggle)
        UIView *oldApple = [ccView viewWithTag:9876];
        UIView *oldFiddler = [ccView viewWithTag:9877];
        UIView *oldTerm = [ccView viewWithTag:9878];
        if (oldApple && oldFiddler) return; // ya existen, no recrear
        [oldApple removeFromSuperview];
        [oldFiddler removeFromSuperview];
        [oldTerm removeFromSuperview];
        CGFloat btnS = 36;

        // Buscar el ultimo modulo visible para poner el boton al lado
        UIView *lastModule = nil;
        CGFloat maxY = 0;
        for (UIView *sub in ccView.subviews) {
            if ([NSStringFromClass([sub class]) containsString:@"ContentModuleContentContainer"]) {
                CGFloat bottom = CGRectGetMaxY(sub.frame);
                if (bottom > maxY) { maxY = bottom; lastModule = sub; }
            }
        }

        CGFloat bx, by;
        if (lastModule) {
            // Al lado derecho del ultimo modulo, alineado verticalmente con el centro
            bx = CGRectGetMaxX(lastModule.frame) + 8;
            by = lastModule.frame.origin.y + (lastModule.frame.size.height - btnS) / 2.0f;
            // Si se sale de la pantalla, poner debajo del ultimo modulo centrado
            if (bx + btnS > ccView.bounds.size.width - 4) {
                bx = (ccView.bounds.size.width - btnS) / 2.0f;
                by = maxY + 12;
            }
        } else {
            bx = (ccView.bounds.size.width - btnS) / 2.0f;
            by = ccView.bounds.size.height - 60;
        }
        ALGBlockButton *appleBtn = [ALGBlockButton buttonWithType:UIButtonTypeCustom];
        appleBtn.frame = CGRectMake(bx, by, btnS, btnS);
        appleBtn.tag = 9876;
        appleBtn.layer.cornerRadius = btnS / 2;
        if (@available(iOS 13.0,*)) appleBtn.layer.cornerCurve = kCACornerCurveContinuous;
        UIVisualEffectView *abV = [[UIVisualEffectView alloc]
            initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
        abV.frame = CGRectMake(0,0,btnS,btnS);
        abV.layer.cornerRadius = btnS/2; abV.layer.masksToBounds = YES;
        abV.userInteractionEnabled = NO; [appleBtn addSubview:abV];
        CAGradientLayer *abG = [CAGradientLayer layer];
        abG.frame = CGRectMake(0,0,btnS,btnS); abG.cornerRadius = btnS/2;
        abG.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.22f].CGColor,
                       (id)[UIColor colorWithWhite:1 alpha:0.05f].CGColor];
        abG.startPoint = CGPointMake(0.5f,0); abG.endPoint = CGPointMake(0.5f,1);
        [appleBtn.layer addSublayer:abG];
        appleBtn.layer.borderWidth = 0.5f;
        appleBtn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.35f].CGColor;
        appleBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        appleBtn.layer.shadowOpacity = 0.3f; appleBtn.layer.shadowRadius = 8;
        appleBtn.layer.shadowOffset = CGSizeMake(0,3);
        if (@available(iOS 13.0,*)) {
            UIImage *appleImg = [UIImage systemImageNamed:@"applelogo"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium]];
            if (appleImg) {
                UIImageView *aiv = [[UIImageView alloc] initWithImage:appleImg];
                aiv.frame = CGRectMake((btnS-18)/2, (btnS-18)/2, 18, 18);
                aiv.tintColor = [UIColor whiteColor];
                aiv.contentMode = UIViewContentModeScaleAspectFit;
                aiv.userInteractionEnabled = NO;
                [appleBtn addSubview:aiv];
            }
        }
        appleBtn.alpha = 0;
        appleBtn.actionBlock = ^{
            if (@available(iOS 10.0,*)) [[UIImpactFeedbackGenerator new] impactOccurred];
            ALGShowDeviceInfoModal();
        };
        [appleBtn addTarget:appleBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [ccView addSubview:appleBtn];

        // Boton Fiddler — al lado del boton Apple
        ALGBlockButton *fiddlerBtn = [ALGBlockButton buttonWithType:UIButtonTypeCustom];
        fiddlerBtn.frame = CGRectMake(bx + btnS + 10, by, btnS, btnS);
        fiddlerBtn.tag = 9877;
        fiddlerBtn.layer.cornerRadius = btnS / 2;
        if (@available(iOS 13.0,*)) fiddlerBtn.layer.cornerCurve = kCACornerCurveContinuous;
        UIVisualEffectView *fbV = [[UIVisualEffectView alloc]
            initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
        fbV.frame = CGRectMake(0,0,btnS,btnS);
        fbV.layer.cornerRadius = btnS/2; fbV.layer.masksToBounds = YES;
        fbV.userInteractionEnabled = NO; [fiddlerBtn addSubview:fbV];
        CAGradientLayer *fbG = [CAGradientLayer layer];
        fbG.frame = CGRectMake(0,0,btnS,btnS); fbG.cornerRadius = btnS/2;
        fbG.colors = @[(id)[UIColor colorWithRed:0.3f green:0.6f blue:1 alpha:0.25f].CGColor,
                       (id)[UIColor colorWithRed:0.2f green:0.4f blue:0.8f alpha:0.1f].CGColor];
        fbG.startPoint = CGPointMake(0.5f,0); fbG.endPoint = CGPointMake(0.5f,1);
        [fiddlerBtn.layer addSublayer:fbG];
        fiddlerBtn.layer.borderWidth = 0.5f;
        fiddlerBtn.layer.borderColor = [UIColor colorWithRed:0.4f green:0.7f blue:1 alpha:0.4f].CGColor;
        fiddlerBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        fiddlerBtn.layer.shadowOpacity = 0.25f; fiddlerBtn.layer.shadowRadius = 6;
        if (@available(iOS 13.0,*)) {
            UIImage *netImg = [UIImage systemImageNamed:@"folder.badge.gearshape"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]];
            if (!netImg) netImg = [UIImage systemImageNamed:@"folder.fill"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]];
            if (netImg) {
                UIImageView *fiv = [[UIImageView alloc] initWithImage:netImg];
                fiv.frame = CGRectMake((btnS-17)/2, (btnS-17)/2, 17, 17);
                fiv.tintColor = [UIColor colorWithRed:0.5f green:0.8f blue:1 alpha:0.95f];
                fiv.contentMode = UIViewContentModeScaleAspectFit;
                fiv.userInteractionEnabled = NO;
                [fiddlerBtn addSubview:fiv];
            }
        }
        fiddlerBtn.alpha = 0;
        fiddlerBtn.actionBlock = ^{
            if (@available(iOS 10.0,*)) [[UIImpactFeedbackGenerator new] impactOccurred];
            ALGShowFileBrowser(@"/var/mobile");
        };


        [fiddlerBtn addTarget:fiddlerBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [ccView addSubview:fiddlerBtn];

        // Boton Terminal — solo si esta habilitado
        if (gTerminalEnabled) {
            ALGBlockButton *termBtn = [ALGBlockButton buttonWithType:UIButtonTypeCustom];
            termBtn.frame = CGRectMake(bx - btnS - 10, by, btnS, btnS);
            termBtn.tag = 9878;
            termBtn.layer.cornerRadius = btnS / 2;
            if (@available(iOS 13.0,*)) termBtn.layer.cornerCurve = kCACornerCurveContinuous;
            UIVisualEffectView *tbV = [[UIVisualEffectView alloc]
                initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
            tbV.frame = CGRectMake(0,0,btnS,btnS);
            tbV.layer.cornerRadius = btnS/2; tbV.layer.masksToBounds = YES;
            tbV.userInteractionEnabled = NO; [termBtn addSubview:tbV];
            CAGradientLayer *tbG = [CAGradientLayer layer];
            tbG.frame = CGRectMake(0,0,btnS,btnS); tbG.cornerRadius = btnS/2;
            tbG.colors = @[(id)[UIColor colorWithRed:0.1f green:0.8f blue:0.4f alpha:0.25f].CGColor,
                           (id)[UIColor colorWithRed:0.05f green:0.5f blue:0.25f alpha:0.1f].CGColor];
            tbG.startPoint = CGPointMake(0.5f,0); tbG.endPoint = CGPointMake(0.5f,1);
            [termBtn.layer addSublayer:tbG];
            termBtn.layer.borderWidth = 0.5f;
            termBtn.layer.borderColor = [UIColor colorWithRed:0.2f green:0.9f blue:0.5f alpha:0.4f].CGColor;
            if (@available(iOS 13.0,*)) {
                UIImage *timg = [UIImage systemImageNamed:@"terminal.fill"
                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]];
                if (timg) {
                    UIImageView *tiv = [[UIImageView alloc] initWithImage:timg];
                    tiv.frame = CGRectMake((btnS-17)/2,(btnS-17)/2,17,17);
                    tiv.tintColor = [UIColor colorWithRed:0.3f green:1 blue:0.5f alpha:0.9f];
                    tiv.contentMode = UIViewContentModeScaleAspectFit;
                    tiv.userInteractionEnabled = NO;
                    [termBtn addSubview:tiv];
                }
            }
            termBtn.alpha = 0;
            termBtn.actionBlock = ^{
                if (@available(iOS 10.0,*)) [[UIImpactFeedbackGenerator new] impactOccurred];
                ALGShowTerminal();
            };
            [termBtn addTarget:termBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
            [ccView addSubview:termBtn];
        }

        [UIView animateWithDuration:0.3f animations:^{
            appleBtn.alpha = 1;
            fiddlerBtn.alpha = 1;
            [[ccView viewWithTag:9878] setAlpha:1];
        }];
    });
}

// ═══════════════════════════════════════════════════════════════
// MINI FILE BROWSER — Fiddler style
// Navega /var/mobile/ y /var/ con permisos SpringBoard
// ═══════════════════════════════════════════════════════════════

static UIWindow *gFileBrowserWindow = nil;
static NSMutableArray *gFBHistory = nil;

static UIView *ALGMakeFBRow(NSString *name, BOOL isDir, CGFloat y, CGFloat w,
                              NSString *fullPath, UIView *listContainer) {
    ALGBlockButton *row = [ALGBlockButton buttonWithType:UIButtonTypeCustom];
    row.frame = CGRectMake(0, y, w, 44);
    row.backgroundColor = [UIColor colorWithWhite:1 alpha:0.03f];

    // Icono
    UILabel *ico = [[UILabel alloc] initWithFrame:CGRectMake(12, 12, 22, 22)];
    if (@available(iOS 13.0,*)) {
        NSString *sym = isDir ? @"folder.fill" : @"doc.text.fill";
        UIImage *img = [UIImage systemImageNamed:sym
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightRegular]];
        UIImageView *iv = [[UIImageView alloc] initWithImage:img];
        iv.frame = CGRectMake(12, 13, 18, 18);
        iv.tintColor = isDir ? [UIColor colorWithRed:0.4f green:0.7f blue:1 alpha:0.9f]
                              : [UIColor colorWithWhite:1 alpha:0.45f];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.userInteractionEnabled = NO;
        [row addSubview:iv];
    } else {
        ico.text = isDir ? @"📁" : @"📄";
        ico.font = [UIFont systemFontOfSize:14];
        [row addSubview:ico];
    }

    // Nombre — dejar espacio para botón copy
    UILabel *nameLbl = [[UILabel alloc] initWithFrame:CGRectMake(38, 0, w-110, 44)];
    nameLbl.text = name;
    nameLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    nameLbl.textColor = [UIColor whiteColor];
    nameLbl.userInteractionEnabled = NO;
    [row addSubview:nameLbl];

    // Botón copiar path — long press en la fila
    ALGBlockButton *copyBtn = [ALGBlockButton buttonWithType:UIButtonTypeCustom];
    copyBtn.frame = CGRectMake(w-58, 8, 28, 28);
    copyBtn.layer.cornerRadius = 6;
    copyBtn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.07f];
    if (@available(iOS 13.0,*)) {
        UIImage *cimg = [UIImage systemImageNamed:@"doc.on.doc"
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightRegular]];
        UIImageView *civ2 = [[UIImageView alloc] initWithImage:cimg];
        civ2.frame = CGRectMake(7, 7, 14, 14);
        civ2.tintColor = [UIColor colorWithWhite:1 alpha:0.4f];
        civ2.contentMode = UIViewContentModeScaleAspectFit;
        civ2.userInteractionEnabled = NO;
        [copyBtn addSubview:civ2];
    }
    __weak ALGBlockButton *wCopyBtn = copyBtn;
    copyBtn.actionBlock = ^{
        [UIPasteboard generalPasteboard].string = fullPath;
        [UIView animateWithDuration:0.1f animations:^{ wCopyBtn.backgroundColor=[UIColor colorWithRed:0.2f green:0.6f blue:1 alpha:0.5f]; }
                         completion:^(BOOL d){
            [UIView animateWithDuration:0.3f animations:^{ wCopyBtn.backgroundColor=[UIColor colorWithWhite:1 alpha:0.07f]; }];
        }];
    };
    [copyBtn addTarget:copyBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:copyBtn];

    // Chevron si es directorio
    if (isDir) {
        if (@available(iOS 13.0,*)) {
            UIImage *chev = [UIImage systemImageNamed:@"chevron.right"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightLight]];
            UIImageView *chevV = [[UIImageView alloc] initWithImage:chev];
            chevV.frame = CGRectMake(w-22, 15, 10, 14);
            chevV.tintColor = [UIColor colorWithWhite:1 alpha:0.3f];
            chevV.userInteractionEnabled = NO;
            [row addSubview:chevV];
        }
    }

    // Separador
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(38, 43.5f, w-38, 0.5f)];
    sep.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06f];
    sep.userInteractionEnabled = NO;
    [row addSubview:sep];

    if (isDir) {
        row.actionBlock = ^{ ALGShowFileBrowser(fullPath); };
    } else {
        // Archivo — mostrar contenido en una subview
        row.actionBlock = ^{
            NSError *err = nil;
            NSString *txt = nil;
            // Intentar leer como UTF8 primero
            txt = [NSString stringWithContentsOfFile:fullPath encoding:NSUTF8StringEncoding error:&err];

            // Si falla, intentar como plist (binario o XML)
            if (!txt) {
                NSData *data = [NSData dataWithContentsOfFile:fullPath];
                if (data) {
                    // Detectar bplist (binary plist magic bytes: "bplist")
                    BOOL isBplist = (data.length > 6 &&
                        memcmp(data.bytes, "bplist", 6) == 0);
                    if (isBplist || [fullPath.pathExtension.lowercaseString isEqualToString:@"plist"]) {
                        NSError *pErr = nil;
                        id pobj = [NSPropertyListSerialization propertyListWithData:data
                                      options:NSPropertyListImmutable
                                       format:nil error:&pErr];
                        if (pobj) {
                            // Convertir a XML legible
                            NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:pobj
                                                  format:NSPropertyListXMLFormat_v1_0
                                                 options:0 error:&pErr];
                            if (xmlData)
                                txt = [[NSString alloc] initWithData:xmlData encoding:NSUTF8StringEncoding];
                        }
                        if (!txt) txt = [NSString stringWithFormat:@"[plist parse error] %@",
                                         pErr.localizedDescription ?: @"unknown"];
                    } else {
                        // Archivo binario — mostrar hex dump de los primeros 512 bytes
                        NSMutableString *hex = [NSMutableString string];
                        [hex appendString:@"[Binary file - hex preview]\n\n"];
                        NSUInteger pLen = MIN(data.length, 512);
                        const uint8_t *bytes = (const uint8_t *)data.bytes;
                        for (NSUInteger hi = 0; hi < pLen; hi += 16) {
                            [hex appendFormat:@"%04lx  ", (unsigned long)hi];
                            for (NSUInteger hj = 0; hj < 16; hj++) {
                                if (hi+hj < pLen)
                                    [hex appendFormat:@"%02x ", bytes[hi+hj]];
                                else [hex appendString:@"   "];
                            }
                            [hex appendString:@" |"];
                            for (NSUInteger hj = 0; hj < 16 && hi+hj < pLen; hj++) {
                                uint8_t c = bytes[hi+hj];
                                [hex appendFormat:@"%c", (c >= 32 && c < 127) ? c : '.'];
                            }
                            [hex appendString:@"|\n"];
                        }
                        if (data.length > 512)
                            [hex appendFormat:@"\n... (%lu bytes total)", (unsigned long)data.length];
                        txt = hex;
                    }
                } else {
                    txt = @"[Could not read file]";
                }
            }

            UIView *fbRoot = gFileBrowserWindow.rootViewController.view;
            [[fbRoot viewWithTag:9902] removeFromSuperview];

            CGFloat sw = [UIScreen mainScreen].bounds.size.width;
            CGFloat sh = [UIScreen mainScreen].bounds.size.height;
            UIView *viewer = [[UIView alloc] initWithFrame:CGRectMake(10, sh*0.15f, sw-20, sh*0.7f)];
            viewer.tag = 9902;
            viewer.layer.cornerRadius = 18;
            if (@available(iOS 13.0,*)) viewer.layer.cornerCurve = kCACornerCurveContinuous;
            viewer.clipsToBounds = YES;
            UIBlurEffect *blr;
            if (@available(iOS 13.0,*)) blr = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
            else blr = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            UIVisualEffectView *vbv = [[UIVisualEffectView alloc] initWithEffect:blr];
            vbv.frame = viewer.bounds; vbv.userInteractionEnabled = NO;
            [viewer addSubview:vbv];
            UIView *vtnt = [[UIView alloc] initWithFrame:viewer.bounds];
            vtnt.backgroundColor = [UIColor colorWithRed:0.03f green:0.03f blue:0.10f alpha:0.75f];
            vtnt.userInteractionEnabled = NO; [viewer addSubview:vtnt];

            CGFloat vw = viewer.bounds.size.width;
            CGFloat vh = viewer.bounds.size.height;
            BOOL isPlist = [fullPath.pathExtension.lowercaseString isEqualToString:@"plist"];

            // Header
            UILabel *vtitle = [[UILabel alloc] initWithFrame:CGRectMake(14, 12, vw-100, 20)];
            vtitle.text = [fullPath lastPathComponent];
            vtitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
            vtitle.textColor = [UIColor whiteColor]; [viewer addSubview:vtitle];

            // Boton cerrar
            ALGBlockButton *vclose = [ALGBlockButton buttonWithType:UIButtonTypeCustom];
            vclose.frame = CGRectMake(vw-44, 8, 34, 34);
            [vclose setTitle:@"x" forState:UIControlStateNormal];
            [vclose setTitleColor:[UIColor colorWithWhite:1 alpha:0.4f] forState:UIControlStateNormal];
            vclose.titleLabel.font = [UIFont systemFontOfSize:12];
            vclose.layer.cornerRadius = 17;
            vclose.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08f];
            __weak UIView *wv = viewer;
            vclose.actionBlock = ^{ [wv removeFromSuperview]; };
            [vclose addTarget:vclose action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
            [viewer addSubview:vclose];

            // Boton Edit (solo para plist y archivos de texto)
            __block BOOL editMode __attribute__((unused)) = NO;
            __block UITextView *editTV = nil;
            __block UIScrollView *readScroll = nil;
            __block NSString *currentTxt = txt;

            ALGBlockButton *editBtn = [ALGBlockButton buttonWithType:UIButtonTypeCustom];
            editBtn.frame = CGRectMake(vw-84, 8, 38, 34);
            editBtn.layer.cornerRadius = 8;
            editBtn.backgroundColor = [UIColor colorWithRed:0.2f green:0.5f blue:0.9f alpha:0.7f];
            [editBtn setTitle:@"Edit" forState:UIControlStateNormal];
            [editBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            editBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
            [viewer addSubview:editBtn];

            // Boton Save (oculto hasta que se edita)
            ALGBlockButton *saveBtn = [ALGBlockButton buttonWithType:UIButtonTypeCustom];
            saveBtn.frame = CGRectMake(vw-84, 8, 38, 34);
            saveBtn.layer.cornerRadius = 8;
            saveBtn.backgroundColor = [UIColor colorWithRed:0 green:0.65f blue:0.3f alpha:0.85f];
            [saveBtn setTitle:@"Save" forState:UIControlStateNormal];
            [saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            saveBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
            saveBtn.hidden = YES;
            [viewer addSubview:saveBtn];

            // Linea sep header
            UIView *hline = [[UIView alloc] initWithFrame:CGRectMake(0, 43.5f, vw, 0.5f)];
            hline.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1f];
            [viewer addSubview:hline];

            // Scroll de lectura
            UIScrollView *vscroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0,44,vw,vh-44)];
            vscroll.showsVerticalScrollIndicator = YES; vscroll.bounces = YES;
            readScroll = vscroll;
            UILabel *content = [[UILabel alloc] init];
            content.text = txt;
            content.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
            content.textColor = [UIColor colorWithRed:0.6f green:0.9f blue:0.6f alpha:1];
            content.numberOfLines = 0;
            CGSize sz = [txt boundingRectWithSize:CGSizeMake(vw-16, CGFLOAT_MAX)
                                          options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:@{NSFontAttributeName: content.font} context:nil].size;
            content.frame = CGRectMake(8, 8, vw-16, sz.height+16);
            vscroll.contentSize = CGSizeMake(vw, sz.height+32);
            [vscroll addSubview:content];
            [viewer addSubview:vscroll];

            // TextView de edicion (oculto)
            UITextView *tv = [[UITextView alloc] initWithFrame:CGRectMake(0,44,vw,vh-44)];
            tv.text = txt;
            tv.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
            tv.textColor = [UIColor colorWithRed:0.5f green:0.85f blue:0.5f alpha:1];
            tv.backgroundColor = [UIColor clearColor];
            tv.keyboardAppearance = UIKeyboardAppearanceDark;
            tv.hidden = YES;
            tv.autocorrectionType = UITextAutocorrectionTypeNo;
            tv.autocapitalizationType = UITextAutocapitalizationTypeNone;
            tv.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
            editTV = tv;
            [viewer addSubview:tv];

            // Accion Edit
            __weak ALGBlockButton *wEditBtn = editBtn;
            __weak ALGBlockButton *wSaveBtn = saveBtn;
            __weak UIScrollView *wReadScroll = readScroll;
            __weak UITextView *wEditTV = editTV;
            editBtn.actionBlock = ^{
                editMode = YES;
                wEditTV.text = currentTxt;
                wEditTV.hidden = NO;
                wReadScroll.hidden = YES;
                wEditBtn.hidden = YES;
                wSaveBtn.hidden = NO;
                [wEditTV becomeFirstResponder];
            };
            [editBtn addTarget:editBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];

            // Accion Save
            NSString *savePath = fullPath;
            saveBtn.actionBlock = ^{
                NSString *editedTxt = editTV.text ?: @"";
                NSError *saveErr = nil;
                BOOL ok = NO;

                if (isPlist) {
                    // Parsear XML editado y guardar como plist binario original
                    NSData *xmlData = [editedTxt dataUsingEncoding:NSUTF8StringEncoding];
                    id pobj = [NSPropertyListSerialization propertyListWithData:xmlData
                                  options:NSPropertyListImmutable format:nil error:&saveErr];
                    if (pobj) {
                        NSData *outData = [NSPropertyListSerialization dataWithPropertyList:pobj
                                              format:NSPropertyListBinaryFormat_v1_0
                                             options:0 error:&saveErr];
                        if (outData) ok = [outData writeToFile:savePath atomically:YES];
                    }
                } else {
                    ok = [editedTxt writeToFile:savePath atomically:YES
                                      encoding:NSUTF8StringEncoding error:&saveErr];
                }

                // Toast
                UILabel *toast = [[UILabel alloc] init];
                toast.text = ok ? @"Saved!" : [NSString stringWithFormat:@"Error: %@", saveErr.localizedDescription ?: @"failed"];
                toast.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
                toast.textColor = [UIColor whiteColor];
                toast.backgroundColor = ok ? [UIColor colorWithRed:0 green:0.6f blue:0.3f alpha:0.9f]
                                           : [UIColor colorWithRed:0.8f green:0.2f blue:0.2f alpha:0.9f];
                toast.textAlignment = NSTextAlignmentCenter;
                [toast sizeToFit];
                CGFloat tw = toast.bounds.size.width + 24;
                toast.frame = CGRectMake((vw-tw)/2, vh-50, tw, 30);
                toast.layer.cornerRadius = 15; toast.clipsToBounds = YES;
                toast.alpha = 0; [wv addSubview:toast];
                [UIView animateWithDuration:0.2f animations:^{ toast.alpha=1; }
                                 completion:^(BOOL d){
                    [UIView animateWithDuration:0.3f delay:1.5f options:0
                                    animations:^{ toast.alpha=0; }
                                    completion:^(BOOL d2){ [toast removeFromSuperview]; }];
                }];
                if (ok) { editMode = NO; wEditTV.hidden=YES; wReadScroll.hidden=NO; wEditBtn.hidden=NO; wSaveBtn.hidden=YES; [wEditTV resignFirstResponder]; }
            };
            [saveBtn addTarget:saveBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];

            viewer.alpha = 0;
            viewer.transform = CGAffineTransformMakeScale(0.92f,0.92f);
            [fbRoot addSubview:viewer];
            [UIView animateWithDuration:0.3f delay:0 usingSpringWithDamping:0.8f initialSpringVelocity:0.5f
                                options:0 animations:^{ viewer.alpha=1; viewer.transform=CGAffineTransformIdentity; }
                             completion:nil];
        };
    }
    [row addTarget:row action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    return row;
}

static void ALGShowFileBrowser(NSString *path) {
    if (!gFBHistory) gFBHistory = [NSMutableArray array];

    if (!gFileBrowserWindow) {
        UIWindowScene *scene = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if ([s isKindOfClass:[UIWindowScene class]]) { scene=(UIWindowScene*)s; break; }
        if (@available(iOS 13.0,*))
            gFileBrowserWindow = [[UIWindow alloc] initWithWindowScene:scene];
        else
            gFileBrowserWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        gFileBrowserWindow.windowLevel = UIWindowLevelAlert + 700;
        gFileBrowserWindow.backgroundColor = [UIColor clearColor];
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        gFileBrowserWindow.rootViewController = vc;
    }

    gFileBrowserWindow.frame = [UIScreen mainScreen].bounds;
    gFileBrowserWindow.rootViewController.view.frame = [UIScreen mainScreen].bounds;
    gFileBrowserWindow.hidden = NO;
    gFileBrowserWindow.userInteractionEnabled = YES;
    UIView *root = gFileBrowserWindow.rootViewController.view;

    // Push history
    if (path) [gFBHistory addObject:path];

    // Limpiar
    for (UIView *v in [root.subviews copy]) [v removeFromSuperview];

    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    CGFloat sh = [UIScreen mainScreen].bounds.size.height;
    CGFloat bw = sw - 20;
    CGFloat bh = sh * 0.78f;
    CGFloat bx = 10;
    CGFloat by = (sh - bh) / 2.0f;

    // Fondo dimmer
    UIControl *dim = [[UIControl alloc] initWithFrame:[UIScreen mainScreen].bounds];
    dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5f];
    dim.alpha = 0;
    ALGBlockButton *dimBtn = [ALGBlockButton buttonWithType:UIButtonTypeCustom];
    dimBtn.frame = dim.bounds;
    __weak UIWindow *ww = gFileBrowserWindow;
    dimBtn.actionBlock = ^{
        [UIView animateWithDuration:0.2f animations:^{ dim.alpha=0; }
                         completion:^(BOOL d){ ww.hidden=YES; [gFBHistory removeAllObjects]; for(UIView*v in [root.subviews copy])[v removeFromSuperview]; }];
    };
    [dimBtn addTarget:dimBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    [dim addSubview:dimBtn]; [root addSubview:dim];

    // Ventana principal
    UIView *browser = [[UIView alloc] initWithFrame:CGRectMake(bx, by, bw, bh)];
    browser.layer.cornerRadius = 24;
    if (@available(iOS 13.0,*)) browser.layer.cornerCurve = kCACornerCurveContinuous;
    browser.clipsToBounds = YES;

    // Blur + tint
    UIBlurEffect *blr;
    if (@available(iOS 13.0,*)) blr=[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    else blr=[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *bv=[[UIVisualEffectView alloc] initWithEffect:blr];
    bv.frame=CGRectMake(0,0,bw,bh); bv.userInteractionEnabled=NO; [browser addSubview:bv];
    UIView *tnt=[[UIView alloc] initWithFrame:CGRectMake(0,0,bw,bh)];
    tnt.backgroundColor=[UIColor colorWithRed:0.03f green:0.04f blue:0.12f alpha:0.72f];
    tnt.userInteractionEnabled=NO; [browser addSubview:tnt];
    // Gradiente borde
    CAGradientLayer *brdG=[CAGradientLayer layer];
    brdG.frame=CGRectMake(0,0,bw,bh);
    brdG.colors=@[(id)[UIColor colorWithWhite:1 alpha:0.35f].CGColor,
                  (id)[UIColor colorWithWhite:1 alpha:0.05f].CGColor,
                  (id)[UIColor colorWithWhite:1 alpha:0.14f].CGColor];
    brdG.locations=@[@0,@0.5f,@1]; brdG.startPoint=CGPointMake(0.5f,0); brdG.endPoint=CGPointMake(0.5f,1);
    CAShapeLayer *bm=[CAShapeLayer layer];
    UIBezierPath *bp=[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0,0,bw,bh) cornerRadius:24];
    UIBezierPath *bpi=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(CGRectMake(0,0,bw,bh),0.6f,0.6f) cornerRadius:23.4f];
    [bp appendPath:bpi]; bp.usesEvenOddFillRule=YES;
    bm.path=bp.CGPath; bm.fillRule=kCAFillRuleEvenOdd; brdG.mask=bm;
    [browser.layer addSublayer:brdG];

    // Header
    UIView *hdr = [[UIView alloc] initWithFrame:CGRectMake(0,0,bw,52)];
    hdr.backgroundColor = [UIColor clearColor];
    // Pill drag
    UIView *pill=[[UIView alloc] initWithFrame:CGRectMake((bw-28)/2,6,28,4)];
    pill.backgroundColor=[UIColor colorWithWhite:1 alpha:0.2f]; pill.layer.cornerRadius=2;
    [hdr addSubview:pill];
    // Icono Fiddler (usamos SF Symbol de lupa + network)
    if (@available(iOS 13.0,*)) {
        UIImage *fimg = [UIImage systemImageNamed:@"network"
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightMedium]];
        UIImageView *fiv = [[UIImageView alloc] initWithImage:fimg];
        fiv.frame = CGRectMake(14, 16, 20, 20);
        fiv.tintColor = [UIColor colorWithRed:0.4f green:0.7f blue:1 alpha:0.9f];
        fiv.contentMode = UIViewContentModeScaleAspectFit;
        [hdr addSubview:fiv];
    }
    UILabel *title=[[UILabel alloc] initWithFrame:CGRectMake(42,14,bw-120,22)];
    title.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    title.textColor=[UIColor whiteColor];
    // Mostrar path actual
    NSString *dispPath = path ?: @"/";
    if (dispPath.length > 30) dispPath = [NSString stringWithFormat:@"...%@", [dispPath substringFromIndex:dispPath.length-27]];
    title.text = dispPath;
    [hdr addSubview:title];

    // Boton atras
    if (gFBHistory.count > 1) {
        ALGBlockButton *back=[ALGBlockButton buttonWithType:UIButtonTypeCustom];
        back.frame=CGRectMake(bw-88,12,36,28);
        if (@available(iOS 13.0,*)) {
            UIImage *bi=[UIImage systemImageNamed:@"chevron.left"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightMedium]];
            UIImageView *biv=[[UIImageView alloc] initWithImage:bi];
            biv.frame=CGRectMake(8,6,12,16); biv.tintColor=[UIColor whiteColor];
            biv.contentMode=UIViewContentModeScaleAspectFit; biv.userInteractionEnabled=NO;
            [back addSubview:biv];
        }
        back.backgroundColor=[UIColor colorWithWhite:1 alpha:0.08f]; back.layer.cornerRadius=8;
        back.actionBlock=^{
            [gFBHistory removeLastObject];
            NSString *prev=gFBHistory.lastObject ?: @"/var/mobile";
            [gFBHistory removeLastObject];
            ALGShowFileBrowser(prev);
        };
        [back addTarget:back action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [hdr addSubview:back];
    }

    // Boton cerrar
    ALGBlockButton *cls=[ALGBlockButton buttonWithType:UIButtonTypeCustom];
    cls.frame=CGRectMake(bw-46,12,34,28);
    [cls setTitle:@"✕" forState:UIControlStateNormal];
    [cls setTitleColor:[UIColor colorWithWhite:1 alpha:0.4f] forState:UIControlStateNormal];
    cls.titleLabel.font=[UIFont systemFontOfSize:12]; cls.layer.cornerRadius=8;
    cls.backgroundColor=[UIColor colorWithWhite:1 alpha:0.08f];
    cls.actionBlock=^{
        [UIView animateWithDuration:0.2f animations:^{dim.alpha=0;}
                         completion:^(BOOL d){ww.hidden=YES;[gFBHistory removeAllObjects];for(UIView*v in [root.subviews copy])[v removeFromSuperview];}];
    };
    [cls addTarget:cls action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    [hdr addSubview:cls];

    // Linea sep
    UIView *hline=[[UIView alloc] initWithFrame:CGRectMake(0,51.5f,bw,0.5f)];
    hline.backgroundColor=[UIColor colorWithWhite:1 alpha:0.1f]; [hdr addSubview:hline];
    [browser addSubview:hdr];

    // Botones acceso rapido si es la raiz
    CGFloat listY = 52;
    if (gFBHistory.count <= 1) {
        UIView *quickRow = [[UIView alloc] initWithFrame:CGRectMake(0, listY, bw, 44)];
        NSArray *roots = @[@"/var/mobile", @"/var", @"/etc", @"/tmp"];
        CGFloat rbw = bw / roots.count;
        for (NSInteger ri=0; ri<(NSInteger)roots.count; ri++) {
            ALGBlockButton *rb=[ALGBlockButton buttonWithType:UIButtonTypeCustom];
            rb.frame=CGRectMake(ri*rbw, 4, rbw-2, 36);
            NSString *rp=roots[ri];
            [rb setTitle:[rp lastPathComponent] forState:UIControlStateNormal];
            rb.titleLabel.font=[UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
            [rb setTitleColor:[UIColor colorWithWhite:1 alpha:0.8f] forState:UIControlStateNormal];
            rb.backgroundColor=[UIColor colorWithWhite:1 alpha:0.07f]; rb.layer.cornerRadius=8;
            rb.actionBlock=^{ ALGShowFileBrowser(rp); };
            [rb addTarget:rb action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
            [quickRow addSubview:rb];
        }
        [browser addSubview:quickRow];
        listY += 46;
        UIView *ql=[[UIView alloc] initWithFrame:CGRectMake(0,listY,bw,0.5f)];
        ql.backgroundColor=[UIColor colorWithWhite:1 alpha:0.08f]; [browser addSubview:ql]; listY+=1;
    }

    // Lista de archivos
    NSError *err=nil;
    NSArray *items=[[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&err];
    if (!items) items=@[];
    items=[items sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    UIScrollView *scroll=[[UIScrollView alloc] initWithFrame:CGRectMake(0,listY,bw,bh-listY)];
    scroll.showsVerticalScrollIndicator=YES; scroll.bounces=YES;
    CGFloat rowY=0;
    for (NSString *item in items) {
        if ([item hasPrefix:@"."]) continue;
        NSString *full=[path stringByAppendingPathComponent:item];
        BOOL isDir=NO;
        [[NSFileManager defaultManager] fileExistsAtPath:full isDirectory:&isDir];
        UIView *row=ALGMakeFBRow(item, isDir, rowY, bw, full, scroll);
        [scroll addSubview:row]; rowY+=44;
    }
    if (items.count==0) {
        UILabel *empty=[[UILabel alloc] initWithFrame:CGRectMake(0,20,bw,30)];
        empty.text=err ? err.localizedDescription : @"Empty directory";
        empty.textAlignment=NSTextAlignmentCenter;
        empty.font=[UIFont systemFontOfSize:13]; empty.textColor=[UIColor colorWithWhite:1 alpha:0.3f];
        [scroll addSubview:empty];
    }
    scroll.contentSize=CGSizeMake(bw,MAX(rowY,bh-listY));
    [browser addSubview:scroll];
    [root addSubview:browser];

    browser.alpha=0; dim.alpha=0;
    browser.transform=CGAffineTransformConcat(CGAffineTransformMakeScale(0.9f,0.9f),CGAffineTransformMakeTranslation(0,20));
    [UIView animateWithDuration:0.38f delay:0 usingSpringWithDamping:0.82f initialSpringVelocity:0.4f
                        options:0 animations:^{browser.alpha=1;dim.alpha=1;browser.transform=CGAffineTransformIdentity;}
                     completion:nil];
}

// ═══════════════════════════════════════════════════════════════
// MINI TERMINAL — commands: cat, ls, find, grep, plutil, neofetch
// ═══════════════════════════════════════════════════════════════

static UIWindow *gTerminalWindow = nil;
static NSMutableArray<NSString*> *gTermHistory = nil;
static NSInteger gTermHistoryIndex = -1;

// Helpers
static NSString *gTermCWD = nil;
static NSString *ALGTermCWD(void) {
    if (!gTermCWD) gTermCWD = @"/var/mobile";
    return gTermCWD;
}

static NSString *ALGFormatPermissions(NSUInteger perms) {
    char p[10];
    p[0] = (perms & 0400) ? 'r' : '-'; p[1] = (perms & 0200) ? 'w' : '-'; p[2] = (perms & 0100) ? 'x' : '-';
    p[3] = (perms & 0040) ? 'r' : '-'; p[4] = (perms & 0020) ? 'w' : '-'; p[5] = (perms & 0010) ? 'x' : '-';
    p[6] = (perms & 0004) ? 'r' : '-'; p[7] = (perms & 0002) ? 'w' : '-'; p[8] = (perms & 0001) ? 'x' : '-';
    p[9] = 0;
    return [NSString stringWithUTF8String:p];
}

static NSString *ALGFormatSize(long long bytes) {
    if (bytes < 1024) return [NSString stringWithFormat:@"%lldB", bytes];
    if (bytes < 1024*1024) return [NSString stringWithFormat:@"%.1fK", bytes/1024.0];
    if (bytes < 1024*1024*1024) return [NSString stringWithFormat:@"%.1fM", bytes/(1024.0*1024)];
    return [NSString stringWithFormat:@"%.1fG", bytes/(1024.0*1024*1024)];
}

// ls nativo con soporte -l y -la
static NSString *ALGCmdLs(NSArray *args) {
    BOOL longFmt = NO;
    NSString *path = ALGTermCWD();
    for (NSString *arg in args) {
        if ([arg hasPrefix:@"-"]) {
            if ([arg containsString:@"l"]) longFmt = YES;
        } else {
            path = [arg hasPrefix:@"/"] ? arg : [ALGTermCWD() stringByAppendingPathComponent:arg];
        }
    }
    // Si el path es un archivo, mostrar info de ese archivo
    BOOL isDir = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
    if (!exists) return [NSString stringWithFormat:@"ls: %@: No such file or directory", path];
    if (!isDir) {
        if (!longFmt) return [path lastPathComponent];
        NSDictionary *a = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        NSString *perms = [NSString stringWithFormat:@"-%@", ALGFormatPermissions([a[NSFilePosixPermissions] unsignedIntegerValue])];
        return [NSString stringWithFormat:@"%@ %6@ %@", perms, ALGFormatSize([a[NSFileSize] longLongValue]), [path lastPathComponent]];
    }
    NSError *e = nil;
    NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&e];
    if (!items) return [NSString stringWithFormat:@"ls: %@: %@", path, e.localizedDescription ?: @"permission denied"];
    items = [items sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSMutableString *out = [NSMutableString string];
    for (NSString *item in items) {
        NSString *full = [path stringByAppendingPathComponent:item];
        BOOL isd = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:full isDirectory:&isd];
        if (longFmt) {
            NSDictionary *a = [[NSFileManager defaultManager] attributesOfItemAtPath:full error:nil];
            NSUInteger permsVal = [a[NSFilePosixPermissions] unsignedIntegerValue];
            NSString *perms = [NSString stringWithFormat:@"%@%@", isd?@"d":@"-", ALGFormatPermissions(permsVal)];
            long long sz = [a[NSFileSize] longLongValue];
            [out appendFormat:@"%@ %6@ %@%@\n", perms, ALGFormatSize(sz), item, isd?@"/":@""];
        } else {
            [out appendFormat:@"%@%@\n", item, isd?@"/":@""];
        }
    }
    return out.length ? [out substringToIndex:out.length-1] : @"(empty)";
}

// cat nativo
static NSString *ALGCmdCat(NSArray *args) {
    if (!args.count) return @"cat: missing operand";
    NSMutableString *out = [NSMutableString string];
    for (NSString *arg in args) {
        if ([arg hasPrefix:@"-"]) continue; // skip flags
        NSString *path = [arg hasPrefix:@"/"] ? arg : [ALGTermCWD() stringByAppendingPathComponent:arg];
        // Leer via NSData primero (más compatible con archivos del sistema)
        NSData *d = [NSData dataWithContentsOfFile:path];
        if (!d) {
            // Intentar con FILE* directo
            FILE *f = fopen(path.UTF8String, "r");
            if (f) {
                NSMutableData *md = [NSMutableData data];
                char buf[4096]; size_t n;
                while ((n = fread(buf, 1, sizeof(buf), f)) > 0)
                    [md appendBytes:buf length:n];
                fclose(f);
                d = md;
            }
        }
        if (!d) { [out appendFormat:@"cat: %@: permission denied\n", [path lastPathComponent]]; continue; }
        // Detectar bplist
        if (d.length > 6 && memcmp(d.bytes,"bplist",6)==0) {
            NSError *e = nil;
            id obj = [NSPropertyListSerialization propertyListWithData:d
                options:NSPropertyListMutableContainersAndLeaves format:nil error:&e];
            if (obj) {
                NSData *xml = [NSPropertyListSerialization dataWithPropertyList:obj
                    format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
                NSString *s = [[NSString alloc] initWithData:xml encoding:NSUTF8StringEncoding];
                if (s) { [out appendString:s]; continue; }
            }
        }
        NSString *txt = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
        if (!txt) txt = [[NSString alloc] initWithData:d encoding:NSISOLatin1StringEncoding];
        if (txt) [out appendString:txt];
        else [out appendFormat:@"cat: %@: binary file\n", [path lastPathComponent]];
    }
    return out;
}

// find nativo
static NSString *ALGCmdFind(NSArray *args) {
    NSString *root = args.count > 0 ? args[0] : ALGTermCWD();
    if (![root hasPrefix:@"/"]) root = [ALGTermCWD() stringByAppendingPathComponent:root];

    NSString *namePattern = nil;
    BOOL caseInsensitive = NO;
    NSString *typeFilter = nil; // "f" = file, "d" = dir

    for (NSInteger i = 1; i < (NSInteger)args.count - 1; i++) {
        if ([args[i] isEqualToString:@"-name"]) {
            namePattern = args[i+1];
            caseInsensitive = NO;
        } else if ([args[i] isEqualToString:@"-iname"]) {
            namePattern = args[i+1];
            caseInsensitive = YES;
        } else if ([args[i] isEqualToString:@"-type"] && i+1 < (NSInteger)args.count) {
            typeFilter = args[i+1];
        }
    }
    // Quitar comillas del patron si las tiene
    if ([namePattern hasPrefix:@"'"] && [namePattern hasSuffix:@"'"])
        namePattern = [namePattern substringWithRange:NSMakeRange(1, namePattern.length-2)];
    if ([namePattern hasPrefix:@"""] && [namePattern hasSuffix:@"""])
        namePattern = [namePattern substringWithRange:NSMakeRange(1, namePattern.length-2)];

    NSMutableString *out = [NSMutableString string];
    NSDirectoryEnumerator *en = [[NSFileManager defaultManager] enumeratorAtPath:root];
    NSInteger count = 0;

    for (NSString *item in en) {
        // Limitar resultados
        if (count > 500) { [out appendString:@"... (too many results, limit 500)"]; break; }

        NSString *full = [root stringByAppendingPathComponent:item];
        NSString *fname = [item lastPathComponent];

        // Filtro por tipo
        if (typeFilter) {
            BOOL isDir = NO;
            [[NSFileManager defaultManager] fileExistsAtPath:full isDirectory:&isDir];
            if ([typeFilter isEqualToString:@"f"] && isDir) continue;
            if ([typeFilter isEqualToString:@"d"] && !isDir) continue;
        }

        // Filtro por nombre
        if (namePattern) {
            NSPredicate *pred = [NSPredicate predicateWithFormat:
                caseInsensitive ? @"SELF LIKE[c] %@" : @"SELF LIKE %@", namePattern];
            if (![pred evaluateWithObject:fname]) continue;
        }

        [out appendFormat:@"%@\n", full];
        count++;
    }
    return out.length ? [out substringToIndex:out.length-1] : @"(no results)";
}

// grep nativo
static NSString *ALGCmdGrep(NSArray *args) {
    if (args.count < 2) return @"grep: usage: grep <pattern> <file>";
    NSString *pattern = args[0];
    NSString *path = [args[1] hasPrefix:@"/"] ? args[1] : [ALGTermCWD() stringByAppendingPathComponent:args[1]];
    NSError *e = nil;
    NSString *txt = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&e];
    if (!txt) return [NSString stringWithFormat:@"grep: %@", e.localizedDescription ?: @"error"];
    NSMutableString *out = [NSMutableString string];
    for (NSString *line in [txt componentsSeparatedByString:@"\n"]) {
        NSRange r = [line rangeOfString:pattern options:NSCaseInsensitiveSearch];
        if (r.location != NSNotFound) [out appendFormat:@"%@\n", line];
    }
    return out.length ? [out substringToIndex:out.length-1] : @"(no matches)";
}

// ps nativo
static NSString *ALGCmdPs(void) {
    NSMutableString *out = [NSMutableString stringWithString:@"PID    NAME\n"];
    [out appendFormat:@"%-6d %@\n", [NSProcessInfo processInfo].processIdentifier,
        [NSProcessInfo processInfo].processName];
    return out;
}

// env nativo
static NSString *ALGCmdEnv(void) {
    NSDictionary *env = [[NSProcessInfo processInfo] environment];
    NSMutableString *out = [NSMutableString string];
    for (NSString *k in [env.allKeys sortedArrayUsingSelector:@selector(compare:)])
        [out appendFormat:@"%@=%@\n", k, env[k]];
    return out.length ? [out substringToIndex:out.length-1] : @"(empty)";
}

// stat/info de archivo
static NSString *ALGCmdStat(NSArray *args) {
    if (!args.count) return @"stat: missing operand";
    NSString *path = [args[0] hasPrefix:@"/"] ? args[0] : [ALGTermCWD() stringByAppendingPathComponent:args[0]];
    NSError *e = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&e];
    if (!attrs) return [NSString stringWithFormat:@"stat: %@", e.localizedDescription ?: @"error"];
    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"File: %@\n", path];
    [out appendFormat:@"Size: %@\n", attrs[NSFileSize]];
    [out appendFormat:@"Type: %@\n", attrs[NSFileType]];
    [out appendFormat:@"Modified: %@\n", attrs[NSFileModificationDate]];
    [out appendFormat:@"Owner: %@ (uid:%@)\n", attrs[NSFileOwnerAccountName] ?: @"?", attrs[NSFileOwnerAccountID] ?: @"?"];
    [out appendFormat:@"Perms: %@", attrs[NSFilePosixPermissions]];
    return out;
}

// uname
static NSString *ALGCmdUname(void) {
    return [NSString stringWithFormat:@"Darwin %@ %@ %@",
        [[UIDevice currentDevice] systemVersion],
        [[UIDevice currentDevice] model],
        [[UIDevice currentDevice] identifierForVendor].UUIDString ?: @"unknown"];
}

// df
static NSString *ALGCmdDf(void) {
    NSError *e = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:@"/var/mobile" error:&e];
    if (!attrs) return @"df: error";
    long long total = [attrs[NSFileSystemSize] longLongValue];
    long long free  = [attrs[NSFileSystemFreeSize] longLongValue];
    long long used  = total - free;
    return [NSString stringWithFormat:
        @"Filesystem      Size    Used    Free\n/var/mobile  %4.1fGB  %4.1fGB  %4.1fGB",
        total/1e9, used/1e9, free/1e9];
}

// echo
static NSString *ALGCmdEcho(NSArray *args) {
    return [args componentsJoinedByString:@" "];
}

// head/tail
static NSString *ALGCmdHead(NSArray *args, BOOL tail) {
    NSInteger n = 10;
    NSString *path = nil;
    for (NSInteger i=0; i<(NSInteger)args.count; i++) {
        if ([args[i] hasPrefix:@"-"]) n = [[args[i] substringFromIndex:1] integerValue] ?: 10;
        else path = args[i];
    }
    if (!path) return tail ? @"tail: missing file" : @"head: missing file";
    if (![path hasPrefix:@"/"]) path = [ALGTermCWD() stringByAppendingPathComponent:path];
    NSError *e = nil;
    NSString *txt = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&e];
    if (!txt) return [NSString stringWithFormat:@"%@: %@", tail?@"tail":@"head", e.localizedDescription];
    NSArray *lines = [txt componentsSeparatedByString:@"\n"];
    NSArray *slice = tail
        ? [lines subarrayWithRange:NSMakeRange(MAX(0,(NSInteger)lines.count-n), MIN(n,(NSInteger)lines.count))]
        : [lines subarrayWithRange:NSMakeRange(0, MIN(n,(NSInteger)lines.count))];
    return [slice componentsJoinedByString:@"\n"];
}

// mkdir / touch / rm
static NSString *ALGCmdMkdir(NSString *arg) {
    NSString *path = [arg hasPrefix:@"/"] ? arg : [ALGTermCWD() stringByAppendingPathComponent:arg];
    NSError *e = nil;
    BOOL ok = [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&e];
    return ok ? [NSString stringWithFormat:@"mkdir: created %@", path]
              : [NSString stringWithFormat:@"mkdir: %@", e.localizedDescription];
}
static NSString *ALGCmdTouch(NSString *arg) {
    NSString *path = [arg hasPrefix:@"/"] ? arg : [ALGTermCWD() stringByAppendingPathComponent:arg];
    BOOL ok = [[NSFileManager defaultManager] createFileAtPath:path contents:[NSData data] attributes:nil];
    return ok ? [NSString stringWithFormat:@"touch: created %@", path] : @"touch: error";
}
static NSString *ALGCmdRm(NSArray *args) {
    if (!args.count) return @"rm: missing operand";
    NSString *path = [args[0] hasPrefix:@"/"] ? args[0] : [ALGTermCWD() stringByAppendingPathComponent:args[0]];
    NSError *e = nil;
    BOOL ok = [[NSFileManager defaultManager] removeItemAtPath:path error:&e];
    return ok ? [NSString stringWithFormat:@"rm: removed %@", path]
              : [NSString stringWithFormat:@"rm: %@", e.localizedDescription];
}

// neofetch estilo
static NSString *ALGCmdNeofetch(void) {
    UIDevice *dev = [UIDevice currentDevice];
    [dev setBatteryMonitoringEnabled:YES];
    NSString *bat = dev.batteryLevel >= 0 ? [NSString stringWithFormat:@"%.0f%%", dev.batteryLevel*100] : @"N/A";
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:@"/var/mobile" error:nil];
    double totalGB = [attrs[NSFileSystemSize] doubleValue]/1e9;
    double freeGB  = [attrs[NSFileSystemFreeSize] doubleValue]/1e9;
    return [NSString stringWithFormat:
        @"       _\n"
        @"      | |    %@ @ %@\n"
        @"   ___| |_   ----------------\n"
        @"  / _ \\ __|  OS:      iOS %@\n"
        @" | (_) |\\__  Model:   %@\n"
        @"  \\___/      RAM:     %.0fGB\n"
        @"             Disk:    %.1f/%.1fGB\n"
        @"             Battery: %@\n"
        @"             PID:     %d",
        [NSProcessInfo processInfo].processName,
        dev.name,
        dev.systemVersion,
        dev.model,
        [NSProcessInfo processInfo].physicalMemory / 1073741824.0,
        totalGB - freeGB, totalGB,
        bat,
        [NSProcessInfo processInfo].processIdentifier
    ];
}

// Dispatcher principal
static NSString *ALGRunCommand(NSString *cmd) {
    if (!cmd.length) return @"";
    cmd = [cmd stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    // Parsear args respetando comillas simples
    NSMutableArray *parts = [NSMutableArray array];
    NSMutableString *cur = [NSMutableString string];
    BOOL inQuote = NO;
    for (NSUInteger i=0; i<cmd.length; i++) {
        unichar c = [cmd characterAtIndex:i];
        if (c == '\'' ) { inQuote = !inQuote; }
        else if (c == ' ' && !inQuote) {
            if (cur.length) { [parts addObject:[cur copy]]; [cur setString:@""]; }
        } else { [cur appendFormat:@"%C", c]; }
    }
    if (cur.length) [parts addObject:[cur copy]];
    if (!parts.count) return @"";

    NSString *prog = [parts[0] lowercaseString];
    NSArray *args = parts.count > 1 ? [parts subarrayWithRange:NSMakeRange(1, parts.count-1)] : @[];

    if ([prog isEqualToString:@"clear"]) return @"";
    if ([prog isEqualToString:@"pwd"]) return ALGTermCWD();
    if ([prog isEqualToString:@"cd"]) {
        NSString *path = args.count ? args[0] : @"/var/mobile";
        if ([path isEqualToString:@"~"]) path = @"/var/mobile";
        if ([path isEqualToString:@".."]) path = [ALGTermCWD() stringByDeletingLastPathComponent];
        if (![path hasPrefix:@"/"]) path = [ALGTermCWD() stringByAppendingPathComponent:path];
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir) {
            gTermCWD = path;
            return [NSString stringWithFormat:@"-> %@", path];
        }
        return [NSString stringWithFormat:@"cd: %@: no such directory", path];
    }
    if ([prog isEqualToString:@"ls"])     return ALGCmdLs(args);
    if ([prog isEqualToString:@"cat"])    return ALGCmdCat(args);
    if ([prog isEqualToString:@"find"])   return ALGCmdFind(args);
    if ([prog isEqualToString:@"grep"])   return ALGCmdGrep(args);
    if ([prog isEqualToString:@"echo"])   return ALGCmdEcho(args);
    if ([prog isEqualToString:@"ps"])     return ALGCmdPs();
    if ([prog isEqualToString:@"env"] || [prog isEqualToString:@"printenv"]) return ALGCmdEnv();
    if ([prog isEqualToString:@"stat"])   return ALGCmdStat(args);
    if ([prog isEqualToString:@"uname"])  return ALGCmdUname();
    if ([prog isEqualToString:@"df"])     return ALGCmdDf();
    if ([prog isEqualToString:@"head"])   return ALGCmdHead(args, NO);
    if ([prog isEqualToString:@"tail"])   return ALGCmdHead(args, YES);
    if ([prog isEqualToString:@"mkdir"])  return args.count ? ALGCmdMkdir(args[0]) : @"mkdir: missing operand";
    if ([prog isEqualToString:@"touch"])  return args.count ? ALGCmdTouch(args[0]) : @"touch: missing operand";
    if ([prog isEqualToString:@"rm"])     return ALGCmdRm(args);
    if ([prog isEqualToString:@"date"])   return [[NSDate date] description];
    if ([prog isEqualToString:@"whoami"]) return @"mobile";
    if ([prog isEqualToString:@"id"])     return [NSString stringWithFormat:@"uid=%d(mobile)", getuid()];
    if ([prog isEqualToString:@"neofetch"]) return ALGCmdNeofetch();
    if ([prog isEqualToString:@"help"])
        return @"Commands: ls cd cat find grep echo ps env stat uname df\n          head tail mkdir touch rm date whoami id neofetch\n          clear pwd\nSave: tap Save button";
    return [NSString stringWithFormat:@"%@: command not found", prog];
}

static void ALGTerminalAppendOutput(UITextView *tv, NSString *line, UIColor *color) {
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc]
        initWithAttributedString:tv.attributedText];
    if (attr.length > 0) [attr appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    UIFont *font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    [attr appendAttributedString:[[NSAttributedString alloc]
        initWithString:line attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: color}]];
    tv.attributedText = attr;
    // Scroll al final
    dispatch_async(dispatch_get_main_queue(), ^{
        NSRange r = NSMakeRange(attr.length > 0 ? attr.length-1 : 0, 0);
        [tv scrollRangeToVisible:r];
    });
}

static void ALGShowTerminal(void) {
    if (!gTermHistory) gTermHistory = [NSMutableArray array];

    if (!gTerminalWindow) {
        UIWindowScene *scene = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if ([s isKindOfClass:[UIWindowScene class]]) { scene=(UIWindowScene*)s; break; }
        if (@available(iOS 13.0,*))
            gTerminalWindow = [[UIWindow alloc] initWithWindowScene:scene];
        else
            gTerminalWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        gTerminalWindow.windowLevel = UIWindowLevelAlert + 650;
        gTerminalWindow.backgroundColor = [UIColor clearColor];
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        gTerminalWindow.rootViewController = vc;
    }
    gTerminalWindow.frame = [UIScreen mainScreen].bounds;
    gTerminalWindow.rootViewController.view.frame = [UIScreen mainScreen].bounds;
    gTerminalWindow.hidden = NO;
    gTerminalWindow.userInteractionEnabled = YES;
    UIView *root = gTerminalWindow.rootViewController.view;
    for (UIView *v in [root.subviews copy]) [v removeFromSuperview];

    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    CGFloat sh = [UIScreen mainScreen].bounds.size.height;
    CGFloat tw = sw - 16;
    CGFloat th = sh * 0.65f;
    CGFloat tx = 8;
    // Posicion inicial: parte inferior de la pantalla
    CGFloat ty = sh - th - 8;

    // Dim bg
    UIControl *dim = [[UIControl alloc] initWithFrame:[UIScreen mainScreen].bounds];
    dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5f];
    dim.alpha = 0;
    __weak UIWindow *ww = gTerminalWindow;
    ALGBlockButton *dimBtn = [ALGBlockButton buttonWithType:UIButtonTypeCustom];
    dimBtn.frame = dim.bounds;
    dimBtn.actionBlock = ^{
        [ww endEditing:YES];
        id ks = objc_getAssociatedObject(ww, "kbShow");
        id kh = objc_getAssociatedObject(ww, "kbHide");
        if (ks) [[NSNotificationCenter defaultCenter] removeObserver:ks];
        if (kh) [[NSNotificationCenter defaultCenter] removeObserver:kh];
        [UIView animateWithDuration:0.2f animations:^{ dim.alpha=0; }
                         completion:^(BOOL d){ ww.hidden=YES; for(UIView*v in [root.subviews copy])[v removeFromSuperview]; }];
    };
    UIView *term = [[UIView alloc] initWithFrame:CGRectMake(tx,ty,tw,th)];
    term.layer.cornerRadius = 20;
    if (@available(iOS 13.0,*)) term.layer.cornerCurve = kCACornerCurveContinuous;
    term.clipsToBounds = YES;

    // Blur + tint verde oscuro
    UIBlurEffect *blr;
    if (@available(iOS 13.0,*)) blr = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    else blr = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *tbv = [[UIVisualEffectView alloc] initWithEffect:blr];
    tbv.frame = CGRectMake(0,0,tw,th); tbv.userInteractionEnabled = NO; [term addSubview:tbv];
    UIView *ttint = [[UIView alloc] initWithFrame:CGRectMake(0,0,tw,th)];
    ttint.backgroundColor = [UIColor colorWithRed:0.02f green:0.07f blue:0.02f alpha:0.82f];
    ttint.userInteractionEnabled = NO; [term addSubview:ttint];

    // Borde verde glass
    CAGradientLayer *tbrd = [CAGradientLayer layer];
    tbrd.frame = CGRectMake(0,0,tw,th);
    tbrd.colors = @[(id)[UIColor colorWithRed:0.2f green:0.9f blue:0.3f alpha:0.35f].CGColor,
                    (id)[UIColor colorWithRed:0.1f green:0.5f blue:0.15f alpha:0.08f].CGColor];
    tbrd.locations = @[@0, @1];
    tbrd.startPoint = CGPointMake(0.5f,0); tbrd.endPoint = CGPointMake(0.5f,1);
    CAShapeLayer *tbm = [CAShapeLayer layer];
    UIBezierPath *tbo = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0,0,tw,th) cornerRadius:20];
    UIBezierPath *tbi = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(CGRectMake(0,0,tw,th),0.6f,0.6f) cornerRadius:19.4f];
    [tbo appendPath:tbi]; tbo.usesEvenOddFillRule = YES;
    tbm.path = tbo.CGPath; tbm.fillRule = kCAFillRuleEvenOdd;
    tbrd.mask = tbm; [term.layer addSublayer:tbrd];

    // Header
    UIView *thdr = [[UIView alloc] initWithFrame:CGRectMake(0,0,tw,40)];
    thdr.backgroundColor = [UIColor colorWithRed:0.02f green:0.1f blue:0.02f alpha:0.6f];
    // Tres bolitas macOS — rojo=cerrar, amarillo y verde decorativos
    CGFloat dotX = 12;
    NSArray *dotColors2 = @[[UIColor colorWithRed:0.94f green:0.35f blue:0.35f alpha:1],
                            [UIColor colorWithRed:0.98f green:0.75f blue:0.22f alpha:1],
                            [UIColor colorWithRed:0.28f green:0.78f blue:0.28f alpha:1]];
    for (NSInteger di=0; di<3; di++) {
        ALGBlockButton *dot = [ALGBlockButton buttonWithType:UIButtonTypeCustom];
        dot.frame = CGRectMake(dotX+di*20, 14, 12, 12);
        dot.backgroundColor = dotColors2[di];
        dot.layer.cornerRadius = 6;
        if (di == 0) {
            // Rojo = cerrar
            dot.actionBlock = ^{
                [ww endEditing:YES];
                id ks = objc_getAssociatedObject(ww, "kbShow");
                id kh = objc_getAssociatedObject(ww, "kbHide");
                if (ks) [[NSNotificationCenter defaultCenter] removeObserver:ks];
                if (kh) [[NSNotificationCenter defaultCenter] removeObserver:kh];
                [UIView animateWithDuration:0.25f animations:^{
                    dim.alpha = 0;
                    term.transform = CGAffineTransformMakeScale(0.85f,0.85f);
                    term.alpha = 0;
                } completion:^(BOOL d2){
                    ww.hidden = YES;
                    term.transform = CGAffineTransformIdentity;
                    term.alpha = 1;
                    for (UIView *v in [root.subviews copy]) [v removeFromSuperview];
                }];
            };
        }
        [dot addTarget:dot action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [thdr addSubview:dot];
    }

    UILabel *ttitle = [[UILabel alloc] initWithFrame:CGRectMake(0,0,tw,40)];
    ttitle.text = @"Terminal";
    ttitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    ttitle.textColor = [UIColor colorWithWhite:1 alpha:0.4f];
    ttitle.textAlignment = NSTextAlignmentCenter; ttitle.userInteractionEnabled = NO;
    [thdr addSubview:ttitle];

    // Save log — esquina derecha
    ALGBlockButton *tsave = [ALGBlockButton buttonWithType:UIButtonTypeCustom];
    tsave.frame = CGRectMake(tw-52,6,44,28);
    tsave.backgroundColor = [UIColor colorWithRed:0.1f green:0.4f blue:0.15f alpha:0.8f];
    tsave.layer.cornerRadius = 6;
    [tsave setTitle:@"Save" forState:UIControlStateNormal];
    [tsave setTitleColor:[UIColor colorWithRed:0.4f green:1 blue:0.5f alpha:1] forState:UIControlStateNormal];
    tsave.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    [thdr addSubview:tsave];
    // Sep
    UIView *tsep = [[UIView alloc] initWithFrame:CGRectMake(0,39.5f,tw,0.5f)];
    tsep.backgroundColor = [UIColor colorWithRed:0.2f green:0.6f blue:0.2f alpha:0.3f];
    [thdr addSubview:tsep];
    [term addSubview:thdr];

    // Pan gesture en header para mover la terminal libremente
    ALGBlockButton *panProxy2 = [ALGBlockButton new];
    __block UIPanGestureRecognizer *termPan = nil;
    __weak UIView *wTerm = term;
    panProxy2.actionBlock = ^{
        UIView *t = wTerm; if (!t || !termPan) return;
        CGPoint d = [termPan translationInView:root];
        CGRect f = t.frame;
        f.origin.x = MAX(0, MIN(f.origin.x+d.x, sw-f.size.width));
        f.origin.y = MAX(20, MIN(f.origin.y+d.y, sh-f.size.height-20));
        t.frame = f;
        [termPan setTranslation:CGPointZero inView:root];
    };
    termPan = [[UIPanGestureRecognizer alloc] initWithTarget:panProxy2 action:@selector(handleTap)];
    objc_setAssociatedObject(thdr,"panProxy",panProxy2,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [thdr addGestureRecognizer:termPan];
    thdr.userInteractionEnabled = YES;

    // Output TextView (no editable)
    CGFloat inputH = 44;
    __block UITextView *outputTV = [[UITextView alloc] initWithFrame:CGRectMake(0,40,tw,th-40-inputH)];
    outputTV.backgroundColor = [UIColor clearColor];
    outputTV.editable = NO;
    outputTV.selectable = YES;
    outputTV.attributedText = [[NSAttributedString alloc] initWithString:@""];
    [term addSubview:outputTV];

    // Welcome
    UIFont *monoFont = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    ALGTerminalAppendOutput(outputTV, @"TweaksLoader Terminal - SpringBoard shell\nType 'help' for commands\n",
        [UIColor colorWithRed:0.3f green:1 blue:0.4f alpha:0.7f]);

    // Save log action
    __weak UITextView *wTV = outputTV;
    tsave.actionBlock = ^{
        NSString *log = wTV.text ?: @"";
        NSString *path = @"/var/mobile/Media/TweaksLoader_terminal.log";
        [log writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        ALGTerminalAppendOutput(wTV, [NSString stringWithFormat:@"Log saved to %@", path],
            [UIColor colorWithRed:0.5f green:1 blue:0.6f alpha:0.9f]);
    };
    [tsave addTarget:tsave action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];

    // Input bar
    UIView *inputBar = [[UIView alloc] initWithFrame:CGRectMake(0,th-inputH,tw,inputH)];
    inputBar.backgroundColor = [UIColor colorWithRed:0.02f green:0.1f blue:0.02f alpha:0.7f];
    UIView *iSep = [[UIView alloc] initWithFrame:CGRectMake(0,0,tw,0.5f)];
    iSep.backgroundColor = [UIColor colorWithRed:0.2f green:0.6f blue:0.2f alpha:0.3f];
    [inputBar addSubview:iSep];
    // Prompt label
    UILabel *prompt = [[UILabel alloc] initWithFrame:CGRectMake(10,10,30,24)];
    prompt.text = @"$";
    prompt.font = monoFont;
    prompt.textColor = [UIColor colorWithRed:0.3f green:1 blue:0.4f alpha:0.9f];
    [inputBar addSubview:prompt];
    // Input field
    UITextField *inputField = [[UITextField alloc] initWithFrame:CGRectMake(32,6,tw-86,32)];
    inputField.backgroundColor = [UIColor clearColor];
    inputField.textColor = [UIColor whiteColor];
    inputField.font = monoFont;
    inputField.keyboardAppearance = UIKeyboardAppearanceDark;
    inputField.autocorrectionType = UITextAutocorrectionTypeNo;
    inputField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    inputField.returnKeyType = UIReturnKeySend;
    inputField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:@"enter command..."
            attributes:@{NSForegroundColorAttributeName:[UIColor colorWithWhite:1 alpha:0.2f],
                         NSFontAttributeName: monoFont}];
    [inputBar addSubview:inputField];
    // Run button
    ALGBlockButton *runBtn = [ALGBlockButton buttonWithType:UIButtonTypeCustom];
    runBtn.frame = CGRectMake(tw-50,6,44,32);
    runBtn.backgroundColor = [UIColor colorWithRed:0.1f green:0.5f blue:0.15f alpha:0.85f];
    runBtn.layer.cornerRadius = 8;
    [runBtn setTitle:@"Run" forState:UIControlStateNormal];
    [runBtn setTitleColor:[UIColor colorWithRed:0.4f green:1 blue:0.5f alpha:1] forState:UIControlStateNormal];
    runBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    [inputBar addSubview:runBtn];
    [term addSubview:inputBar];

    // Ejecutar comando
    __weak UITextField *wField = inputField;
    __weak UITextView *wOut = outputTV;
    void (^execCmd)(void) = ^{
        NSString *cmd = [wField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (!cmd.length) return;
        // Guardar en historial
        [gTermHistory insertObject:cmd atIndex:0];
        if (gTermHistory.count > 50) [gTermHistory removeLastObject];
        gTermHistoryIndex = -1;
        wField.text = @"";

        // Mostrar el comando
        NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
        NSString *promptLine = [NSString stringWithFormat:@"%@$ %@",
            [cwd lastPathComponent], cmd];
        ALGTerminalAppendOutput(wOut, promptLine,
            [UIColor colorWithRed:0.4f green:0.9f blue:0.4f alpha:0.9f]);

        // Comando help builtin
        if ([cmd isEqualToString:@"help"]) {
            ALGTerminalAppendOutput(wOut, @"Commands: ls cat find grep plutil echo ps uname id whoami\n         date df du head tail wc sort uniq env which file\n         stat chmod cp mv rm mkdir touch bash sh cd pwd clear\n         neofetch\nSave: tap Save button",
                [UIColor colorWithRed:0.6f green:0.8f blue:1 alpha:0.9f]);
            return;
        }

        // Ejecutar en background
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
            NSString *out = ALGRunCommand(cmd);
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([out isEqualToString:@""]) {
                    // clear
                    wOut.attributedText = [[NSAttributedString alloc] initWithString:@""];
                } else {
                    ALGTerminalAppendOutput(wOut, out,
                        [UIColor colorWithRed:0.85f green:0.95f blue:0.85f alpha:0.95f]);
                }
            });
        });
    };

    runBtn.actionBlock = execCmd;
    [runBtn addTarget:runBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];

    // Return key = run
    objc_setAssociatedObject(inputField, "execBlock",
        [execCmd copy], OBJC_ASSOCIATION_COPY_NONATOMIC);

    [root addSubview:term];

    // Observer del teclado — subir/bajar la terminal
    id __block kbShow = [[NSNotificationCenter defaultCenter]
        addObserverForName:UIKeyboardWillShowNotification object:nil
        queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        CGRect kbFrame = [n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
        CGFloat kbH = kbFrame.size.height;
        CGFloat dur = [n.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
        NSInteger curve = [n.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
        [UIView animateWithDuration:dur delay:0
                            options:(curve << 16)|UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            term.frame = CGRectMake(tx, sh - kbH - th - 4, tw, th);
        } completion:nil];
    }];
    id __block kbHide = [[NSNotificationCenter defaultCenter]
        addObserverForName:UIKeyboardWillHideNotification object:nil
        queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        CGFloat dur = [n.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
        [UIView animateWithDuration:dur animations:^{
            term.frame = CGRectMake(tx, ty, tw, th);
        }];
    }];
    // Limpiar observers al cerrar
    objc_setAssociatedObject(gTerminalWindow, "kbShow", kbShow, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(gTerminalWindow, "kbHide", kbHide, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Animacion entrada desde abajo
    term.transform = CGAffineTransformMakeTranslation(0, th);
    dim.alpha = 0;
    [UIView animateWithDuration:0.4f delay:0 usingSpringWithDamping:0.85f initialSpringVelocity:0.4f
                        options:0 animations:^{ term.transform=CGAffineTransformIdentity; dim.alpha=1; }
                     completion:^(BOOL d){ [inputField becomeFirstResponder]; }];
}

// ═══════════════════════════════════════════════════════════════
// MOBILEGESTALT EDITOR
// ═══════════════════════════════════════════════════════════════

static UIWindow *gGestaltWindow = nil;

static NSDictionary *ALGLoadGestaltPlist(void) {
    NSData *d = [NSData dataWithContentsOfFile:GESTALT_PLIST];
    if (!d) {
        // Fallback FILE*
        FILE *f = fopen(GESTALT_PLIST.UTF8String, "rb");
        if (f) {
            NSMutableData *md = [NSMutableData data];
            char buf[4096]; size_t n;
            while ((n = fread(buf,1,sizeof(buf),f)) > 0) [md appendBytes:buf length:n];
            fclose(f);
            d = md;
        }
    }
    if (!d) { NSLog(@"[TweaksLoader] Gestalt: cannot read plist"); return nil; }
    NSError *e = nil;
    id obj = [NSPropertyListSerialization propertyListWithData:d
                 options:NSPropertyListMutableContainersAndLeaves format:nil error:&e];
    NSLog(@"[TweaksLoader] Gestalt load: %@ keys, error: %@",
        [obj isKindOfClass:[NSDictionary class]] ? @(((NSDictionary*)obj).count) : @"nil", e);
    return [obj isKindOfClass:[NSDictionary class]] ? obj : nil;
}

static BOOL ALGSaveGestaltPlist(NSDictionary *dict) {
    NSError *e = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict
                        format:NSPropertyListBinaryFormat_v1_0 options:0 error:&e];
    if (!data) {
        NSLog(@"[TweaksLoader] serialize error: %@", e);
        return NO;
    }
    NSString *path = ALGGestaltPath();
    NSLog(@"[TweaksLoader] Writing %lu bytes to: %@", (unsigned long)data.length, path);

    // Quitar flag immutable antes de escribir
    ALGGestaltUnlock();

    // Metodo 1: writeToFile directo
    BOOL ok = [data writeToFile:path options:0 error:&e];
    NSLog(@"[TweaksLoader] writeToFile: %d error: %@", (int)ok, e);

    if (!ok) {
        // Metodo 2: POSIX fd
        int fd = open(path.UTF8String, O_WRONLY|O_CREAT|O_TRUNC, 0644);
        NSLog(@"[TweaksLoader] fd: %d errno: %d", fd, errno);
        if (fd >= 0) {
            ssize_t w = write(fd, data.bytes, data.length);
            close(fd);
            ok = (w == (ssize_t)data.length);
        }
    }

    if (!ok) {
        // Metodo 3: escribir a tmp y usar replaceItemAtURL que maneja flags
        NSString *tmpPath = @"/var/mobile/Media/TweaksLoader_MobileGestalt_tmp.plist";
        BOOL tmpOk = [data writeToFile:tmpPath options:0 error:&e];
        NSLog(@"[TweaksLoader] tmp write: %d err: %@", (int)tmpOk, e);
        if (tmpOk) {
            NSURL *dstURL = [NSURL fileURLWithPath:path];
            NSURL *srcURL = [NSURL fileURLWithPath:tmpPath];
            NSURL *resultURL = nil;
            NSError *replErr = nil;
            ok = [[NSFileManager defaultManager]
                replaceItemAtURL:dstURL
                   withItemAtURL:srcURL
                  backupItemName:nil
                         options:NSFileManagerItemReplacementUsingNewMetadataOnly
                resultingItemURL:&resultURL
                           error:&replErr];
            NSLog(@"[TweaksLoader] replaceItemAtURL: %d err: %@", (int)ok, replErr);
            // Limpiar tmp
            [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
        }
    }

    if (!ok) {
        // Metodo 4: rename() — atomico a nivel kernel, puede pasar por encima del flag
        NSString *tmpPath2 = @"/var/mobile/Media/TweaksLoader_MobileGestalt_rename.plist";
        BOOL tmpOk2 = [data writeToFile:tmpPath2 options:0 error:nil];
        if (tmpOk2) {
            int r = rename(tmpPath2.UTF8String, path.UTF8String);
            ok = (r == 0);
            NSLog(@"[TweaksLoader] rename: %d errno: %d", r, errno);
            if (!ok) [[NSFileManager defaultManager] removeItemAtPath:tmpPath2 error:nil];
        }
    }

    if (!ok) {
        // Guardar modified para referencia
        NSString *modPath = @"/var/mobile/Media/TweaksLoader_MobileGestalt_modified.plist";
        [data writeToFile:modPath options:0 error:nil];
        NSLog(@"[TweaksLoader] Saved modified to: %@", modPath);
    }

    if (ok) ALGGestaltLock();
    NSLog(@"[TweaksLoader] === FINAL SAVE RESULT: %d ===", (int)ok);
    return ok;
}

static void ALGBackupGestalt(void) {
    if ([[NSFileManager defaultManager] fileExistsAtPath:GESTALT_BACKUP]) {
        NSLog(@"[TweaksLoader] Backup already exists at %@", GESTALT_BACKUP);
        return;
    }
    NSData *d = [NSData dataWithContentsOfFile:GESTALT_PLIST];
    if (!d) { NSLog(@"[TweaksLoader] Backup: cannot read source plist"); return; }
    NSError *e = nil;
    BOOL ok = [d writeToFile:GESTALT_BACKUP options:0 error:&e];
    NSLog(@"[TweaksLoader] Backup result: %d path: %@ error: %@", (int)ok, GESTALT_BACKUP, e);
}

static BOOL ALGRestoreGestalt(void) {
    NSString *backupPath = GESTALT_BACKUP;
    NSString *destPath = ALGGestaltPath();
    NSLog(@"[TweaksLoader:Restore] === RESTORE TAPPED ===");
    NSLog(@"[TweaksLoader:Restore] backup path: %@", backupPath);
    NSLog(@"[TweaksLoader:Restore] dest path: %@", destPath);

    BOOL backupExists = [[NSFileManager defaultManager] fileExistsAtPath:backupPath];
    NSLog(@"[TweaksLoader:Restore] backup exists: %d", (int)backupExists);
    if (!backupExists) {
        NSLog(@"[TweaksLoader:Restore] ERROR: no backup found");
        return NO;
    }

    // Leer backup
    NSData *backupData = [NSData dataWithContentsOfFile:backupPath];
    NSLog(@"[TweaksLoader:Restore] backup size: %lu bytes", (unsigned long)backupData.length);
    if (!backupData) {
        NSLog(@"[TweaksLoader:Restore] ERROR: cannot read backup");
        return NO;
    }

    // Quitar immutable flag
    ALGGestaltUnlock();

    // Eliminar plist actual
    NSError *rmErr = nil;
    [[NSFileManager defaultManager] removeItemAtPath:destPath error:&rmErr];
    NSLog(@"[TweaksLoader:Restore] remove current: err=%@", rmErr);

    // Metodo 1: writeToFile
    NSError *writeErr = nil;
    BOOL ok = [backupData writeToFile:destPath options:0 error:&writeErr];
    NSLog(@"[TweaksLoader:Restore] writeToFile: %d err: %@", (int)ok, writeErr);

    if (!ok) {
        // Metodo 2: POSIX fd
        int fd = open(destPath.UTF8String, O_WRONLY|O_CREAT|O_TRUNC, 0644);
        NSLog(@"[TweaksLoader:Restore] fd: %d errno: %d", fd, errno);
        if (fd >= 0) {
            ssize_t written = write(fd, backupData.bytes, backupData.length);
            close(fd);
            ok = (written == (ssize_t)backupData.length);
        }
    }

    if (!ok) {
        // Metodo 3: rename — copia backup a tmp en mismo volumen y rename
        NSString *tmpR = @"/var/mobile/Media/TweaksLoader_restore_tmp.plist";
        BOOL tmpOk = [backupData writeToFile:tmpR options:0 error:nil];
        if (tmpOk) {
            int r = rename(tmpR.UTF8String, destPath.UTF8String);
            ok = (r == 0);
            NSLog(@"[TweaksLoader:Restore] rename: %d errno: %d", r, errno);
            if (!ok) [[NSFileManager defaultManager] removeItemAtPath:tmpR error:nil];
        }
    }

    if (!ok) {
        // Metodo 4: replaceItemAtURL
        NSString *tmpR2 = @"/var/mobile/Media/TweaksLoader_restore_tmp2.plist";
        BOOL tmpOk2 = [backupData writeToFile:tmpR2 options:0 error:nil];
        if (tmpOk2) {
            NSError *repErr = nil;
            ok = [[NSFileManager defaultManager]
                replaceItemAtURL:[NSURL fileURLWithPath:destPath]
                   withItemAtURL:[NSURL fileURLWithPath:tmpR2]
                  backupItemName:nil
                         options:NSFileManagerItemReplacementUsingNewMetadataOnly
                resultingItemURL:nil error:&repErr];
            NSLog(@"[TweaksLoader:Restore] replaceItemAtURL: %d err: %@", (int)ok, repErr);
            if (!ok) [[NSFileManager defaultManager] removeItemAtPath:tmpR2 error:nil];
        }
    }

    if (ok) ALGGestaltLock();
    NSLog(@"[TweaksLoader:Restore] === RESULT: %d ===", (int)ok);
    return ok;
}

// ═══════════════════════════════════════════════════════════════
// CacheData patch — iPadOS DeviceClassNumber
// Basado en SparseBox FindCacheDataOffset.m + GestaltTweaksView.swift
//
// El approach correcto:
// 1. Abrir libMobileGestalt.dylib (ya cargada en memoria)
// 2. Buscar la key obfuscada "mtrAoWJ3gsq+I90ZnQ0vQw" en __TEXT,__cstring
// 3. Buscar un struct en __AUTH_CONST/__DATA_CONST,__const cuyo
//    primer pointer apunta a esa string
// 4. Leer uint16_t en offset 0x9a del struct, shift left 3 bits
// 5. Eso da el byte offset dentro de CacheData donde esta DeviceClassNumber
// 6. Escribir 3 (iPad) o 1 (iPhone) como Int en ese offset
// ═══════════════════════════════════════════════════════════════
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
#include <mach-o/loader.h>

static long ALGFindCacheDataOffset(const char *mgKey) {
    const struct mach_header_64 *header = NULL;
    const char *mgName = "/usr/lib/libMobileGestalt.dylib";
    dlopen(mgName, RTLD_GLOBAL);

    for (int i = 0; i < _dyld_image_count(); i++) {
        if (!strncmp(mgName, _dyld_get_image_name(i), strlen(mgName))) {
            header = (const struct mach_header_64 *)_dyld_get_image_header(i);
            break;
        }
    }
    if (!header) {
        NSLog(@"[TweaksLoader:CacheData] libMobileGestalt header not found");
        return -1;
    }

    // Buscar la key obfuscada en __TEXT,__cstring
    size_t textCStringSize;
    const char *textCStringSection = (const char *)getsectiondata(header, "__TEXT", "__cstring", &textCStringSize);
    if (!textCStringSection) {
        NSLog(@"[TweaksLoader:CacheData] __TEXT,__cstring not found");
        return -1;
    }
    const char *keyPtr = NULL;
    for (size_t size = 0; size < textCStringSize; size += strlen(textCStringSection + size) + 1) {
        if (!strncmp(mgKey, textCStringSection + size, strlen(mgKey))) {
            keyPtr = textCStringSection + size;
            break;
        }
    }
    if (!keyPtr) {
        NSLog(@"[TweaksLoader:CacheData] Key '%s' not found in __cstring", mgKey);
        return -1;
    }

    // Buscar struct cuyo primer pointer apunta a la key
    size_t constSize;
    // arm64e
    const uintptr_t *constSection = (const uintptr_t *)getsectiondata(header, "__AUTH_CONST", "__const", &constSize);
    if (!constSection) {
        // arm64 fallback
        constSection = (const uintptr_t *)getsectiondata(header, "__DATA_CONST", "__const", &constSize);
    }
    if (!constSection) {
        NSLog(@"[TweaksLoader:CacheData] __const section not found");
        return -1;
    }

    const uintptr_t *structPtr = NULL;
    for (int i = 0; i < (int)(constSize / 8); i++) {
        if (constSection[i] == (uintptr_t)keyPtr) {
            structPtr = constSection + i;
            break;
        }
    }
    if (!structPtr) {
        NSLog(@"[TweaksLoader:CacheData] Struct for key not found in __const");
        return -1;
    }

    // Leer uint16_t en offset 0x9a, shift left 3
    long offset = (long)((uint16_t *)structPtr)[0x9a / 2] << 3;
    NSLog(@"[TweaksLoader:CacheData] FindCacheDataOffset('%s') = %ld", mgKey, offset);
    return offset;
}

static BOOL ALGPatchCacheDataDeviceClass(NSMutableDictionary *plist, BOOL toIPad) {
    NSMutableData *cacheData = plist[@"CacheData"];
    if (![cacheData isKindOfClass:[NSData class]]) {
        NSLog(@"[TweaksLoader:CacheData] No CacheData found");
        return NO;
    }
    // Asegurar que es mutable
    if (![cacheData isKindOfClass:[NSMutableData class]]) {
        cacheData = [cacheData mutableCopy];
        plist[@"CacheData"] = cacheData;
    }

    // mtrAoWJ3gsq+I90ZnQ0vQw = DeviceClassNumber obfuscated key
    long valueOffset = ALGFindCacheDataOffset("mtrAoWJ3gsq+I90ZnQ0vQw");
    if (valueOffset < 0 || (NSUInteger)valueOffset >= cacheData.length - sizeof(int)) {
        NSLog(@"[TweaksLoader:CacheData] Invalid offset: %ld (data length: %lu)", valueOffset, (unsigned long)cacheData.length);
        return NO;
    }

    // Leer valor actual
    int currentValue = 0;
    [cacheData getBytes:&currentValue range:NSMakeRange(valueOffset, sizeof(int))];
    NSLog(@"[TweaksLoader:CacheData] Current DeviceClassNumber at offset %ld = %d", valueOffset, currentValue);

    // Escribir: 3 = iPad, 1 = iPhone (igual que SparseBox)
    int newValue = toIPad ? 3 : 1;
    [cacheData replaceBytesInRange:NSMakeRange(valueOffset, sizeof(int)) withBytes:&newValue];

    NSLog(@"[TweaksLoader:CacheData] Patched DeviceClassNumber: %d -> %d (toIPad=%d)", currentValue, newValue, (int)toIPad);
    return YES;
}

// Tweaks disponibles — mismos que Nugget
// subKey = nil -> directo en CacheExtra
// subKey = "oPeik/9e8lQWMszEjbPzng" -> CacheExtra[subKey][key]
// Para tweaks con múltiples keys, usamos "keys" y "values" arrays
// Single key: @"key" + @"value" + @"sub"
// Multi key:  @"keys" array + @"values" array (sub siempre "")
static NSArray *ALGGestaltTweaks(void) {
    return @[
        // ── Dynamic Island ──
        @{@"label":@"Dynamic Island (14 Pro)",      @"key":@"ArtworkDeviceSubType", @"value":@(2556), @"sub":PEIK, @"risky":@NO, @"section":@"Dynamic Island"},
        @{@"label":@"Dynamic Island (14 Pro Max)",  @"key":@"ArtworkDeviceSubType", @"value":@(2796), @"sub":PEIK, @"risky":@NO, @"section":@"Dynamic Island"},
        @{@"label":@"Dynamic Island (15 Pro Max)",  @"key":@"ArtworkDeviceSubType", @"value":@(2976), @"sub":PEIK, @"risky":@NO, @"section":@"Dynamic Island"},
        @{@"label":@"Dynamic Island (16 Pro)",      @"key":@"ArtworkDeviceSubType", @"value":@(2622), @"sub":PEIK, @"risky":@NO, @"section":@"Dynamic Island"},
        @{@"label":@"Dynamic Island (16 Pro Max)",  @"key":@"ArtworkDeviceSubType", @"value":@(2868), @"sub":PEIK, @"risky":@NO, @"section":@"Dynamic Island"},
        @{@"label":@"Dynamic Island (iPhone 17)",   @"key":@"ArtworkDeviceSubType", @"value":@(2736), @"sub":PEIK, @"risky":@NO, @"section":@"Dynamic Island"},
        @{@"label":@"iPhone X Gestures",            @"key":@"ArtworkDeviceSubType", @"value":@(2436), @"sub":PEIK, @"risky":@NO, @"section":@"Dynamic Island"},
        @{@"label":@"Supports Dynamic Island",      @"key":@"YlEtTtHlNesRBMal1CqRaA", @"value":@YES, @"sub":@"", @"risky":@NO, @"section":@"Dynamic Island"},

        // ── Features ──
        @{@"label":@"Boot Chime",                   @"key":@"QHxt+hGLaBPbQJbXiUJX3w", @"value":@YES,  @"sub":@"", @"risky":@NO, @"section":@"Features"},
        @{@"label":@"80% Charge Limit",             @"key":@"37NVydb//GP/GrhuTN+exg", @"value":@YES,  @"sub":@"", @"risky":@NO, @"section":@"Features"},
        @{@"label":@"Tap to Wake (SE)",             @"key":@"yZf3GTRMGTuwSV/lD7Cagw", @"value":@YES,  @"sub":@"", @"risky":@NO, @"section":@"Features"},
        @{@"label":@"Action Button",                @"key":@"cT44WE1EohiwRzhsZ8xEsw",  @"value":@YES,  @"sub":@"", @"risky":@NO, @"section":@"Features"},
        @{@"label":@"Always On Display",            @"keys":@[@"2OOJf1VhaM7NxfRok3HbWQ",@"j8/Omm6s1lsmTDFsXjsBfA"], @"values":@[@YES,@YES], @"sub":@"", @"risky":@NO, @"section":@"Features"},
        @{@"label":@"AOD Vibrancy",                 @"key":@"ykpu7qyhqFweVMKtxNylWA",   @"value":@YES,  @"sub":@"", @"risky":@NO, @"section":@"Features"},
        @{@"label":@"Apple Pencil Support",         @"key":@"yhHcB0iH0d1XzPO/CFd3ow",  @"value":@YES,  @"sub":@"", @"risky":@NO, @"section":@"Features"},
        @{@"label":@"Apple Internal (Metal HUD)",   @"key":@"EqrsVvjcYDdxHBiQmGhAWw",  @"value":@YES,  @"sub":@"", @"risky":@NO, @"section":@"Features"},
        @{@"label":@"Disable Wallpaper Parallax",   @"key":@"UIParallaxCapability",     @"value":@(0),  @"sub":@"", @"risky":@NO, @"section":@"Features"},
        @{@"label":@"Collision SOS",                @"key":@"HCzWusHQwZDea6nNhaKndw",  @"value":@YES,  @"sub":@"", @"risky":@NO, @"section":@"Features"},
        @{@"label":@"Camera Button (iPhone 16)",    @"keys":@[@"CwvKxM2cEogD3p+HYgaW0Q",@"oOV1jhJbdV3AddkcCg0AEA"], @"values":@[@(1),@(1)], @"sub":@"", @"risky":@NO, @"section":@"Features"},
        @{@"label":@"Silent Shutter (US)",          @"keys":@[@"h63QSdBCiT/z0WU6rdQv6Q",@"zHeENZu+wbg7PUprwNwBWg"], @"values":@[@"US",@"LL/A"], @"sub":@"", @"risky":@NO, @"section":@"Features"},
        @{@"label":@"Internal Storage",             @"key":@"LBJfwOEzExRxzlAnSuI7eg",  @"value":@YES,  @"sub":@"", @"risky":@NO, @"section":@"Features"},
        @{@"label":@"SRD Mode",                     @"key":@"XYlJKKkj2hztRP1NWWnhlw",  @"value":@YES,  @"sub":@"", @"risky":@NO, @"section":@"Features"},
        @{@"label":@"Enable LGLPM",                 @"key":@"SAGvsp6O6kAQ4fEfDJpC4Q",  @"value":@YES,  @"sub":@"", @"risky":@NO, @"section":@"Features"},

        // ── iPadOS (risky) ──
        @{@"label":@"iPadOS (Stage Manager + Multitasking)", @"keys":@[@"uKc7FPnEO++lVhHWHFlGbQ",@"mG0AnH/Vy1veoqoLRAIgTA",@"UCG5MkVahJxG1YULbbd5Bg",@"ZYqko/XM5zD3XBfN5RmaXA",@"nVh/gwNpy7Jv1NOk00CMrw",@"qeaj75wk3HF4DwQ8qbIi7g"], @"values":@[@(1),@(1),@(1),@(1),@(1),@(1)], @"sub":@"", @"risky":@YES, @"section":@"iPadOS", @"patchCacheData":@YES},
        @{@"label":@"Stage Manager",                @"key":@"qeaj75wk3HF4DwQ8qbIi7g",  @"value":@(1),  @"sub":@"", @"risky":@YES, @"section":@"iPadOS"},
        @{@"label":@"iPad Apps on iPhone",          @"key":@"9MZ5AdH43csAUajl/dU+IQ",  @"value":@[@(1),@(2)], @"sub":@"", @"risky":@YES, @"section":@"iPadOS"},

        // ── Apple Intelligence ──
        @{@"label":@"Apple Intelligence (AI Gestalt)", @"key":@"A62OafQ85EJAiiqKn4agtg", @"value":@YES, @"sub":@"", @"risky":@NO, @"section":@"Apple Intelligence"},
    ];
}


static void ALGShowGestaltEditor(void) {
    if (!gGestaltWindow) {
        UIWindowScene *scene=nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if ([s isKindOfClass:[UIWindowScene class]]){scene=(UIWindowScene*)s;break;}
        if (@available(iOS 13.0,*))
            gGestaltWindow=[[UIWindow alloc] initWithWindowScene:scene];
        else
            gGestaltWindow=[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        gGestaltWindow.windowLevel=UIWindowLevelAlert+610;
        gGestaltWindow.backgroundColor=[UIColor clearColor];
        UIViewController *vc=[[UIViewController alloc] init];
        vc.view.backgroundColor=[UIColor clearColor];
        gGestaltWindow.rootViewController=vc;
    }
    gGestaltWindow.frame=[UIScreen mainScreen].bounds;
    gGestaltWindow.rootViewController.view.frame=[UIScreen mainScreen].bounds;
    gGestaltWindow.hidden=NO; gGestaltWindow.userInteractionEnabled=YES;
    UIView *root=gGestaltWindow.rootViewController.view;
    for (UIView *v in [root.subviews copy]) [v removeFromSuperview];

    CGFloat sw2=[UIScreen mainScreen].bounds.size.width;
    CGFloat sh=[UIScreen mainScreen].bounds.size.height;
    CGFloat mw=MIN(sw2-20,380); CGFloat mh=sh*0.85f;
    CGFloat mx=(sw2-mw)/2; CGFloat my=(sh-mh)/2;

    // Dim
    UIView *dim=[[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    dim.backgroundColor=[UIColor colorWithWhite:0 alpha:0.45f]; dim.alpha=0;
    __weak UIWindow *ww=gGestaltWindow;
    ALGBlockButton *dimBtn=[ALGBlockButton buttonWithType:UIButtonTypeCustom];
    dimBtn.frame=dim.bounds;
    dimBtn.actionBlock=^{
        [UIView animateWithDuration:0.2f animations:^{dim.alpha=0;}
            completion:^(BOOL d){ww.hidden=YES;for(UIView*v in [root.subviews copy])[v removeFromSuperview];}];
    };
    [dimBtn addTarget:dimBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    [dim addSubview:dimBtn]; [root addSubview:dim];

    // Shadow
    UIView *shd=[[UIView alloc] initWithFrame:CGRectMake(mx,my,mw,mh)];
    shd.backgroundColor=[UIColor clearColor]; shd.layer.cornerRadius=28;
    shd.layer.shadowColor=[UIColor colorWithRed:0.1f green:0.15f blue:0.7f alpha:0.5f].CGColor;
    shd.layer.shadowOpacity=0.8f; shd.layer.shadowRadius=30; shd.layer.shadowOffset=CGSizeMake(0,10);
    shd.userInteractionEnabled=NO; [root addSubview:shd];

    // Panel
    UIView *panel=ALGMakeGlassPanel(CGRectMake(mx,my,mw,mh));

    // Header
    UIView *pill=[[UIView alloc] initWithFrame:CGRectMake((mw-36)/2,8,36,4)];
    pill.backgroundColor=[UIColor colorWithWhite:1 alpha:0.2f];
    pill.layer.cornerRadius=2; [panel addSubview:pill];

    UILabel *ttl=[[UILabel alloc] initWithFrame:CGRectMake(0,18,mw,22)];
    ttl.text=@"MobileGestalt"; ttl.font=[UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    ttl.textColor=[UIColor whiteColor]; ttl.textAlignment=NSTextAlignmentCenter;
    ttl.userInteractionEnabled=NO; [panel addSubview:ttl];

    // Close
    ALGBlockButton *xBtn=[ALGBlockButton buttonWithType:UIButtonTypeCustom];
    xBtn.frame=CGRectMake(mw-44,10,34,34); xBtn.layer.cornerRadius=17;
    xBtn.backgroundColor=[UIColor colorWithWhite:1 alpha:0.08f];
    UILabel *xL=[[UILabel alloc] initWithFrame:CGRectMake(0,0,34,34)];
    xL.text=@"\u2715"; xL.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    xL.textColor=[UIColor colorWithWhite:1 alpha:0.45f];
    xL.textAlignment=NSTextAlignmentCenter; xL.userInteractionEnabled=NO;
    [xBtn addSubview:xL];
    xBtn.actionBlock=^{
        [UIView animateWithDuration:0.2f animations:^{dim.alpha=0;panel.alpha=0;}
            completion:^(BOOL d){ww.hidden=YES;for(UIView*v in [root.subviews copy])[v removeFromSuperview];}];
    };
    [xBtn addTarget:xBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:xBtn];

    // Status
    BOOL hasBackup=[[NSFileManager defaultManager] fileExistsAtPath:GESTALT_BACKUP];
    BOOL canWrite=[[NSFileManager defaultManager] isWritableFileAtPath:GESTALT_PLIST];
    UILabel *statusLbl=[[UILabel alloc] initWithFrame:CGRectMake(16,42,mw-32,16)];
    statusLbl.font=[UIFont systemFontOfSize:10]; statusLbl.textAlignment=NSTextAlignmentCenter;
    statusLbl.textColor=canWrite?ALG_GREEN:[UIColor colorWithRed:1 green:0.4f blue:0.3f alpha:0.8f];
    statusLbl.text=!canWrite?@"Read-only — needs TrollStore/jailbreak"
                  :hasBackup?@"Backup exists — safe to modify"
                  :@"No backup yet — created on first save";
    statusLbl.userInteractionEnabled=NO; [panel addSubview:statusLbl];

    // Separator
    UIView *sepH=[[UIView alloc] initWithFrame:CGRectMake(0,61,mw,0.5f)];
    sepH.backgroundColor=[UIColor colorWithWhite:1 alpha:0.12f]; [panel addSubview:sepH];

    // Tweaks list
    UIScrollView *sc=[[UIScrollView alloc] initWithFrame:CGRectMake(0,62,mw,mh-62-56)];
    sc.showsVerticalScrollIndicator=NO; sc.bounces=YES;
    NSDictionary *currentPlist=ALGLoadGestaltPlist();
    NSDictionary *cacheExtra=currentPlist[@"CacheExtra"]?:@{};
    NSArray *tweaks=ALGGestaltTweaks();
    CGFloat rowY=10;
    NSString *lastSection=@"";

    for (NSDictionary *tweak in tweaks) {
        NSString *section=tweak[@"section"]?:@"";
        // Section header cuando cambia
        if (![section isEqualToString:lastSection]) {
            if (rowY > 10) rowY += 8; // extra spacing between sections
            UILabel *secLbl=[[UILabel alloc] initWithFrame:CGRectMake(20,rowY,mw-40,16)];
            secLbl.text=[section uppercaseString];
            secLbl.font=[UIFont systemFontOfSize:10 weight:UIFontWeightBold];
            secLbl.textColor=[UIColor colorWithWhite:1 alpha:0.30f];
            secLbl.userInteractionEnabled=NO;
            [sc addSubview:secLbl]; rowY+=22;
            lastSection=section;
        }

        BOOL risky=[tweak[@"risky"] boolValue];
        NSString *key=tweak[@"key"];
        NSString *sub=tweak[@"sub"];
        NSArray *mKeys=tweak[@"keys"];

        // Read state
        BOOL isOn=NO;
        if (mKeys.count>0) {
            BOOL allOn=YES;
            for (NSString *mk in mKeys)
                if (!cacheExtra[mk]){allOn=NO;break;}
            isOn=allOn;
        } else if (sub.length>0) {
            NSDictionary *sd=cacheExtra[sub];
            id v=sd[key];
            isOn=(v!=nil && ![v isEqual:@(0)] && ![v isEqual:@NO]);
        } else {
            id v=cacheExtra[key];
            isOn=(v!=nil && ![v isEqual:@(0)] && ![v isEqual:@NO]);
        }

        UIView *row=[[UIView alloc] initWithFrame:CGRectMake(10,rowY,mw-20,50)];
        row.backgroundColor=[UIColor colorWithWhite:1 alpha:risky?0.06f:0.035f];
        row.layer.cornerRadius=13;
        if (@available(iOS 13.0,*)) row.layer.cornerCurve=kCACornerCurveContinuous;
        [sc addSubview:row];

        UILabel *lbl=[[UILabel alloc] initWithFrame:CGRectMake(14,8,mw-20-90,20)];
        lbl.text=tweak[@"label"];
        lbl.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        lbl.textColor=risky?ALG_WARN:[UIColor whiteColor];
        lbl.userInteractionEnabled=NO; [row addSubview:lbl];

        // Show first key or multi-key count
        NSString *detail = key ?: [NSString stringWithFormat:@"%lu keys",(unsigned long)mKeys.count];
        if (detail.length > 22) detail = [[detail substringToIndex:22] stringByAppendingString:@"\u2026"];
        UILabel *klbl=[[UILabel alloc] initWithFrame:CGRectMake(14,28,mw-20-90,14)];
        klbl.text=detail;
        klbl.font=[UIFont systemFontOfSize:9 weight:UIFontWeightRegular];
        klbl.textColor=[UIColor colorWithWhite:1 alpha:0.22f];
        klbl.userInteractionEnabled=NO; [row addSubview:klbl];

        UISwitch *gsw=[[UISwitch alloc] initWithFrame:CGRectMake(mw-20-64,10,51,31)];
        gsw.on=isOn;
        gsw.onTintColor=risky?ALG_WARN:ALG_ACCENT;

        // ── Apply logic (preserved exactly from original) ──
        NSDictionary *tref=tweak;
        ALGBlockButton *swProxy=[ALGBlockButton new];
        swProxy.actionBlock=^{
            ALGBackupGestalt();
            NSData *tData2=[NSPropertyListSerialization dataWithPropertyList:
                [ALGLoadGestaltPlist() mutableCopy]
                format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
            NSMutableDictionary *mpl2=tData2?
                [[NSPropertyListSerialization propertyListWithData:tData2
                    options:NSPropertyListMutableContainersAndLeaves
                    format:nil error:nil] mutableCopy]:nil;
            if (!mpl2){gsw.on=!gsw.on;return;}
            NSMutableDictionary *cache=mpl2[@"CacheExtra"];
            if (![cache isKindOfClass:[NSMutableDictionary class]])
                cache=[cache mutableCopy]?:[NSMutableDictionary dictionary];
            NSString *subk=tref[@"sub"];
            NSArray *mk=tref[@"keys"];
            NSArray *mv=tref[@"values"];
            if (mk.count>0){
                for (NSInteger ki=0;ki<(NSInteger)mk.count;ki++){
                    if (gsw.on) cache[mk[ki]]=ki<(NSInteger)mv.count?mv[ki]:@YES;
                    else [cache removeObjectForKey:mk[ki]];
                }
            } else if (subk.length>0){
                NSMutableDictionary *sd=cache[subk];
                if (![sd isKindOfClass:[NSMutableDictionary class]])
                    sd=[sd mutableCopy]?:[NSMutableDictionary dictionary];
                if (gsw.on) sd[tref[@"key"]]=tref[@"value"];
                else [sd removeObjectForKey:tref[@"key"]];
                cache[subk]=sd;
            } else {
                if (gsw.on) cache[tref[@"key"]]=tref[@"value"];
                else [cache removeObjectForKey:tref[@"key"]];
            }
            mpl2[@"CacheExtra"]=cache;
            // CacheData patch solo para iPadOS
            if ([tref[@"patchCacheData"] boolValue]) {
                BOOL cdOk = ALGPatchCacheDataDeviceClass(mpl2,gsw.on);
                NSLog(@"[TweaksLoader:CacheData] Editor patch: %d", (int)cdOk);
            }
            BOOL saved=ALGSaveGestaltPlist(mpl2);
            gsw.on=saved?gsw.on:!gsw.on;
        };
        [gsw addTarget:swProxy action:@selector(handleTap) forControlEvents:UIControlEventValueChanged];
        objc_setAssociatedObject(gsw,"p",swProxy,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [row addSubview:gsw];
        rowY+=56;
    }
    sc.contentSize=CGSizeMake(mw,rowY+16);
    [panel addSubview:sc];

    // ── Bottom bar: Restore + Respring ──
    UIView *bottomBar=[[UIView alloc] initWithFrame:CGRectMake(0,mh-56,mw,56)];
    bottomBar.backgroundColor=[UIColor clearColor];
    // Top separator
    UIView *bsep=[[UIView alloc] initWithFrame:CGRectMake(0,0,mw,0.5f)];
    bsep.backgroundColor=[UIColor colorWithWhite:1 alpha:0.1f]; [bottomBar addSubview:bsep];

    CGFloat bbw=(mw-36)/2;
    ALGBlockButton *restBtn=ALGActionBtn(@"Restore",ALG_RED,8,bbw+24);
    restBtn.frame=CGRectMake(12,8,bbw,40);
    restBtn.actionBlock=^{
        BOOL ok=ALGRestoreGestalt();
        if (@available(iOS 10.0,*)){
            UINotificationFeedbackGenerator *g=[[UINotificationFeedbackGenerator alloc] init];
            [g notificationOccurred:ok?UINotificationFeedbackTypeSuccess:UINotificationFeedbackTypeError];
        }
        ALGToast(panel,ok?@"Restored! Respring to apply":@"No backup found",ok);
    };
    [restBtn addTarget:restBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:restBtn];

    ALGBlockButton *respBtn=ALGActionBtn(@"Apply (Respring)",ALG_ACCENT,8,bbw+24);
    respBtn.frame=CGRectMake(12+bbw+12,8,bbw,40);
    respBtn.actionBlock=^{ ALGDoRespring(); };
    [respBtn addTarget:respBtn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:respBtn];
    [panel addSubview:bottomBar];

    [root addSubview:panel];
    panel.alpha=0; dim.alpha=0;
    panel.transform=CGAffineTransformConcat(CGAffineTransformMakeScale(0.92f,0.92f),CGAffineTransformMakeTranslation(0,16));
    [UIView animateWithDuration:0.35f delay:0 usingSpringWithDamping:0.8f initialSpringVelocity:0.4f
        options:0 animations:^{panel.alpha=1;dim.alpha=1;panel.transform=CGAffineTransformIdentity;}
        completion:nil];
}

__attribute__((constructor))
static void AldazTweaksLoaderInit(void) {

    NSLog(@"[AldazDev] OK: SpringBoard OK");

    ALGLoadPrefs();
    NSLog(@"[AldazDev] OK: Prefs loaded");

    // Floating dock hooks
    Class iconMgr = objc_getClass("SBHIconManager");
    if (iconMgr) HOOK(iconMgr, @selector(isFloatingDockSupported), hook_isFloatingDockSupported, orig_isFloatingDockSupported);
    Class rfcClass = objc_getClass("SBRootFolderController");
    if (rfcClass) HOOK(rfcClass, @selector(isDockExternal), hook_isDockExternal, orig_isDockExternal);
    Class fdockCtrl = objc_getClass("SBFloatingDockController");
    if (fdockCtrl) HOOK(object_getClass(fdockCtrl), @selector(isFloatingDockSupported), hook_fdockCtrl_isSupported, orig_fdockCtrl_isSupported);
    Class iconCtrlClass = objc_getClass("SBIconController");
    if (iconCtrlClass) HOOK(iconCtrlClass, sel_registerName("isFloatingDockSupportedForIconManager:"), hook_isFloatingDockSupportedForIconManager, orig_isFloatingDockSupportedForIconManager);
    Class fdDefaults = objc_getClass("SBFloatingDockDefaults");
    if (fdDefaults) {
        HOOK(fdDefaults, @selector(recentsEnabled), hook_recentsEnabled, orig_recentsEnabled);
        HOOK(fdDefaults, sel_registerName("setRecentsEnabled:"), hook_setRecentsEnabled, orig_setRecentsEnabled);
        HOOK(fdDefaults, @selector(appLibraryEnabled), hook_appLibraryEnabled, orig_appLibraryEnabled);
        HOOK(fdDefaults, sel_registerName("setAppLibraryEnabled:"), hook_setAppLibraryEnabled, orig_setAppLibraryEnabled);
    }
    Class suggModel = objc_getClass("SBFloatingDockSuggestionsModel");
    if (suggModel) HOOK(suggModel, sel_registerName("maxSuggestions"), hook_maxSuggestions, orig_maxSuggestions);
    Class gridConfig = objc_getClass("SBIconListGridLayoutConfiguration");
    if (gridConfig) HOOK(gridConfig, sel_registerName("numberOfPortraitColumns"), hook_numberOfPortraitColumns, orig_numberOfPortraitColumns);
    Class iconListView = objc_getClass("SBIconListView");
    if (iconListView) HOOK(iconListView, sel_registerName("maximumIconCount"), hook_maximumIconCount, orig_maximumIconCount);
    Class fdockCtrlInst = objc_getClass("SBFloatingDockController");
    if (fdockCtrlInst) HOOK(fdockCtrlInst, sel_registerName("_configureFloatingDockBehaviorAssertionForOpenFolder:atLevel:"), hook_configureBehaviorForFolder, orig_configureBehaviorForFolder);
    Class fluidSwitcher = objc_getClass("SBFluidSwitcherViewController");
    if (fluidSwitcher) {
        HOOK(fluidSwitcher, sel_registerName("isFloatingDockGesturePossible"), hook_isFloatingDockGesturePossible, orig_isFloatingDockGesturePossible);
        HOOK(fluidSwitcher, sel_registerName("isFloatingDockSupported"), hook_switcher_isFloatingDockSupported, orig_switcher_isFloatingDockSupported);
    }
    NSLog(@"[AldazDev] OK: Dock hooks done");

    // Dock animation
    hookMethod("SBFloatingDockViewController",
               @selector(viewWillAppear:), (IMP)hooked_fdockPresent, &orig_fdockPresent);
    hookMethod("SBFloatingDockViewController",
               @selector(viewWillDisappear:), (IMP)hooked_fdockDismiss, &orig_fdockDismiss);

    // Banners
    hookMethod("BNBannerClientContainerViewController", @selector(viewDidLoad),
               (IMP)hooked_bannerLoad, &orig_bannerLoad);
    NSLog(@"[AldazDev] OK: Banner hook done");

    // Dock nativo — glass + spacing
    hookMethod("SBDockView", @selector(layoutSubviews),
               (IMP)hooked_nativeDockLayout, &orig_nativeDockLayout);
    // También intentar en iOS 17
    hookMethod("SBDockHorizontalLayoutStrategy", @selector(layoutIconsInDockView:),
               (IMP)hooked_dockIconLayout, &orig_dockIconLayout);

    // Round icons
    hookMethod("SBIconView", @selector(layoutSubviews),
               (IMP)hooked_iconViewLayout, &orig_iconViewLayout);

    // Page animations
    hookMethod("SBIconScrollView", @selector(setContentOffset:),
               (IMP)hooked_setContentOffset, &orig_setContentOffset);
    NSLog(@"[AldazDev] OK: Icon/scroll hooks done");

    // Battery
    hookMethod("_UIBatteryView", sel_registerName("setFillLayer:"),
               (IMP)hooked_setFillLayer, &orig_setFillLayer);
    hookMethod("_UIBatteryView", sel_registerName("_updateFillLayer"),
               (IMP)hooked_updateFillLayer, &orig_updateFillLayer);
    hookMethod("_UIBatteryView", @selector(layoutSubviews),
               (IMP)hooked_battLayout, &orig_battLayout);
    NSLog(@"[AldazDev] OK: Battery hooks done");

    // Lockscreen clock/date
    const char *clockClasses[] = {"SBFLockScreenDateView", "_UIDateLabelView", NULL};
    for (int i = 0; clockClasses[i] && !orig_lsClockLayout; i++)
        hookMethod(clockClasses[i], @selector(layoutSubviews),
                   (IMP)hooked_lsClockLayout, &orig_lsClockLayout);
    NSLog(@"[AldazDev] OK: Clock hook: %s", orig_lsClockLayout ? "OK" : "MISS");

    const char *dateClasses[] = {"SBFLockScreenDateSubtitleDateView",
                                  "SBFLockScreenDateSubtitleView", NULL};
    for (int i = 0; dateClasses[i] && !orig_lsDateLayout; i++)
        hookMethod(dateClasses[i], @selector(layoutSubviews),
                   (IMP)hooked_lsDateLayout, &orig_lsDateLayout);
    NSLog(@"[AldazDev] OK: Date hook: %s", orig_lsDateLayout ? "OK" : "MISS");

    // Notificaciones
    hookMethod("NCNotificationShortLookViewController",
               @selector(viewDidLayoutSubviews),
               (IMP)hooked_ncLayoutSubviews, &orig_ncLayoutSubviews);
    hookMethod("NCNotificationShortLookViewController",
               sel_registerName("viewDidAppear:"),
               (IMP)hooked_ncViewDidAppear, &orig_ncViewDidAppear);
    hookMethod("NCNotificationSummaryPlatterView",
               @selector(layoutSubviews),
               (IMP)hooked_summaryLayout, &orig_summaryLayout);
    NSLog(@"[AldazDev] OK: NC notification hooks done");

    // Lockscreen visibility
    const char *lsClasses[] = {
        "SBDashBoardViewController",
        "CSCoverSheetViewController",
        NULL
    };
    for (int i = 0; lsClasses[i]; i++) {
        Class lsCls = objc_getClass(lsClasses[i]);
        if (!lsCls) continue;
        Method mApp  = class_getInstanceMethod(lsCls, @selector(viewDidAppear:));
        Method mDis  = class_getInstanceMethod(lsCls, @selector(viewDidDisappear:));
        if (mApp && !orig_lsDashAppear) {
            orig_lsDashAppear = (IMP)method_getImplementation(mApp);
            method_setImplementation(mApp, (IMP)hooked_lsDashAppear);
        }
        if (mDis && !orig_lsDashDisappear) {
            orig_lsDashDisappear = (IMP)method_getImplementation(mDis);
            method_setImplementation(mDis, (IMP)hooked_lsDashDisappear);
        }
        if (orig_lsDashAppear && orig_lsDashDisappear) {
            NSLog(@"[AldazDev] OK: LS visibility hooked via: %s", lsClasses[i]);
            break;
        }
    }
    if (!orig_lsDashAppear) NSLog(@"[AldazDev] FAIL: LS visibility hook MISS — no class found");

    NSLog(@"[AldazDev] OK: All hooks done — scheduling setup");

    // Settings button a los 2s
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.0*NSEC_PER_SEC)),
                   dispatch_get_main_queue(),^{
        NSLog(@"[AldazDev] OK: Setup starting...");
        ALGSetupSettingsButton();

        hookMethod("CCUIModularControlCenterOverlayViewController",
            sel_registerName("setPresentationState:"),
            (IMP)hooked_ccPresentationState, &orig_ccPresentationState);
        NSLog(@"[AldazDev] OK: Settings button ready");
        LSLoadPrefs();
        NSLog(@"[AldazDev] OK: LS prefs loaded");
        LSSetupFloatingButton();
        NSLog(@"[AldazDev] OK: LS button ready");
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.0*NSEC_PER_SEC)),
                   dispatch_get_main_queue(),^{
        activateDock();
    });
}