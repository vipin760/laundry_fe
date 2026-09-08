import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/account_deletion_api.dart';
import '../models/delete_account_models.dart';

/// Steps in the deletion flow (drives the UI).
/// [pendingApproval] is the terminal state of the iOS admin-approval flow:
/// the request was submitted and is awaiting an admin decision.
enum DeleteStep { idle, requested, verified, deleting, done, error, pendingApproval }

/// Backend-owned deletion-request status for the current user. Consumed by the
/// Profile row and the iOS delete screen so the "pending" state survives app
/// restarts / re-login / device changes instead of living only in memory.
final deleteRequestStatusProvider =
    FutureProvider.autoDispose<DeleteRequestStatusResult>((ref) async {
  return const AccountDeletionApi().status();
});

class DeleteAccountState {
  const DeleteAccountState({
    this.step = DeleteStep.idle,
    this.reason,
    this.comment = '',
    this.deleteRequestId,
    this.verificationToken,
    this.verificationRequired = false,
    this.isBusy = false,
    this.error,
    this.successMessage,
  });

  final DeleteStep step;
  final DeleteReason? reason;
  final String comment;
  final String? deleteRequestId;
  final String? verificationToken;
  final bool verificationRequired;
  final bool isBusy;
  final String? error;
  final String? successMessage;

  DeleteAccountState copyWith({
    DeleteStep? step,
    DeleteReason? reason,
    String? comment,
    String? deleteRequestId,
    String? verificationToken,
    bool? verificationRequired,
    bool? isBusy,
    String? error,
    String? successMessage,
    bool clearError = false,
  }) {
    return DeleteAccountState(
      step: step ?? this.step,
      reason: reason ?? this.reason,
      comment: comment ?? this.comment,
      deleteRequestId: deleteRequestId ?? this.deleteRequestId,
      verificationToken: verificationToken ?? this.verificationToken,
      verificationRequired: verificationRequired ?? this.verificationRequired,
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : (error ?? this.error),
      successMessage: successMessage ?? this.successMessage,
    );
  }
}

class DeleteAccountNotifier extends Notifier<DeleteAccountState> {
  final _api = const AccountDeletionApi();

  @override
  DeleteAccountState build() => const DeleteAccountState();

  void setReason(DeleteReason reason) =>
      state = state.copyWith(reason: reason, clearError: true);

  void setComment(String comment) => state = state.copyWith(comment: comment);

  /// Step 1 — create the deletion request.
  Future<bool> submitRequest() async {
    if (state.reason == null) {
      state = state.copyWith(error: 'Please choose a reason');
      return false;
    }
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final result = await _api.request(
        reason: state.reason!,
        comment: state.comment,
      );
      state = state.copyWith(
        isBusy: false,
        step: DeleteStep.requested,
        deleteRequestId: result.deleteRequestId,
        verificationRequired: result.verificationRequired,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isBusy: false, error: _msg(e));
      return false;
    }
  }

  /// iOS admin-approval flow — submit the request and stop. The account is NOT
  /// deleted here; an admin reviews and approves later. Guards against
  /// duplicate submissions from rapid taps ([isBusy]) and reports an
  /// already-pending request as success so the UI moves straight to the
  /// pending state.
  Future<bool> submitApprovalRequest() async {
    if (state.isBusy) return false;
    if (state.reason == null) {
      state = state.copyWith(error: 'Please choose a reason');
      return false;
    }
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final result = await _api.request(
        reason: state.reason!,
        comment: state.comment,
        flow: 'admin_approval',
      );
      state = state.copyWith(
        isBusy: false,
        step: DeleteStep.pendingApproval,
        deleteRequestId: result.deleteRequestId,
      );
      return true;
    } catch (e) {
      // An existing pending request comes back as 409 — treat it as "already
      // submitted" and surface the pending state rather than an error.
      if (e is DioException && e.response?.statusCode == 409) {
        state = state.copyWith(isBusy: false, step: DeleteStep.pendingApproval);
        return true;
      }
      state = state.copyWith(isBusy: false, error: _msg(e));
      return false;
    }
  }

  /// Send an OTP for OTP-based verification.
  Future<bool> sendOtp() async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _api.sendOtp();
      state = state.copyWith(isBusy: false);
      return true;
    } catch (e) {
      state = state.copyWith(isBusy: false, error: _msg(e));
      return false;
    }
  }

  /// Step 2 — verify identity (password or OTP).
  Future<bool> verify({
    required VerificationMethod method,
    String? password,
    String? otp,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final result = await _api.verify(
        method: method,
        password: password,
        otp: otp,
      );
      state = state.copyWith(
        isBusy: false,
        step: DeleteStep.verified,
        verificationToken: result.verificationToken,
      );
      return result.verified;
    } catch (e) {
      state = state.copyWith(isBusy: false, error: _msg(e));
      return false;
    }
  }

  /// Step 3 — final confirmation (irreversible).
  /// [verificationToken] is only present when re-verification is enabled.
  Future<bool> confirm() async {
    state = state.copyWith(isBusy: true, step: DeleteStep.deleting, clearError: true);
    try {
      final message = await _api.confirm(state.verificationToken);
      state = state.copyWith(
        isBusy: false,
        step: DeleteStep.done,
        successMessage: message,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        step: DeleteStep.error,
        error: _msg(e),
      );
      return false;
    }
  }

  void reset() => state = const DeleteAccountState();

  /// Turn any thrown error into a short, user-safe sentence — never a raw
  /// backend payload or stack trace. Prefers the backend's own `message`.
  String _msg(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final m = data['message'];
        if (m is String && m.trim().isNotEmpty) return m.trim();
        if (m is List && m.isNotEmpty) return m.map((x) => '$x').join('. ');
      }
      switch (e.response?.statusCode) {
        case 401:
          return 'Your session has expired. Please log in again.';
        case 409:
          return 'A deletion request is already in progress.';
        case 429:
          return 'Too many attempts. Please wait a moment and try again.';
      }
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return 'Network problem. Check your connection and try again.';
        default:
          return 'Something went wrong. Please try again.';
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}

final deleteAccountProvider =
    NotifierProvider<DeleteAccountNotifier, DeleteAccountState>(
  DeleteAccountNotifier.new,
);
