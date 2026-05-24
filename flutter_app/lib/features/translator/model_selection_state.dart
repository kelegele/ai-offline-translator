import 'local_model_info.dart';
import 'supported_model_info.dart';

enum ModelLifecycleStatus {
  noneSelected,
  selected,
  loading,
  ready,
  unloading,
  failed,
}

class ModelSelectionState {
  const ModelSelectionState({
    this.status = ModelLifecycleStatus.noneSelected,
    this.availableModels = const [],
    this.supportedModels = supportedTranslatorModels,
    this.selectedPath,
    this.loadedPath,
    this.displayName,
    this.downloadingModelId,
    this.errorMessage,
  });

  final ModelLifecycleStatus status;
  final List<LocalModelInfo> availableModels;
  final List<SupportedModelInfo> supportedModels;
  final String? selectedPath;
  final String? loadedPath;
  final String? displayName;
  final String? downloadingModelId;
  final String? errorMessage;

  bool get hasSelection =>
      selectedPath != null && selectedPath!.trim().isNotEmpty;
  bool get isReady => status == ModelLifecycleStatus.ready;
  bool get isLoadedSelection =>
      hasSelection && loadedPath != null && loadedPath == selectedPath;

  ModelSelectionState copyWith({
    ModelLifecycleStatus? status,
    List<LocalModelInfo>? availableModels,
    List<SupportedModelInfo>? supportedModels,
    String? selectedPath,
    String? loadedPath,
    String? displayName,
    String? downloadingModelId,
    String? errorMessage,
    bool clearSelection = false,
    bool clearLoadedPath = false,
    bool clearDownloadingModel = false,
    bool clearError = false,
  }) {
    return ModelSelectionState(
      status: status ?? this.status,
      availableModels: availableModels ?? this.availableModels,
      supportedModels: supportedModels ?? this.supportedModels,
      selectedPath: clearSelection ? null : selectedPath ?? this.selectedPath,
      loadedPath: clearLoadedPath ? null : loadedPath ?? this.loadedPath,
      displayName: clearSelection ? null : displayName ?? this.displayName,
      downloadingModelId: clearDownloadingModel
          ? null
          : downloadingModelId ?? this.downloadingModelId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
