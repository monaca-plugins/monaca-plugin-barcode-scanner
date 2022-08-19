/**
 * Copyright (c) 2022 Asial Corporation. All rights reserved.
 */
package io.monaca.plugin.barcodescanner;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.util.Log;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;

import org.apache.cordova.PermissionHelper;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.Arrays;

/**
 * Barcode scanner plugin class
 */
public class BarcodeScanner extends CordovaPlugin {
    public static final String TAG = "BarcodeScanner";
    public static final int REQUEST_CODE_CAMERA_PERMISSION = 0;
    public static final int REQUEST_CODE_SCANNER = 1000;
    protected final static String[] permissions = {Manifest.permission.CAMERA};
    public static final String PERMISSION_DENIED_ERROR = "permission denied";
    public static final String UNKNOWN_ERROR = "unknown error";
    private JSONObject options;

    public CallbackContext callbackContext;

    /**
     * ${inheritDoc}
     */
    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) {
        this.callbackContext = callbackContext;
        if ("scan".equals(action)) {
            // plugin scan action
            try {
                if (args.length() > 0) {
                    options = args.getJSONObject(0);
                }
            } catch (JSONException e) {
                options = null;
            }
            callScanner();
        } else {
            return false;
        }
        return true;
    }

    /**
     * Call scanner feature
     */
    private void callScanner() {
        // カメラ許可の確認
        ScannerPermission permission = checkAndRequestPermissions();
        if (permission == ScannerPermission.GRANTED) {
            // 許可された場合のみ処理を続行する
            showScanner();
        } else if (permission == ScannerPermission.DENIED) {
            sendPluginError(PERMISSION_DENIED_ERROR);
        }

        // ScannerPermission.REQUESTINGの場合は onRequestPermissionResult() で許可のリクエスト結果が渡されるため
        // ここでは何もしない
    }

    /**
     * Show scanner screen
     */
    private void showScanner() {
        Intent intent = new Intent(this.cordova.getActivity(), BarcodeScannerActivity.class);
        if (options != null) {
            setIntentExtras(options, intent, "");
        }
        this.cordova.startActivityForResult((CordovaPlugin) this, intent, REQUEST_CODE_SCANNER);
    }

    /**
     * Set option parameters to intent extras
     */
    private void setIntentExtras(JSONObject jsonObj, Intent intent, String keyPrefix) {
        if (jsonObj == null) {
            return;
        }
        JSONArray names = jsonObj.names();
        if (names == null) {
            return;
        }
        for (int i = 0; i < names.length(); i ++) {
            try {
                String key = names.getString(i);
                String extraKey = keyPrefix + key;
                Object value = jsonObj.get(key);
                if (value instanceof Boolean) {
                    intent.putExtra(extraKey, (Boolean) value);
                } else if (value instanceof Number) {
                    intent.putExtra(extraKey, ((Number) value).intValue());
                } else if (value instanceof String) {
                    intent.putExtra(extraKey, (String) value);
                } else if (value instanceof JSONObject) {
                    setIntentExtras((JSONObject) value, intent, extraKey + ".");
                }
            } catch (JSONException e) {
                continue;
            }
        }
    }

    /**
     * スキャナーに必要な機能の許可状態  Scanner permission status
     *
     * GRANTED: 許可
     * REQUESTING: 許可リクエスト中
     * DENIED: 拒否
     */
    public enum ScannerPermission {
        GRANTED(0),
        REQUESTING(1),
        DENIED(2);

        ScannerPermission(int i) {
        }
    }

    /**
     * Check permission and request if needed
     */
    private ScannerPermission checkAndRequestPermissions() {
        // カメラ許可の確認
        boolean cameraPermission = PermissionHelper.hasPermission(this, Manifest.permission.CAMERA);
        if (cameraPermission) {
            // 許可済
            return ScannerPermission.GRANTED;
        }

        // Manifest内の定義を確認
        // Manifest内に記述がない場合はリクエストできない
        boolean hasPermissionInManifest = false;
        try {
            PackageManager packageManager = this.cordova.getActivity().getPackageManager();
            String[] permissionsInPackage = packageManager.getPackageInfo(this.cordova.getActivity().getPackageName(), PackageManager.GET_PERMISSIONS).requestedPermissions;
            if (permissionsInPackage != null) {
                if (Arrays.asList(permissionsInPackage).contains(Manifest.permission.CAMERA)) {
                    hasPermissionInManifest = true;
                }
            }
        } catch (PackageManager.NameNotFoundException e) {
            // We are requesting the info for our package, so this should
            // never be caught
            sendPluginError(UNKNOWN_ERROR);
        }

        if (hasPermissionInManifest) {
            // Manifestに記述がある場合のみリクエストする
            PermissionHelper.requestPermissions(this, REQUEST_CODE_CAMERA_PERMISSION, permissions);
            return ScannerPermission.REQUESTING;
        } else {
            // 記述がないので拒否扱いとする
            return ScannerPermission.DENIED;
        }
    }

    /**
     * プラグインにエラーを返却する  Send error to plugin
     * @param message エラーメッセージ
     */
    private void sendPluginError(String message) {
        Log.d(TAG, "Plugin Error: " + message);
        this.callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, message));
    }

    /**
     * ${inheritDoc}
     */
    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent intent) {
        if (requestCode == REQUEST_CODE_SCANNER) {
            if (resultCode == Activity.RESULT_OK) {
                String detectedText = intent.getStringExtra(BarcodeScannerActivity.INTENT_DETECTED_TEXT);
                String detectedFormat = intent.getStringExtra(BarcodeScannerActivity.INTENT_DETECTED_FORMAT);

                JSONObject result = getResultData(detectedText, detectedFormat, false);
                this.callbackContext.success(result);
            } else {
                // cancelled
                JSONObject result = getResultData("", "", true);
                this.callbackContext.success(result);
            }
        }
    }

    private static JSONObject getResultData(String text, String format, boolean cancelled) {
        JSONObject result = new JSONObject();
        try {
            JSONObject resultData = new JSONObject();
            resultData.put("text", text);
            resultData.put("format", format);
            result.put("data", resultData);
            result.put("cancelled", cancelled);
        } catch (JSONException e) {
            Log.d(TAG, "Failed to create JSONObject");
        }

        return result;
    }

    /**
     * ${inheritDoc}
     */
    @Override
    public void onRestoreStateForActivityResult(Bundle state, CallbackContext callbackContext) {
        this.callbackContext = callbackContext;
    }

    /**
     * ${inheritDoc}
     */
    @Override
    @Deprecated
    public void onRequestPermissionResult(int requestCode, String[] permissions,
                                           int[] grantResults) {
        switch (requestCode) {
            case REQUEST_CODE_CAMERA_PERMISSION:
                for (int r : grantResults) {
                    if (r == PackageManager.PERMISSION_DENIED) {
                        // 許可されなかったのでエラーを返却
                        sendPluginError(PERMISSION_DENIED_ERROR);
                        return;
                    }
                }
                // 許可されたのでスキャナー画面へ遷移
                showScanner();
                break;
        }
    }
}
