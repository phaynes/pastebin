# BarcodeScanner

A small native macOS camera app for reading a visible barcode and returning the URL encoded in it.

The app uses the Mac camera through `AVFoundation` and decodes frames with Apple Vision barcode detection. It is aimed at URL payloads in QR-style codes, and also uses Vision-supported common formats such as Aztec, Data Matrix, PDF417, EAN, UPC, Code 39, Code 93, Code 128, ITF-14, and Interleaved 2 of 5.

## Build

```sh
git clone https://github.com/phaynes/pastebin.git
cd pastebin/barcode-scanner-macos
make app
```

The app bundle will be created at:

```text
build/BarcodeScanner.app
```

## Run

```sh
make run
```

macOS will ask for camera permission the first time the app opens. If permission is denied, enable it under System Settings -> Privacy & Security -> Camera.

## Notes

- HTTP and HTTPS payloads are returned directly.
- Bare domains such as `example.com/path` are normalized to `https://example.com/path`.
- Non-URL barcode payloads are shown as raw text so they can still be copied.
- If "3D barcode" means a proprietary depth/shape-based code rather than a camera-visible QR/Data Matrix/PDF417-style mark, this app will need a format-specific decoder.
