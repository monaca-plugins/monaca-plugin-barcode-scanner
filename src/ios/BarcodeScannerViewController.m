//
//  BarcodeScannerViewController.m
//
//  Created by Asial Corporation.
//  Copyright (c) 2022 Asial Corporation. All rights reserved.
//

#import "BarcodeScannerViewController.h"
#import <AVFoundation/AVFoundation.h>

#ifdef DEBUG
    #define LOGD(...) NSLog(__VA_ARGS__)
#else
    #define LOGD(...)
#endif

CGFloat const DETECTION_AREA_SIZE = 240.0;
CGFloat const DETECTION_AREA_SIZE_IPAD = 320.0;
CGFloat const DETECTION_AREA_BORDER = 8;

NSString *const DELEGATE_DETECTED_TEXT = @"text";
NSString *const DELEGATE_DETECTED_FORMAT = @"format";
// 検出テキストのデザイン
CGFloat const DETECTED_TEXT_RADIUS = 20.0;
CGFloat const DETECTED_TEXT_HEIGHT = 40.0;
CGFloat const DETECTED_TEXT_MARGIN_PORTRAIT = 20.0; // 検出枠との距離(Portrait時)
CGFloat const DETECTED_TEXT_MARGIN_LANDSCAPE = 10.0; // 検出枠との距離(Landscape時)
CGFloat const DETECTED_TEXT_FONT_SIZE = 12.0;
CGFloat const DETECTED_TEXT_PADDING_VERT = 4.0;
CGFloat const DETECTED_TEXT_PADDING_HORZ = 12.0;
// 検出タイムアウトメッセージのデザイン
CGFloat const DETECTED_TIMEOUT_RADIUS = 15.0;
CGFloat const DETECTED_TIMEOUT_HEIGHT = 50.0;
CGFloat const DETECTED_TIMEOUT_MARGIN_PORTRAIT = 20.0; // 検出枠との距離(Portrait時)
CGFloat const DETECTED_TIMEOUT_MARGIN_LANDSCAPE = 10.0; // 検出枠との距離(Landscape時)
CGFloat const DETECTED_TIMEOUT_FONT_SIZE = 16.0;
CGFloat const DETECTED_TIMEOUT_PADDING_VERT = 4.0;
CGFloat const DETECTED_TIMEOUT_PADDING_HORZ = 12.0;
NSString *const DETECTED_TIMEOUT_PROMPT_DEFAULT = @"Barcode not detected";


@implementation UIColor (Extensions)

+ (UIColor *)scannerBlue {
    return [UIColor colorWithRed:0x00/255.0 green:0x85/255.0 blue:0xb1/255.0 alpha:255.0 ];
}

+ (UIColor *)detectedTextColor {
    return UIColor.whiteColor;
}

+ (UIColor *)detectedTextBgColor {
    return UIColor.scannerBlue;
}

+ (UIColor *)detectedAreaDefaultColor {
    return UIColor.whiteColor;
}

+ (UIColor *)detectedAreaDetectedColor {
    return UIColor.scannerBlue;
}

+ (UIColor *)detectTimeoutTextColor {
    return UIColor.whiteColor;
}

+ (UIColor *)detectTimeoutBgColor {
    return [UIColor colorWithRed:0x40/255.0 green:0x40/255.0 blue:0x40/255.0 alpha:0.7 ];
}

@end

/// バーコードスキャナー ViewController
@interface BarcodeScannerViewController () <AVCaptureMetadataOutputObjectsDelegate, UIAdaptivePresentationControllerDelegate>

/// プレビュー画面
@property AVCaptureVideoPreviewLayer *previewLayer;
/// カメラキャプチャセッション
@property (strong, nonatomic) AVCaptureSession *session;
/// バーコード検出範囲を示すビュー
@property (strong, nonatomic) UIView* detectionArea;
/// 検出された文字列の画面表示
@property (strong, nonatomic) UIButton* detectedStr;
/// 検出タイムアウトメッセージ
@property (strong, nonatomic) UILabel* timeoutPrompt;

