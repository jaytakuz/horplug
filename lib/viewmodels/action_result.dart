/// Result of a one-shot ViewModel action (e.g. a save or a service call)
/// that a View needs to react to with a SnackBar/dialog dismissal.
class ActionResult {
  const ActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}
