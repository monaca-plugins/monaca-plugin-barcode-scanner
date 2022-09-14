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
  }
}
```

|parameter|type|default value|description|
|---|---|---|---|
|oneShot|boolean|false|Enable or disable One Shot mode.|
|timeoutPrompt.show|boolean|false|Show or hide detection timeout message.|
|timeoutPrompt.timeout|int|-|Period(in seconds) from when the barcode not detected until the message is displayed.|
|timeoutPrompt.prompt|string|"Barcode not detected"|Timeout message.|

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

The library `androidx.camera:camera-view` used internally requires `compileSDKVersion>=31`.

To specify the compileSdkVersion in Cordova, you should set `android-targetSdkVersion` by using the `<preference>` tag in the `config.xml` file like this:

```
<preference name="android-targetSdkVersion" value="31" />
```

## License

see [LICENSE](./LICENSE)

[^1]: QR Code is a registered trademark of DENSO WAVE INCORPORATED in Japan and in other countries.
