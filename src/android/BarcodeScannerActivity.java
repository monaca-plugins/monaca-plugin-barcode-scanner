/**
 * Copyright (c) 2022 Asial Corporation. All rights reserved.
 */
package io.monaca.plugin.barcodescanner;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresPermission;
import androidx.appcompat.app.AppCompatActivity;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageProxy;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.view.PreviewView;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.drawable.GradientDrawable;
import android.media.Image;
import android.os.Bundle;
import android.os.Handler;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.TextView;

import com.google.common.util.concurrent.ListenableFuture;
import com.google.mlkit.vision.barcode.BarcodeScanner;
import com.google.mlkit.vision.barcode.BarcodeScannerOptions;
import com.google.mlkit.vision.barcode.BarcodeScanning;
import com.google.mlkit.vision.barcode.common.Barcode;
import com.google.mlkit.vision.common.InputImage;

import java.util.List;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Executor;

/**
 * Barcode scanner activity class
 */
public class BarcodeScannerActivity extends AppCompatActivity {

    private static final String TAG = "BarcodeScannerActivity";
    private PreviewView previewView;
    private Button detectedTextButton;
    private ImageView detectionArea;
    private Barcode detectedBarcode;
    private TextView timeoutPromptView;
    private ListenableFuture<ProcessCameraProvider> cameraProviderFuture;

    public static final String INTENT_DETECTED_TEXT = "detectedText";
    public static final String INTENT_DETECTED_FORMAT = "detectedFormat";

    private final int DETECTION_AREA_COLOR = 0xffffffff;
    private final int DETECTION_AREA_DETECTED_COLOR = 0xff0085b1;
    private final int DETECTION_AREA_BORDER = 12;

    private final int DETECTED_TEXT_BACKGROUND_COLOR = 0xff0085b1;
    private final int DETECTED_TEXT_COLOR = 0xffffffff;
    private final int DETECTED_TEXT_MAX_LENGTH = 40;

    private final int TIMEOUT_PROMPT_BACKGROUND_COLOR = 0xb4404040;
    private final int TIMEOUT_PROMPT_BACKGROUND_CORNER_RADIUS = 20;

    private boolean oneShot = false;
    private boolean showTimeoutPrompt;
    private int timeoutPromptSpan;
    private String timeoutPrompt = "Barcode not detected";

    private Handler timeoutPromptHandler;
    private Runnable timeoutPromptRunnable;

    /**
     * ${inheritDoc}
     */
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Resources res = getResources();
        String packageName = getPackageName();
        int layoutId = getResourceId(res, "activity_barcode_scanner", "layout", packageName);
        int previewViewId = getResourceId(res, "preview_view", "id", packageName);
        int detectedTextButtonId = getResourceId(res, "detected_text", "id", packageName);
        int detectionAreaId = getResourceId(res, "detection_area", "id", packageName);
        int timeoutPromptId = getResourceId(res, "timeout_prompt", "id", packageName);

        Intent intent = getIntent();
        oneShot = intent.getBooleanExtra("oneShot", false);
        showTimeoutPrompt = intent.getBooleanExtra("timeoutPrompt.show", false);
        timeoutPromptSpan = intent.getIntExtra("timeoutPrompt.timeout", -1);
        String prompt = intent.getStringExtra("timeoutPrompt.prompt");
        if (prompt != null && prompt.length() > 0) {
            timeoutPrompt = prompt;
        }

        // create UI from resource
        setContentView(LayoutInflater.from(this).inflate(layoutId, null));
        previewView = findViewById(previewViewId);
        // detected text
        detectedTextButton = findViewById(detectedTextButtonId);
        detectedTextButton.getBackground().setTint(DETECTED_TEXT_BACKGROUND_COLOR);
        detectedTextButton.setTextColor(DETECTED_TEXT_COLOR);
        detectedTextButton.setVisibility(View.INVISIBLE);
        detectionArea = findViewById(detectionAreaId);
        GradientDrawable drawable = (GradientDrawable) detectionArea.getDrawable();
        drawable.setStroke(DETECTION_AREA_BORDER, DETECTION_AREA_COLOR);
        // timeout prompt
        timeoutPromptView = findViewById(timeoutPromptId);
        GradientDrawable shape = new GradientDrawable();
        shape.setCornerRadius(TIMEOUT_PROMPT_BACKGROUND_CORNER_RADIUS);
        shape.setTint(TIMEOUT_PROMPT_BACKGROUND_COLOR);
        timeoutPromptView.setBackground(shape);
        timeoutPromptView.setText(timeoutPrompt);
        timeoutPromptView.setVisibility(View.INVISIBLE);

        detectedTextButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                // 検出した文字列が選択されたので親画面へ値を渡して遷移する
                if (detectedBarcode == null) {
                    return;
                }
                setResult(Activity.RESULT_OK, getResultIntent());
                finish();
            }
        });
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            // TODO: Consider calling
            //    ActivityCompat#requestPermissions
            // here to request the missing permissions, and then overriding
            //   public void onRequestPermissionsResult(int requestCode, String[] permissions,
            //                                          int[] grantResults)
            // to handle the case where the user grants the permission. See the documentation
            // for ActivityCompat#requestPermissions for more details.
            Log.d(TAG, "Failed to checkSelfPermission");
            return;
        }
        initCamera();
    }

    /**
     * 検出したバーコード情報からIntentを作成する
     * @return intent: バーコード文字列・フォーマットを格納したIntent
     */
    private Intent getResultIntent() {
        Intent intent = new Intent();
        try {
            intent.putExtra(INTENT_DETECTED_TEXT, detectedBarcode.getDisplayValue());
            intent.putExtra(INTENT_DETECTED_FORMAT, getBarcodeFormatString(detectedBarcode.getFormat()));
        } catch (NullPointerException e) {
        }

        return intent;
    }

    /**
     * 定数 Barcode.FORMAT_XXXX からプラグインのフォーマット形式に変換
     * @param format Barcode.FORMAT_XXXX
     * @return formatStr: プラグインで定義するフォーマット文字列
     */
    private static String getBarcodeFormatString(int format) {
        String formatStr = "";
        switch (format) {
            case Barcode.FORMAT_QR_CODE:
                formatStr = "QR_CODE";
                break;
            case Barcode.FORMAT_EAN_8:
                formatStr = "EAN_8";
                break;
            case Barcode.FORMAT_EAN_13:
                formatStr = "EAN_13";
                break;
            case Barcode.FORMAT_ITF:
                formatStr = "ITF";
                break;
            default:
                formatStr = "UNKNOWN";
                break;
        }

        return formatStr;
    }

    /**
     * Initialize and prepare camera
     */
    @RequiresPermission(Manifest.permission.CAMERA)
    private void initCamera() {
        cameraProviderFuture = ProcessCameraProvider.getInstance(this);
        Executor executor = ContextCompat.getMainExecutor(this);

        Runnable listenerRunnable = () -> {
            ProcessCameraProvider cameraProvider = null;
            try {
                cameraProvider = cameraProviderFuture.get();
                bindToLifecycle(cameraProvider, executor);
            } catch (ExecutionException e) {
                Log.d(TAG, "CameraProvider ExecutionException");
            } catch (InterruptedException e) {
                Log.d(TAG, "CameraProvider InterruptedException");
            }
        };
        cameraProviderFuture.addListener(listenerRunnable, executor);

        startDetectionTimer();
    }

    /**
     * Bind preview, analyzer, cameraProvider to camera lifecycle.
     *
     * @param cameraProvider
     * @param executor
     */
    private void bindToLifecycle(ProcessCameraProvider cameraProvider, Executor executor) {

        // prepare preview
        Preview preview = new Preview.Builder().build();
        CameraSelector cameraSelector = new CameraSelector.Builder()
                .requireLensFacing(CameraSelector.LENS_FACING_BACK)
                .build();
        preview.setSurfaceProvider(previewView.getSurfaceProvider());

        // prepare analyzer
        ScannerAnalyzer analyzer = new ScannerAnalyzer();

        ImageAnalysis imageAnalysis = new ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build();
        imageAnalysis.setAnalyzer(executor, analyzer);

        // bind preview and analyzer to lifecycle
        cameraProvider.bindToLifecycle(this, cameraSelector, imageAnalysis, preview);
    }

    /**
     * Callback function to retrieve detected barcodes
     *
     * @param barcodes
     */
    private void onDetectionTaskSuccess(List<Barcode> barcodes) {
        int detected = 0;
        for (Barcode barcode : barcodes) {
            detectedBarcode = barcode;
            String detectedText = barcode.getDisplayValue();
            if (detectedText == null) {
                detectedBarcode = null;
                continue;
            }
            detected ++;

            // UI
            if (!oneShot) {
                GradientDrawable drawable = (GradientDrawable) detectionArea.getDrawable();
                drawable.setStroke(DETECTION_AREA_BORDER, DETECTION_AREA_DETECTED_COLOR);

                detectedTextButton.setText(
                        detectedText.substring(0, Math.min(DETECTED_TEXT_MAX_LENGTH, detectedText.length())));
                detectedTextButton.setVisibility(View.VISIBLE);
            }
        }
        if (detected == 0) {
            // no item is detected.
            detectedBarcode = null;

            // UI
            detectedTextButton.setText("");
            detectedTextButton.setVisibility(View.INVISIBLE);
            GradientDrawable drawable = (GradientDrawable) detectionArea.getDrawable();
            drawable.setStroke(DETECTION_AREA_BORDER, DETECTION_AREA_COLOR);
        } else {
            if (oneShot) {
                setResult(Activity.RESULT_OK, getResultIntent());
                finish();
            }
            // 検出タイムアウトタイマーを再起動
            restartDetectionTimer();
        }
    }

    /**
     * Analyzer class for scanning barcodes.
     */
    private class ScannerAnalyzer implements ImageAnalysis.Analyzer {
        private BarcodeScanner scanner;

        ScannerAnalyzer() {
            BarcodeScannerOptions options = new BarcodeScannerOptions.Builder()
                    .setBarcodeFormats(
                            Barcode.FORMAT_QR_CODE,
                            Barcode.FORMAT_EAN_8,
                            Barcode.FORMAT_EAN_13,
                            Barcode.FORMAT_ITF)
                    .build();
            scanner = BarcodeScanning.getClient(options);
        }

        /**
         * ${inheritDoc}
         */
        @Override
        public void analyze(@NonNull ImageProxy imageProxy) {
            // カメラからキャプチャされた画像を毎フレーム取得してバーコード検出ライブラリへ渡す
            @SuppressLint("UnsafeOptInUsageError") Image mediaImage = imageProxy.getImage();
            int imageWidth, imageHeight;
            int trimWidth, trimHeight;
            int rotationDegrees = imageProxy.getImageInfo().getRotationDegrees();

            // 検出範囲の座標を計算
            int screenWidth = BarcodeScannerActivity.this.previewView.getWidth();
            int screenHeight = BarcodeScannerActivity.this.previewView.getHeight();
            int areaWidth = BarcodeScannerActivity.this.detectionArea.getWidth();
            int areaHeight = BarcodeScannerActivity.this.detectionArea.getHeight();
            if (rotationDegrees % 180 == 0) {
                // landscape
                imageWidth = mediaImage.getWidth();
                trimWidth = imageWidth * areaWidth / screenWidth;
                trimHeight = trimWidth * areaHeight / areaWidth;
            } else {
                // portrait
                imageHeight = mediaImage.getWidth();
                trimHeight = imageHeight * areaHeight / screenHeight;
                trimWidth = trimHeight * areaWidth / areaHeight;
            }

            if (mediaImage != null) {
                // カメラ画像をトリミングして検出範囲を限定する
                Bitmap bitmapOrg = ImageUtils.imageToToBitmap(mediaImage);
                Bitmap bitmapTrimmed = ImageUtils.trim(bitmapOrg, trimWidth, trimHeight);
                InputImage inputImage = InputImage.fromBitmap(bitmapTrimmed, rotationDegrees);
                // バーコード検出実行
                scanner.process(inputImage)
                        .addOnSuccessListener(barcodes -> {
                            // 検出された
                            BarcodeScannerActivity.this.onDetectionTaskSuccess(barcodes);
                        })
                        .addOnFailureListener(e -> {

                        }).addOnCompleteListener(task -> imageProxy.close());
            } else {
                imageProxy.close();
            }
        }
    }

    private boolean isEnableTimeoutPrompt() {
        return showTimeoutPrompt && timeoutPromptSpan >= 0;
    }

    private void startDetectionTimer () {
        if (!isEnableTimeoutPrompt()) {
            return;
        }
        timeoutPromptHandler = new Handler();
        timeoutPromptRunnable = () -> timeoutPromptView.setVisibility(View.VISIBLE);
        timeoutPromptHandler.postDelayed(timeoutPromptRunnable, Math.max(timeoutPromptSpan * 1000, 400));
    }

    private void restartDetectionTimer () {
        if (!isEnableTimeoutPrompt()) {
            return;
        }
        if (timeoutPromptHandler != null) {
            timeoutPromptHandler.removeCallbacks(timeoutPromptRunnable);
        }
        timeoutPromptView.setVisibility(View.INVISIBLE);
        startDetectionTimer();
    }

    /**
     * Get resource id
     *
     * @param res        resource object
     * @param name       resource name
     * @param defType    resource type
     * @param defPackage package name
     * @return resource id
     */
    private static int getResourceId(Resources res, String name, String defType, String defPackage) {
        return res.getIdentifier(name, defType, defPackage);
    }
}
