import 'package:url_launcher/url_launcher.dart';

abstract final class PushlogLinks {
  static final Uri website = Uri.https('pushlog.iamngoni.dev', '/');
  static final Uri privacy = Uri.https('pushlog.iamngoni.dev', '/privacy/');
  static final Uri terms = Uri.https('pushlog.iamngoni.dev', '/terms/');
  static final Uri deleteAccount = Uri.https(
    'pushlog.iamngoni.dev',
    '/delete-account/',
  );
}

Future<bool> openPushlogLink(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
