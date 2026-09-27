import 'dart:convert';

/// Adds the owner's weight entries to the workout export.
///
/// The workout snapshot keys stay at the top level, as they were before
/// weight existed, so an older reader of the export still finds them.
String mergeWeightExport(
  String workoutJson,
  List<Map<String, dynamic>> weightEntries,
) {
  final decoded = jsonDecode(workoutJson);
  final payload = decoded is Map<String, dynamic>
      ? decoded
      : <String, dynamic>{'workout': decoded};
  payload['weightEntries'] = weightEntries;
  return const JsonEncoder.withIndent('  ').convert(payload);
}