/// 検出された文字列
@property NSString *detectedText;
/// 検出されたバーコード形式
@property NSString *detectedFormat;

/// 検出エリアの座標
@property CGRect detectionAreaRect;

@end

@implementation BarcodeScannerViewController

NSTimer* timeoutPromptTimer;
/// option parameters
BOOL oneShot;
BOOL showTimeoutPrompt;
int timeoutSeconds;
NSString* timeoutPrompt;

/// init
- (BarcodeScannerViewController*)initWithOptions:(NSDictionary *)options {
    self = [super init];
    if(!self){
        return self;
    }
    oneShot = [self isOneShot:options];
    showTimeoutPrompt = [self doesShowTimeoutPrompt:options];
    timeoutSeconds = [self timeoutValue:options];
    timeoutPrompt = [self timeoutPromptText:options];

    return self;
}

/// override
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    // 閉じるボタンの作成
    UIBarButtonItem *closeButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(cancel:)];
    self.navigationItem.rightBarButtonItem = closeButtonItem;

    // デバイス回転の通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceDidRotate:) name:UIDeviceOrientationDidChangeNotification object:nil];
    
    [self startCamera];
}

/// override
/// @param animated
- (void)viewWillAppear:(BOOL)animated {
    // UIModalPresentationFullScreen以外で表示されたときのためにUIの位置を調整する
    [self layoutAllUIComponents];
}

