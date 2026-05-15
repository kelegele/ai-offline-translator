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
    this.selectedPath,
    this.displayName,
    this.errorMessage,
  });

  final ModelLifecycleStatus status;
  final String? selectedPath;
  final String? displayName;
  final String? errorMessage;

  bool get hasSelection =>
      selectedPath != null && selectedPath!.trim().isNotEmpty;
  bool get isReady => status == ModelLifecycleStatus.ready;

  ModelSelectionState copyWith({
    ModelLifecycleStatus? status,
    String? selectedPath,
    String? displayName,
    String? errorMessage,
    bool clearSelection = false,
    bool clearError = false,
  }) {
    return ModelSelectionState(
      status: status ?? this.status,
      selectedPath: clearSelection ? null : selectedPath ?? this.selectedPath,
      displayName: clearSelection ? null : displayName ?? this.displayName,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
