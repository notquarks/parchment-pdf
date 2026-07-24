# qpdf_optimizer

Local Dart native-assets package for structural PDF optimization with qpdf.

Supported targets are Windows and Android.

## API

```dart
final result = await const QpdfOptimizer().optimize(
  inputPath: inputPath,
  outputPath: outputPath,
  options: const QpdfOptimizerOptions(
    mode: QpdfCompressionMode.imageOptimized,
    jpegQuality: 70,
    targetDpi: 140,
    dpiThreshold: 175,
    downsampleImages: true,
  ),
);
```

The package exposes one unversioned optimization method. Native compatibility
is tracked separately through `QPDF_OPTIMIZER_ABI_VERSION` and the size/version
fields in the C option and result structs.

The result returned by `qpdf_optimizer_run` is owned by its job and remains
valid until the next run or `qpdf_optimizer_destroy_job`. Analysis error
messages returned separately by the C API must be released with
`qpdf_optimizer_free_string`.
