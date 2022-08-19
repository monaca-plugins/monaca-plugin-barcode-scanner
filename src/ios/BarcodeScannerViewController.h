//
//  BarcodeScannerViewController.h
//
//  Created by Asial Corporation.
//  Copyright (c) 2022 Asial Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const DELEGATE_DETECTED_TEXT;
extern NSString *const DELEGATE_DETECTED_FORMAT;


@protocol BarcodeScannerDelegate <NSObject>

@optional

/// BarcodeScannerViewController が閉じられる際に呼ばれるコールバック
/// @param detected:  検出されたバーコード
///   - nil: 検出キャンセル(検出を確定せずに閉じる)
///   - non nil:
///     - detected[@"text"]: バーコードから変換された文字列
///     - detected[@"format"]: バーコードの形式  
- (void)didDismiss: (NSDictionary * _Nullable)detected;

@end

/// バーコードスキャナー ViewController
@interface BarcodeScannerViewController : UIViewController < UIAdaptivePresentationControllerDelegate>

- (BarcodeScannerViewController*)initWithOptions:(NSDictionary *)options;

/// delegate
@property (weak, nonatomic) id <BarcodeScannerDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
