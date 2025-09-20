/**
 * Copyright (c) 2022 Asial Corporation. All rights reserved.
 */
const monaca = function () {};
const BarcodeScanner = function () {};

/**
 * Scan barcode with optional configuration
 * @param {function} success - Success callback function
 * @param {function} fail - Error callback function  
 * @param {object} config - Optional configuration object
 * @param {object} config.detectionArea - Detection area configuration (width, height in density-independent units: Android=dp, iOS=pt)
 */
BarcodeScanner.prototype.scan = function(success, fail, config) {
  cordova.exec(success, fail, "MonacaBarcodeScannerPlugin", "scan", [config]);
};

monaca.BarcodeScanner = new BarcodeScanner();
module.exports = monaca.BarcodeScanner;
