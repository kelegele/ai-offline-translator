enum ModelDownloadStatus { idle, downloading, completed, cancelled, failed }

class ModelDownloadState {
  const ModelDownloadState({
    this.status = ModelDownloadStatus.idle,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.message = '',
    this.path,
  });

  final ModelDownloadStatus status;
  final int receivedBytes;
  final int totalBytes;
  final String message;
  final String? path;

  bool get isDownloading => status == ModelDownloadStatus.downloading;

  String get progressLabel {
    if (totalBytes <= 0) {
      return receivedBytes <= 0 ? message : '正在下载：${_formatBytes(receivedBytes)}';
    }
    return '正在下载：${_formatBytes(receivedBytes)} / ${_formatBytes(totalBytes)}';
  }

  ModelDownloadState copyWith({
    ModelDownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    String? message,
    String? path,
    bool clearPath = false,
  }) {
    return ModelDownloadState(
      status: status ?? this.status,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      message: message ?? this.message,
      path: clearPath ? null : path ?? this.path,
    );
  }

  static String _formatBytes(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb >= 100) {
      return '${mb.toStringAsFixed(0)} MB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }
}
