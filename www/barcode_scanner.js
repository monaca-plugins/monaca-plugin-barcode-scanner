/**
 * Copyright (c) 2022 Asial Corporation. All rights reserved.
 */
 const monaca = function () {};
const BarcodeScanner = function () {};

BarcodeScanner.prototype.scan = function(success, fail, config) {
  cordova.exec(success, fail, "MonacaBarcodeScannerPlugin", "scan", [config]);
};

monaca.BarcodeScanner = new BarcodeScanner();
module.exports = monaca.BarcodeScanner;