#pragma mark - Navigation
/*

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

/// override
/// dismissViewControllerAnimatedで明示的に閉じられる際に呼び出される
/// ViewControllerが閉じられる際に呼び出し元へ検出したバーコードを通知する
/// @param flag
/// @param completion
-(void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    [super dismissViewControllerAnimated:flag completion:completion];

    // キャプチャ停止
    [self.session stopRunning];
    // タイマー停止
    [timeoutPromptTimer invalidate];
    
    // 検出したバーコードの返却
    NSDictionary *detected = nil;
    if ([self.detectedText length] > 0) {
        // 検出成功
        detected = [self getDetectedData];
    }
    if (self.delegate) {
        [self.delegate didDismiss:detected];
    }
}

/// implement of UIAdaptivePresentationControllerDelegate
/// スワイプで閉じられる際に呼び出される
/// @param presentationController
-(void)presentationControllerWillDismiss:(UIPresentationController *)presentationController {

    // キャプチャ停止
    [self.session stopRunning];
    // タイマー停止
    [timeoutPromptTimer invalidate];

    // 検出キャンセル
    if (self.delegate) {
        [self.delegate didDismiss:nil];
    }
}

#pragma mark - Orientation

/// override
- (BOOL)shouldAutorotate {
    // 画面の回転に対応する
    return YES;
}

/// override
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // 画面の回転に対応する
    return UIInterfaceOrientationMaskAll;
}

/// デバイスの回転の通知
/// @param note
- (void)deviceDidRotate:(NSNotification*)note {
    // UIの位置やプレビュー画面の向きを調整し直す
    [self layoutAllUIComponents];
}

/// convert UIDevice orientation to AVCaptureVideoOrientation
///
/// Caution:
/// AVCaptureVideoPreviewLayerにおいてlanscapeモードではプレビュー画面が反転してしまうため
/// AVCaptureVideoOrientationLandscapeLeft/Rightは逆にして返す
///
/// on landscape orientation, left/right is reversed in order to correct video capture preview orientation.
- (AVCaptureVideoOrientation) videoOrientationFromCurrentDeviceOrientation {
    switch (UIDevice.currentDevice.orientation) {
        case UIDeviceOrientationPortrait: {
            return AVCaptureVideoOrientationPortrait;
        }
        case UIDeviceOrientationLandscapeLeft: {
            // return reversed value for video preview
            return AVCaptureVideoOrientationLandscapeRight;
        }
        case UIDeviceOrientationLandscapeRight: {
            // return reversed value for video preview
            return AVCaptureVideoOrientationLandscapeLeft;
        }
        case UIDeviceOrientationPortraitUpsideDown: {
            return AVCaptureVideoOrientationPortraitUpsideDown;
        }
        case UIDeviceOrientationFaceUp: {
            return AVCaptureVideoOrientationPortrait;
        }
        case UIDeviceOrientationFaceDown: {
            return AVCaptureVideoOrientationPortrait;
        }
        case UIDeviceOrientationUnknown: {
            return AVCaptureVideoOrientationPortrait;
        }
    }
}

#pragma mark - UI

/// 画面からはみ出した部分を考慮したプレビュー画面のサイズ
- (CGSize)unclippedPreviewSize {
    // 画面の向き
    BOOL isHorizontal = UIDeviceOrientationIsLandscape(UIDevice.currentDevice.orientation);
    // 画面のアスペクト比を計算
    CGFloat screenRatio = self.view.frame.size.width / self.view.frame.size.height;
    // カメラキャプチャ入力のアスペクト比を計算
    CGFloat captureRatio = isHorizontal ? 16.0 / 9.0 : 9.0 / 16.0;
    
    // アスペクト比を比較して実際のプレビュー画面のサイズを計算
    CGSize unclippedSize = self.view.frame.size;
    if (screenRatio < captureRatio) {
        // 画面の比率の方が小さい場合は左右がはみ出す
        unclippedSize.width = unclippedSize.height * captureRatio;
    } else {
        // 画面の比率の方が大きい場合は上下がはみ出す
        unclippedSize.height = unclippedSize.width / captureRatio;
    }
    
    return unclippedSize;
}

/// 検出範囲の座標(絶対値)を計算する
- (void)calculateDetectionArea {
    CGFloat areaSize = (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) ? DETECTION_AREA_SIZE_IPAD : DETECTION_AREA_SIZE;
    self.detectionAreaRect = CGRectMake((self.view.frame.size.width - areaSize) / 2, (self.view.frame.size.height - areaSize) / 2, areaSize, areaSize);
}

/// 検出範囲の画面上の範囲を計算する
///AVCaptureMetadataOutputの検出範囲(rectOnInterest)の指定は絶対値ではなく画面内の範囲(0.0-1.0)で指定する
- (CGRect)detectionAreaRange {
    CGSize unclippedSize = [self unclippedPreviewSize];
    CGFloat unclippedOriginX = self.detectionAreaRect.origin.x + (unclippedSize.width - self.view.frame.size.width) / 2;
    CGFloat unclippedOriginY = self.detectionAreaRect.origin.y + (unclippedSize.height - self.view.frame.size.height) / 2;

    return CGRectMake(unclippedOriginX / unclippedSize.width, unclippedOriginY / unclippedSize.height, self.detectionAreaRect.size.width / unclippedSize.width, self.detectionAreaRect.size.height / unclippedSize.height);
}

/// 検出のUIを作成する
- (void)createDetectionUI {

    // 検出エリアの枠を作成
    self.detectionArea = [[UIView alloc] init];
    self.detectionArea.layer.borderColor = [UIColor detectedAreaDefaultColor].CGColor;
    self.detectionArea.layer.borderWidth = DETECTION_AREA_BORDER;
    [self.view addSubview:self.detectionArea];
    
    // 検出文字列表示欄
    self.detectedStr = [[UIButton alloc] init];
    // ラベル
    [self.detectedStr setTitle:@"" forState:UIControlStateNormal];    self.detectedStr.titleLabel.textColor = [UIColor detectedTextColor];
    self.detectedStr.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.detectedStr.titleLabel.font = [UIFont systemFontOfSize:DETECTED_TEXT_FONT_SIZE];
    self.detectedStr.titleEdgeInsets = UIEdgeInsetsMake(DETECTED_TEXT_PADDING_HORZ, DETECTED_TEXT_PADDING_VERT, DETECTED_TEXT_PADDING_HORZ, DETECTED_TEXT_PADDING_VERT);

    self.detectedStr.layer.cornerRadius = DETECTED_TEXT_RADIUS;
    self.detectedStr.backgroundColor = [UIColor detectedTextBgColor];
    [self.detectedStr setHidden:YES];
    
    // 検出タイムアウト文字列
    self.timeoutPrompt = [[UILabel alloc] init];
    self.timeoutPrompt.textAlignment = NSTextAlignmentCenter;
    self.timeoutPrompt.font = [UIFont systemFontOfSize:DETECTED_TIMEOUT_FONT_SIZE];
    self.timeoutPrompt.textColor = [UIColor detectTimeoutTextColor];
    self.timeoutPrompt.layer.cornerRadius = DETECTED_TIMEOUT_RADIUS;
    self.timeoutPrompt.layer.backgroundColor = [UIColor detectTimeoutBgColor].CGColor;
    self.timeoutPrompt.text = timeoutPrompt;
    [self.timeoutPrompt setHidden:YES];

    // 位置を調整する
    [self layoutDetectionUI];
    
    // 検出文字列のタップを設定
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(onTapDetectedStr)];
    self.detectedStr.userInteractionEnabled = YES;
    [self.detectedStr addGestureRecognizer:gesture];

    // 文字列表示タイマー設定
//    timeoutPromptTimer = [NSTimer scheduledTimerWithTimeInterval:[self timeoutValue] target:self selector:@selector(onDetectionTimeout:) userInfo:nil repeats:YES];
    [self startDetectionTimer];
    
    [self.view addSubview:self.detectedStr];
    [self.view addSubview:self.timeoutPrompt];
}

/// 全てのUIパーツの位置を調整する
- (void)layoutAllUIComponents {
    [self calculateDetectionArea];
    [self layoutPreviewLayer];
    [self layoutDetectionUI];
}

/// プレビュー画面の位置を調整する
- (void)layoutPreviewLayer {
    self.previewLayer.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    [self.previewLayer.connection setVideoOrientation:[self videoOrientationFromCurrentDeviceOrientation]];
}

/// 検出のUIの位置を調整する
- (void)layoutDetectionUI {
    // 検出エリア
    self.detectionArea.frame = self.detectionAreaRect;

    // 検出文字列
    BOOL isLandscape = UIDeviceOrientationIsLandscape(UIDevice.currentDevice.orientation);
    CGFloat margin = isLandscape ? DETECTED_TEXT_MARGIN_LANDSCAPE : DETECTED_TEXT_MARGIN_PORTRAIT;
    [self.detectedStr sizeToFit];
    self.detectedStr.frame = CGRectMake((self.view.frame.size.width - self.detectedStr.frame.size.width - DETECTED_TEXT_PADDING_HORZ * 2)/2, self.detectionAreaRect.origin.y + self.detectionAreaRect.size.height + margin, self.detectedStr.frame.size.width + DETECTED_TEXT_PADDING_HORZ * 2, DETECTED_TEXT_HEIGHT);
    
    // 検出タイムアウト文字列
    [self.timeoutPrompt sizeToFit];
    self.timeoutPrompt.frame = CGRectMake((self.view.frame.size.width - self.timeoutPrompt.frame.size.width - DETECTED_TIMEOUT_PADDING_HORZ * 2)/2, self.detectionAreaRect.origin.y + self.detectionAreaRect.size.height + margin, self.timeoutPrompt.frame.size.width + DETECTED_TIMEOUT_PADDING_HORZ * 2, DETECTED_TIMEOUT_HEIGHT);
}

/// 検出された文字列のタップ
/// 検出内容を確定して画面を閉じる
- (void)onTapDetectedStr {
    if ([self.detectedText length] > 0) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

/// 閉じるボタンのタップ
/// @param barButtonItem  閉じるボタン
- (void)cancel:(UIBarButtonItem *)barButtonItem {
    self.detectedText = @"";
    self.detectedFormat = @"";
    [self dismissViewControllerAnimated:YES completion:nil];
}

/// 検出タイムアウト文字列表示タイマーハンドラ
/// @param timer タイマー
- (void)onDetectionTimeout:(NSTimer *) timer {
    [self.timeoutPrompt setHidden:NO];
    [timer invalidate];
}

- (void)startDetectionTimer {
    if (![self isEnableTimeoutPrompt]) {
        return;
    }
    timeoutPromptTimer = [NSTimer scheduledTimerWithTimeInterval:MAX(timeoutSeconds, 0.4f) target:self selector:@selector(onDetectionTimeout:) userInfo:nil repeats:NO];
}
/// 検出タイムアウト文字列再表示
- (void)restartDetectionTimer {
    if (![self isEnableTimeoutPrompt]) {
        return;
    }
    [timeoutPromptTimer invalidate];
    [self.timeoutPrompt setHidden:YES];
    [self startDetectionTimer];
}

#pragma mark - Scanner process

/// カメラ設定＆検出開始
-(void)startCamera {
    // カメラセッションの作成
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    self.session = [[AVCaptureSession alloc] init];

    // キャプチャ入力の設定
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];

    if (!input) {
        // カメラ入力が使用できない
        LOGD(@"Failed to initialize AVCaptureDeviceInput");
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    [self.session addInput:input];

    // キャプチャ出力の設定
    AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
    [self.session addOutput:output];
    // 読み取りたいバーコードの種類を指定
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [output setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN13Code,
        AVMetadataObjectTypeEAN8Code,
        AVMetadataObjectTypeITF14Code]];
    
    // 検出エリアの設定
    // 検出エリアの座標(絶対値)を計算
    [self calculateDetectionArea];
    // rectOfInterestの計算。絶対値ではなく0-1.0の範囲の割合で渡す。
    CGRect rect = [self detectionAreaRange];
    // AVCaptureMetadataOutputがLandscapeで処理されているためPortraitの場合はx/y反転
    if (UIDeviceOrientationIsLandscape(UIDevice.currentDevice.orientation)) {
        output.rectOfInterest = rect;
    } else {
        output.rectOfInterest = CGRectMake(rect.origin.y, rect.origin.x, rect.size.height, rect.size.width);
    }
        
    // プレビュー画面の作成
    AVCaptureVideoPreviewLayer *preview = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    preview.videoGravity = AVLayerVideoGravityResizeAspectFill;// 画面いっぱいに表示
    [self.view.layer insertSublayer:preview atIndex:0];
    self.previewLayer = preview;

    // 検出UIの作成
    [self createDetectionUI];
    
    // デバイスの向きに合わせてUIやプレビュー画面の位置を調整
    [self layoutAllUIComponents];
    
    // セッション開始
    [self.session startRunning];
}

/// バーコード検出時のコールバック
/// @param captureOutput
/// @param metadataObjects
/// @param connection
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputMetadataObjects:(NSArray *)metadataObjects
       fromConnection:(AVCaptureConnection *)connection {
    for (AVMetadataObject *data in metadataObjects) {
        if (![data isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) continue;

        // バーコードを検出
        NSString *barcodeDataStr = [(AVMetadataMachineReadableCodeObject *)data stringValue];
        if ([data.type isEqualToString:AVMetadataObjectTypeQRCode]
            || [data.type isEqualToString:AVMetadataObjectTypeEAN13Code]
            || [data.type isEqualToString:AVMetadataObjectTypeEAN8Code]
            || [data.type isEqualToString:AVMetadataObjectTypeITF14Code]) {

            self.detectedText = barcodeDataStr;
            self.detectedFormat = [BarcodeScannerViewController getBarcodeFormatString:data.type];

            if (oneShot) {
                // one shotモード
                // １つ目のバーコードが検出されたので処理を終了する
                [self dismissViewControllerAnimated:YES completion:nil];
            } else {
                // UIを更新
                self.detectionArea.layer.borderColor = [UIColor detectedAreaDetectedColor].CGColor;
                self.detectionArea.layer.borderWidth = DETECTION_AREA_BORDER;
                [self.detectedStr setTitle:[barcodeDataStr substringToIndex:MIN(40, barcodeDataStr.length)] forState:UIControlStateNormal];
                [self.detectedStr setHidden:NO];
                [self layoutDetectionUI];
            }
            // 検出タイムアウトタイマーを再起動
            [self restartDetectionTimer];
        } else {
            LOGD(@"other type detected: %@", data.type);
        }
    }
    if (metadataObjects.count == 0) {
        // バーコードが検出されなかった場合
        self.detectedText = @"";
        self.detectedFormat = @"";

        // UIを初期化
        self.detectionArea.layer.borderColor = [UIColor detectedAreaDefaultColor].CGColor;
        self.detectionArea.layer.borderWidth = DETECTION_AREA_BORDER;
        [self.detectedStr setTitle:@"" forState:UIControlStateNormal];
        [self.detectedStr setHidden:YES];
        [self layoutDetectionUI];
    }
}

/// 検出されたバーコードをNSDictionary形式で取得
- (NSDictionary *)getDetectedData {
    NSDictionary *detected = @{
        DELEGATE_DETECTED_TEXT: self.detectedText,
        DELEGATE_DETECTED_FORMAT: self.detectedFormat,
    };
    
    return detected;
}

/// バーコードフォーマットをAVMetadataObjectTypeからプラグインの形式に変換
/// @param type  AVMetadataObjectTypeのバーコード形式
+ (NSString *)getBarcodeFormatString:(NSString *)type {
    NSString *format = @"UNKNOWN";
    if (type == AVMetadataObjectTypeQRCode) {
        format = @"QR_CODE";
    } else if (type == AVMetadataObjectTypeEAN8Code) {
        format = @"EAN_8";
    } else if (type == AVMetadataObjectTypeEAN13Code) {
        format = @"EAN_13";
    } else if (type == AVMetadataObjectTypeITF14Code) {
        format = @"ITF";
    }
    
    return format;
}

#pragma mark - Options

- (BOOL)isOneShot:(NSDictionary*)options {
    if ([options isEqual:[NSNull null]]) {
        return NO;
    }
    id oneShot = options[@"oneShot"];
    if ([self isBoolNumber:oneShot]) {
        return [oneShot boolValue];
    } else {
        return NO;
    }
}

- (BOOL)isEnableTimeoutPrompt {
    return showTimeoutPrompt && timeoutSeconds >= 0;
}

- (BOOL)doesShowTimeoutPrompt:(NSDictionary*)options {
    if ([options isEqual:[NSNull null]]) {
        return NO;
    }
    id showPrompt = [options valueForKeyPath:@"timeoutPrompt.show"];
    if ([self isBoolNumber:showPrompt]) {
        return [showPrompt boolValue];
    } else {
        return NO;
    }
}

- (int)timeoutValue:(NSDictionary*)options {
    if ([options isEqual:[NSNull null]]) {
        return -1;
    }
    NSNumber* timeout = [options valueForKeyPath:@"timeoutPrompt.timeout"];
    if ([timeout isEqual:[NSNull null]] || ![self isNumber:timeout]) {
        return -1;
    }
    return [timeout intValue];
}

- (NSString*)timeoutPromptText:(NSDictionary*)options {
    if ([options isEqual:[NSNull null]]) {
        return DETECTED_TIMEOUT_PROMPT_DEFAULT;
    }
    id prompt = [options valueForKeyPath:@"timeoutPrompt.prompt"];
    if (![prompt isKindOfClass:[NSString class]]) {
        return DETECTED_TIMEOUT_PROMPT_DEFAULT;
    }
    if ([prompt length] > 0) {
        return prompt;
    } else {
        return DETECTED_TIMEOUT_PROMPT_DEFAULT;
    }
}

- (BOOL) isNumber:(NSNumber *)obj {
    if (!obj || [obj isEqual:[NSNull null]] || ![obj isKindOfClass:[NSNumber class]]) {
        return NO;
    }
    if ([self isBoolNumber:obj]) {
        return NO;
    }
    return YES;
}

- (BOOL) isBoolNumber:(NSNumber *)obj {
    if (!obj || [obj isEqual:[NSNull null]]) {
        return NO;
    }
    CFTypeID boolID = CFBooleanGetTypeID();
    CFTypeID numID = CFGetTypeID((__bridge CFTypeRef)(obj));
    return numID == boolID;
}

@end
