class SupportedModelInfo {
  const SupportedModelInfo({
    required this.id,
    required this.displayName,
    required this.filename,
    required this.downloadUrl,
    required this.expectedSizeLabel,
  });

  final String id;
  final String displayName;
  final String filename;
  final String downloadUrl;
  final String expectedSizeLabel;
}

const supportedTranslatorModels = <SupportedModelInfo>[
  SupportedModelInfo(
    id: 'hymt2_18b_125bit',
    displayName: 'Hy-MT2 1.8B 1.25bit',
    filename: 'Hy-MT2-1.8B-1.25Bit.gguf',
    downloadUrl:
        'https://hf-mirror.com/tencent/Hy-MT2-1.8B-1.25Bit-GGUF/resolve/main/Hy-MT2-1.8B-1.25Bit.gguf',
    expectedSizeLabel: '440 MB',
  ),
];
