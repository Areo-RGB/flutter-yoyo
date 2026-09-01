/// Typed representation of user-visible remote messages.
///
/// Raw strings are still rendered at the UI edge; this keeps copy
/// out of the view-model state machine and makes message behaviour testable.
sealed class RemoteUiMessage {
  const RemoteUiMessage();
  String toDisplayString();
}

class RemoteInfo extends RemoteUiMessage {
  final String text;
  const RemoteInfo(this.text);
  @override
  String toDisplayString() => text;
}

class RemoteCommandApplied extends RemoteUiMessage {
  const RemoteCommandApplied();
  @override
  String toDisplayString() => 'Command applied by tablet.';
}

class RemoteCommandRejected extends RemoteUiMessage {
  final String reason;
  const RemoteCommandRejected(this.reason);
  @override
  String toDisplayString() =>
      'Tablet rejected command: ${reason.replaceAll('_', ' ')}.';
}

class RemoteConnectionLost extends RemoteUiMessage {
  const RemoteConnectionLost();
  @override
  String toDisplayString() => 'Connection lost. Reconnecting…';
}

class RemoteCommandTimeout extends RemoteUiMessage {
  const RemoteCommandTimeout();
  @override
  String toDisplayString() =>
      'Tablet did not respond. Check connection and retry.';
}

String remoteMessageText(RemoteUiMessage? message) =>
    message?.toDisplayString() ?? '';
