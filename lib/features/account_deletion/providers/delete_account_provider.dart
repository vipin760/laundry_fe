import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/account_deletion_api.dart';
import '../models/delete_account_models.dart';

/// Steps in the deletion flow (drives the UI).
enum DeleteStep { idle, requested, verified, deleting, done, error }

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

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');
}

final deleteAccountProvider =
    NotifierProvider<DeleteAccountNotifier, DeleteAccountState>(
  DeleteAccountNotifier.new,
);
