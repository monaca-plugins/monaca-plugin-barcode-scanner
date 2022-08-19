//
//  CDVBarcodeScanner.m
//
//  Created by Asial Corporation.
//  Copyright (c) 2022 Asial Corporation. All rights reserved.
//

#import <Cordova/CDV.h>
#import "CDVBarcodeScanner.h"
#import "BarcodeScannerViewController.h"
#import <AVFoundation/AVFoundation.h>

static NSString * const PERMISSION_DENIED_ERROR = @"permission denied";

typedef NS_ENUM(NSInteger, ScannerPermission) {
    ScannerPermissionGranted = 0,   // 許可
    ScannerPermissionRequesting = 1,    // 許可リクエスト中
    ScannerPermissionDenied = 2,    // 拒否
};

# pragma mark - CustomNavigationController

/// 回転処理やmodalPresentationの動作をカスタマイズするためのNavigationController
/// NagigationController for customize a behaviour of rotation and modalPresentation.
@interface CustomNavigationController : UINavigationController

@end

@implementation CustomNavigationController

/// override
- (BOOL)shouldAutorotate {
    // 画面の回転に対応する
    // allow device rotation
    return YES;
}

/// override
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // 画面の回転に対応する
    // allow device rotation
    return UIInterfaceOrientationMaskAll;
}

@end

# pragma mark - CDVBarcodeScanner

@interface CDVBarcodeScanner () <BarcodeScannerDelegate>

/// callback ID
/// プラグインへの値の返却に用いる
@property NSString *callbackId;

@end

/// バーコードスキャナープラグイン barcode scanner plugin
@implementation CDVBarcodeScanner

NSDictionary* options;

/// plugin action method
/// @param command
- (void)scan:(CDVInvokedUrlCommand*)command
{
    self.callbackId = command.callbackId;
    if (command.arguments.count == 0) {
        options = [NSDictionary dictionary];
    } else {
        options = command.arguments[0];
    }
    [self.commandDelegate runInBackground:^{
        // Perform UI operations on the main thread
        [self callScanner];
    }];
}

/// スキャナー画面の呼び出し call scanner screen
- (void) callScanner {
    // カメラ許可の確認
    ScannerPermission permission = ScannerPermissionDenied;
    permission = [CDVBarcodeScanner checkAndRequestPremissions:^(ScannerPermission result) {
        // 許可を求めた結果
        if (result == ScannerPermissionGranted) {
            // 許可されたのでスキャナー画面へ
            [self showScanner];
        } else if (result == ScannerPermissionDenied){
            // 拒否されたのでプラグインにエラーを返却
            [self sendPluginResultWithPermissionError];
        }
    }];
    // 過去に許可を求めている場合、許可の場合のみスキャナー画面へ遷移する
    // 新たに許可を求めている場合(permission == ScannerPermissionRequesting)
    // requestCameraPremissionのコールバックが呼び出されるため何もしない
    if (permission == ScannerPermissionGranted) {
        // 許可済なのでスキャナー画面へ
        [self showScanner];
    } else if (permission == ScannerPermissionDenied){
        // 拒否されているのでプラグインにエラーを返却
        [self sendPluginResultWithPermissionError];
    }
}

/// スキャナー画面への遷移  navigate to scanner screen
- (void) showScanner {
    dispatch_async(dispatch_get_main_queue(), ^{
        // スキャナー画面の作成
        BarcodeScannerViewController *scanner = [[BarcodeScannerViewController alloc] initWithOptions:options];
        scanner.view.frame = self.viewController.view.frame;
        scanner.delegate = self;    // BarcodeScannerViewControllerからの通知を受け取る

        CustomNavigationController *navigationController = [[CustomNavigationController alloc] initWithRootViewController:scanner];
        navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
        if(navigationController.presentationController) {
            // BarcodeScannerViewController自身で画面遷移の通知を受け取ることができるようにdelegate設定
            navigationController.presentationController.delegate = scanner;
        }

        // スキャナー画面へ遷移
        [self.viewController presentViewController:navigationController animated:YES completion:nil];
    });
}

/// Check and request permissions
/// @param completionHandler: カメラ許可のリクエスト結果のコールバック
/// @return (ScannerPermission)permission: 過去にリクエスト済の場合、その結果を返す
+ (ScannerPermission)checkAndRequestPremissions:(void (^)(ScannerPermission))completionHandler {
    ScannerPermission permission = ScannerPermissionDenied;
    switch([AVCaptureDevice authorizationStatusForMediaType:(AVMediaTypeVideo)]) {
        case AVAuthorizationStatusNotDetermined:
            {
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                    ScannerPermission result = granted ? ScannerPermissionGranted : ScannerPermissionDenied;
                    completionHandler(result);
                }];
            }
            permission = ScannerPermissionRequesting;
            break;
        case AVAuthorizationStatusRestricted:
            break;
        case AVAuthorizationStatusDenied:
            break;
        case AVAuthorizationStatusAuthorized:
            permission = ScannerPermissionGranted;
            break;
    }
    return permission;
}

/// プラグインへ値を返却する  return value to plugin
/// @param (NSDictionary *)result 戻り値
- (void)sendPluginResultWithValue: (NSDictionary *)result {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
}

/// プラグインへエラーを返却する  return error to plugin
- (void)sendPluginResultWithPermissionError {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:PERMISSION_DENIED_ERROR];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
}

# pragma mark - BarcodeScannerDelegate

/// Implementation of BarcodeScannerDelegate
/// スキャナー画面が閉じる際に呼び出される
/// @param detected: 検出されたバーコード
- (void)didDismiss:(NSDictionary * _Nullable)detected
{
    // 返却するデータ形式に変換
    NSDictionary *result = @{
        @"data": @{
            @"text": detected ? detected[DELEGATE_DETECTED_TEXT] : @"",
            @"format": detected ? detected[DELEGATE_DETECTED_FORMAT] : @""
        },
        @"cancelled": detected ? @NO : @YES
    };
    // プラグインに値を返却
    [self sendPluginResultWithValue:result];
}

@end
