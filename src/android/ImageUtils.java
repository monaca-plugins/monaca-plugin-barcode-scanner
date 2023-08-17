/**
 * Copyright (c) 2022 Asial Corporation. All rights reserved.
 */
package io.monaca.plugin.barcodescanner;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.ImageFormat;
import android.graphics.Rect;
import android.graphics.YuvImage;
import android.media.Image;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;

/**
 * Image utility class
 */
public class ImageUtils {

    /**
     * Trim image to specified size.
     *
     * @param image
     * @param maxWidth
     * @param maxHeight
     * @return trimmed image
     */
    public static Bitmap trim(Bitmap image, int maxWidth, int maxHeight) {
        if (maxHeight > 0 && maxWidth > 0) {
            int width = image.getWidth();
            int height = image.getHeight();

            int startX = (width - maxWidth) / 2;
            int startY = (height - maxHeight) / 2;

            Bitmap result = Bitmap.createBitmap(image, startX, startY, maxWidth, maxHeight, null, true);

            return result;
        } else {
            return image;
        }
    }

    /**
     * Convert Image to Bitmap
     *
     * @param image original Image
     * @return Converted Bitmap
     */
    public static Bitmap imageToBitmap(Image image) {
        byte[] data = imageToByteArray(image);
        return BitmapFactory.decodeByteArray(data, 0, data.length);
    }

    /**
     * Convert Image to JPEG byte array
     *
     * @param image
     * @return
     */
    private static byte[] imageToByteArray(Image image) {
        byte[] data = null;
        if (image.getFormat() == ImageFormat.JPEG) {
            Image.Plane[] planes = image.getPlanes();
            ByteBuffer buffer = planes[0].getBuffer();
            data = new byte[buffer.capacity()];
            buffer.get(data);
            return data;
        } else if (image.getFormat() == ImageFormat.YUV_420_888) {
            data = NV21toJPEG(YUV_420_888toNV21(image),
                    image.getWidth(), image.getHeight());
        }
        return data;
    }

    /**
     * Convert YUV420_888 Image to NV21 byte array
     *
     * @param image
     * @return
     */
    private static byte[] YUV_420_888toNV21(Image image) {
        byte[] nv21;
        ByteBuffer yBuffer = image.getPlanes()[0].getBuffer();
        ByteBuffer uBuffer = image.getPlanes()[1].getBuffer();
        ByteBuffer vBuffer = image.getPlanes()[2].getBuffer();
        int ySize = yBuffer.remaining();
        int uSize = uBuffer.remaining();
        int vSize = vBuffer.remaining();
        nv21 = new byte[ySize + uSize + vSize];
        yBuffer.get(nv21, 0, ySize);
        vBuffer.get(nv21, ySize, vSize);
        uBuffer.get(nv21, ySize + vSize, uSize);
        return nv21;
    }

    /**
     * Convert NV21 byte array to JPEG
     *
     * @param nv21
     * @param width
     * @param height
     * @return
     */
    private static byte[] NV21toJPEG(byte[] nv21, int width, int height) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        YuvImage yuv = new YuvImage(nv21, ImageFormat.NV21, width, height, null);
        yuv.compressToJpeg(new Rect(0, 0, width, height), 100, out);
        return out.toByteArray();
    }
}
