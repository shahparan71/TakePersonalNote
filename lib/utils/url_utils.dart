import 'package:url_launcher/url_launcher.dart';

enum SocialPlatform {
  facebook,
  youtube,
  instagram,
  whatsapp,
  tiktok,
  telegram,
  messenger,
  wechat,
  other,
}

class UrlUtils {
  /// Identifies the social platform from a URL.
  static SocialPlatform identifyPlatform(String url) {
    try {
      final host = Uri.parse(url).host.toLowerCase();
      
      if (host.contains('facebook.com') || host.contains('fb.com') || host.contains('fb.me')) {
        return SocialPlatform.facebook;
      } else if (host.contains('youtube.com') || host.contains('youtu.be')) {
        return SocialPlatform.youtube;
      } else if (host.contains('instagram.com') || host.contains('instagr.am')) {
        return SocialPlatform.instagram;
      } else if (host.contains('whatsapp.com') || host.contains('wa.me')) {
        return SocialPlatform.whatsapp;
      } else if (host.contains('tiktok.com')) {
        return SocialPlatform.tiktok;
      } else if (host.contains('t.me') || host.contains('telegram.org') || host.contains('telegram.me')) {
        return SocialPlatform.telegram;
      } else if (host.contains('messenger.com') || host.contains('m.me')) {
        return SocialPlatform.messenger;
      } else if (host.contains('wechat.com') || host.contains('weixin.qq.com')) {
        return SocialPlatform.wechat;
      }
    } catch (_) {}
    return SocialPlatform.other;
  }

  /// Opens the URL using the appropriate app or browser based on its platform.
  static Future<void> openUrl(String rawUrl) async {
    final normalized = rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl';
    final uri = Uri.parse(normalized);

    final platform = identifyPlatform(normalized);

    Uri? appUri;
    switch (platform) {
      case SocialPlatform.facebook:
        appUri = Uri.parse('fb://facewebmodal/f?href=${Uri.encodeComponent(normalized)}');
        break;
      case SocialPlatform.youtube:
        appUri = Uri.parse(normalized.replaceFirst(RegExp(r'^https?://'), 'vnd.youtube://'));
        break;
      case SocialPlatform.instagram:
        appUri = Uri.parse('instagram://url?url=${Uri.encodeComponent(normalized)}');
        break;
      case SocialPlatform.whatsapp:
        // wa.me urls usually open fine via intent directly, but we can try whatsapp://send?text=
        break;
      case SocialPlatform.tiktok:
        appUri = Uri.parse('snssdk1128://open?url=${Uri.encodeComponent(normalized)}');
        break;
      case SocialPlatform.telegram:
        appUri = Uri.parse(normalized.replaceFirst(RegExp(r'^https?://(t\.me|telegram\.me|telegram\.org)/'), 'tg://resolve?domain='));
        break;
      case SocialPlatform.messenger:
        appUri = Uri.parse('fb-messenger://share?link=${Uri.encodeComponent(normalized)}');
        break;
      case SocialPlatform.wechat:
        appUri = Uri.parse('weixin://');
        break;
      case SocialPlatform.other:
        break;
    }

    if (appUri != null && await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
      return;
    }

    // Fallback: open in default browser.
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
