class LocalModelInfo {
  const LocalModelInfo({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  factory LocalModelInfo.fromMap(Map<String, Object?> map) {
    final path = (map['path'] as String? ?? '').trim();
    final name = (map['name'] as String? ?? '').trim();
    final size = map['sizeBytes'];
    return LocalModelInfo(
      path: path,
      name: name.isEmpty ? _basename(path) : name,
      sizeBytes: size is num ? size.toInt() : 0,
    );
  }

  final String path;
  final String name;
  final int sizeBytes;

  @override
  bool operator ==(Object other) {
    return other is LocalModelInfo &&
        other.path == path &&
        other.name == name &&
        other.sizeBytes == sizeBytes;
  }

  @override
  int get hashCode => Object.hash(path, name, sizeBytes);

  static String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    if (slash < 0) return normalized;
    return normalized.substring(slash + 1);
  }
}
