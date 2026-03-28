import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ToastType { success, error, warning, info }

class ToastMessage {
  const ToastMessage({
    required this.id,
    required this.message,
    required this.type,
    required this.duration,
  });

  final String id;
  final String message;
  final ToastType type;
  final Duration duration;
}

class UiState {
  const UiState({
    required this.toasts,
    this.activeModal,
    this.modalData,
    required this.globalLoading,
    this.loadingMessage,
    required this.isSidebarOpen,
  });

  final List<ToastMessage> toasts;
  final String? activeModal;
  final Map<String, dynamic>? modalData;
  final bool globalLoading;
  final String? loadingMessage;
  final bool isSidebarOpen;

  factory UiState.initial() => const UiState(
        toasts: <ToastMessage>[],
        globalLoading: false,
        isSidebarOpen: false,
      );

  UiState copyWith({
    List<ToastMessage>? toasts,
    String? activeModal,
    Map<String, dynamic>? modalData,
    bool? globalLoading,
    String? loadingMessage,
    bool? isSidebarOpen,
    bool clearModal = false,
    bool clearLoadingMessage = false,
  }) {
    return UiState(
      toasts: toasts ?? this.toasts,
      activeModal: clearModal ? null : (activeModal ?? this.activeModal),
      modalData: clearModal ? null : (modalData ?? this.modalData),
      globalLoading: globalLoading ?? this.globalLoading,
      loadingMessage: clearLoadingMessage
          ? null
          : (loadingMessage ?? this.loadingMessage),
      isSidebarOpen: isSidebarOpen ?? this.isSidebarOpen,
    );
  }
}

class UiNotifier extends Notifier<UiState> {
  @override
  UiState build() => UiState.initial();

  void showToast(
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final String id =
        '${DateTime.now().millisecondsSinceEpoch}_${message.hashCode}';
    final ToastMessage toast = ToastMessage(
      id: id,
      message: message,
      type: type,
      duration: duration,
    );

    state = state.copyWith(
      toasts: <ToastMessage>[...state.toasts, toast],
    );
  }

  void removeToast(String id) {
    state = state.copyWith(
      toasts: state.toasts.where((t) => t.id != id).toList(),
    );
  }

  void openModal(String modalId, {Map<String, dynamic>? data}) {
    state = state.copyWith(activeModal: modalId, modalData: data);
  }

  void closeModal() {
    state = state.copyWith(clearModal: true);
  }

  void setGlobalLoading({required bool loading, String? message}) {
    if (!loading) {
      state = state.copyWith(
        globalLoading: false,
        clearLoadingMessage: true,
      );
    } else {
      state = state.copyWith(
        globalLoading: true,
        loadingMessage: message,
      );
    }
  }

  void toggleSidebar() {
    state = state.copyWith(isSidebarOpen: !state.isSidebarOpen);
  }
}

final NotifierProvider<UiNotifier, UiState> uiProvider =
    NotifierProvider<UiNotifier, UiState>(UiNotifier.new);
