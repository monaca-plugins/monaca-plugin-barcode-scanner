# monaca-plugin-barcode-scanner

Barcode scanner Monaca Plugin.

## Description

This plugin provides a scanning barcode feature.
Detect barcode or QR Code[^1] by device's camera and returns extracted strings.

### Scanning mode

- `Normal` mode  
  The detected code is displayed on screen and selected by tapping(clicking).
- `One Shot` mode  
  The first detected code is selected and screen closed automatically.

### Detection timeout message

A Specified message can be displayed if no code is detected for a certain period.

## Supported Platforms

### Build Environments

- Cordova 11.0.0 or later
- cordova-android@10.1.2 or later
- cordova-ios@6.2.0 or later

### Operating Environments

- Android 5.1 or later (9 or later recommended)
- iOS 11 or later (13 or later recommended)

## Supported Barcode Types

- QR_CODE
- EAN_8
- EAN_13
- ITF
- CODE_128
- CODE_39
and more...

Notes:
- As of ver.1.4.0, we have expanded supported barcode types.  
This plugin now scans almost all formats supported by the iOS or Android MKKit.
- In additional to the types mentioned above, following types will be scanned.
  - CODE_93, AZTEC, DATA_MATRIX, UPC_E, and others.
- Some formats are exclusively supported on iOS.

See [here](#About-detecting-barcode) for the caution of detection.

> Some devices may fail to detect barcodes. See [here](#how-to-check-for-unsupported-image-formats) for details.

## API Reference

```
monaca.BarcodeScanner.scan(successCallback, failCallback[, options])
```

- Calling `scan ()` will transition to the scanner screen.
- When the barcode is detected, the extracted character string is displayed below the frame.(`Normal mode`)
- Tap the string to return to the original screen and the string and barcode type will be returned to `successCallback`.
- In the case of `One Shot` mode, the first detected code is returned and screen is closed automatically.
- When returned to the original screen without selecting the string, the detection will be cancelled.
In order to return to the original screen, click the "Close" (X on the screen) button for iOS and the "Back" button for Android.

### successCallback

successCallback(result)

result: following data
```
{
  data: {
    "text": "xxxxxxxx"  // detected string
    "format": "QR_CODE"  // barcode type
  },
  cancelled: false // detection cancelled(true) or not(false)
}
```

### failCallback

failCallback(error)

error: error message(string)

|message|description|
|---|---|
|"permission denied"|camera permission is not granted.|

### options

```
{
  "oneShot" : true,
  "timeoutPrompt" : {
    "show" : true,
    "timeout" : 5,
    "prompt" : "Not detected"
  },
  "debug" : {
    "preview" : 0
  }
}
```

|parameter|type|default value|description|
|---|---|---|---|
|oneShot|boolean|false|Enable or disable One Shot mode.|
|timeoutPrompt.show|boolean|false|Show or hide detection timeout message.|
|timeoutPrompt.timeout|int|-|Period(in seconds) from when the barcode not detected until the message is displayed.|
|timeoutPrompt.prompt|string|"Barcode not detected"|Timeout message.|
|debug.preview<br/>(android only)|int|0|Displays camera preview bitmap(before sending to MLKit) on screen.<br/>0: OFF(default)<br/>1: Inside detection area <br/>2: Whole camera image|

## Example

```javascript
  monaca.BarcodeScanner.scan((result) => {
    if (result.cancelled) {
      // scan cancelled
    } else {
      // scan
      const detected_text = result.data.text;
      const detected_format = result.data.format;
    }
  }, (error) => {
    // permission error
    const error_message = error;
  }, {
    "oneShot" : true,
    "timeoutPrompt" : {
      "show" : true,
      "timeout" : 5,
      "prompt" : "Not detected"
    }
  });
```

## iOS Quirks

Since iOS 10, it's mandatory to provide a usage description in the `info.plist`.  
The description string is displayed in the permission dialog box.

This plugin requires the following usage descriptions:

- `NSCameraUsageDescription` specifies the reason for your app to access the device's camera.

To add these entries ito the `info.plist`, you can use the `<edit-config>` tag in the `config.xml` file like this:

```
    <platform name="ios">
        <edit-config target="NSCameraUsageDescription" file="*-Info.plist" mode="merge">
            <string>need camera access to scan barcode</string>
        </edit-config>
    </platform>
```

## Android Quirks

### compileSDKVersion

The library `androidx.camera:camera-view` used internally requires `compileSDKVersion>=31`.

To specify the compileSdkVersion in Cordova, you should set `android-targetSdkVersion` by using the `<preference>` tag in the `config.xml` file like this:

```
<preference name="android-targetSdkVersion" value="31" />
```

### Barcode detection problem due to device model dependency

This plugin detects barcodes by processing the image captured by the camera (ImageProxy) and passing it to the barcode detection library (MLKit).  
ImageProxy can store images in a variety of formats, and it depends on the device what format the camera captures.  
Some devices may fail to detect barcodes because they are captured in a format not supported by the plugin.

#### Supported format

|version|supported format|
|---|---|
|before ver.1.2.1|- Support `JPEG` or `YUV_420_888`<br/>- Support only when plane buffer's `rowStride` is same as `ImageWidth`|
|ver.1.3.0|- Support when plane buffer's `rowStride` is different from `ImageWidth` |

#### How to check for unsupported image formats

You can check the device compatibility by using the `debug preview` feature added in ver.1.3.0.

- Enable `debug preview` in config

```javascript
  monaca.BarcodeScanner.scan((result) => {
    if (result.cancelled) {
      // scan cancelled
    } else {
      // scan
    }
  }, (error) => {
    // permission error
    const error_message = error;
  }, {
    "debug" : {
      "preview" : 1
    }
  });
```

- Thumbnail of the image  before barcode detection are displayed on the scan screen.

If this thumbnail image is displayed distorted, it will be a device that does not support.

<img width="270" alt="unsupported" src="https://user-images.githubusercontent.com/98803273/262234724-4c9b355f-a4eb-4205-aa57-9dfc868b0384.png">

## About detecting barcode

### ITF code (since ver.1.2.0)

Ver.1.2.0:

- For iOS, only ITF-14 (14 digits ITF) is supported.
- For Android, various digits ITF is supported.

Ver.1.4.0

- Various digits ITF is supported on iOS.

### Other barcode

Caution:
  - Because some barcode standard is prone to cause misdetection, requiring the barcode to be exactly positioned within the detection area.

## iOS Privacy Manifest

As of May 1, 2024, Apple requires a privacy manifest file to be created for apps and third-party SDKs. The purpose of the privacy manifest file is to explain the data being collected and the reasons for the required APIs it uses. Starting with `cordova-ios@7.1.0`, APIs are available for configuring the privacy manifest file from `config.xml`.

As an app developer, it will be your responsibility to identify additional information explaining what your app does with that data.
In this case, you will need to review the "[Describing data use in privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_data_use_in_privacy_manifests)" to understand the list of known `NSPrivacyCollectedDataTypes` and `NSPrivacyCollectedDataTypePurposes`.

Also, ensure all four keys—`NSPrivacyTracking`, `NSPrivacyTrackingDomains`, `NSPrivacyAccessedAPITypes`, and `NSPrivacyCollectedDataTypes`—are defined, even if you are not making an addition to the other items. Apple requires all to be defined.

Additional Resources:
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Privacy Manifest Files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files?language=objc)

## License

see [LICENSE](./LICENSE)

[^1]: QR Code is a registered trademark of DENSO WAVE INCORPORATED in Japan and in other countries.

