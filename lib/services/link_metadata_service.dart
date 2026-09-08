import 'package:dio/dio.dart';
import '../utils/entity_parser.dart';

/// Represents parsed web page metadata for rich link previews.
class LinkMetadata {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;
  final String? faviconUrl;

  const LinkMetadata({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    this.faviconUrl,
  });
}

/// Service for fetching and caching website metadata (Open Graph image, title, description).
class LinkMetadataService {
  LinkMetadataService._();
  static final LinkMetadataService instance = LinkMetadataService._();

  final Map<String, LinkMetadata> _cache = {};
  final Map<String, Future<LinkMetadata?>> _inFlight = {};

  LinkMetadata? getCached(String url) {
    final clean = EntityParser.cleanUrl(url);
    return _cache[clean];
  }

  Future<LinkMetadata?> fetchMetadata(String rawUrl) async {
    final cleanUrl = EntityParser.cleanUrl(rawUrl);
    if (cleanUrl.isEmpty) return null;

    if (_cache.containsKey(cleanUrl)) {
      return _cache[cleanUrl];
    }

    if (_inFlight.containsKey(cleanUrl)) {
      return _inFlight[cleanUrl];
    }

    final future = _fetch(cleanUrl);
    _inFlight[cleanUrl] = future;
    try {
      final res = await future;
      if (res != null) {
        _cache[cleanUrl] = res;
      }
      return res;
    } finally {
      _inFlight.remove(cleanUrl);
    }
  }

  Future<LinkMetadata?> _fetch(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return null;
      }

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 MiptgramBot/1.0',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
          responseType: ResponseType.plain,
        ),
      );

      final response = await dio.get<String>(url);
      if (response.statusCode != 200 || response.data == null) {
        return null;
      }

      final html = response.data!;
      return _parseHtml(html, uri);
    } catch (_) {
      return null;
    }
  }

  LinkMetadata _parseHtml(String html, Uri baseUri) {
    final headMatch = RegExp(r'<head[^>]*>([\s\S]*?)<\/head>', caseSensitive: false).firstMatch(html);
    final contentToScan = headMatch?.group(1) ?? html.substring(0, html.length.clamp(0, 15000));

    String? ogImage = _extractMeta(contentToScan, 'og:image') ??
        _extractMeta(contentToScan, 'twitter:image') ??
        _extractMeta(contentToScan, 'twitter:image:src');

    String? ogTitle = _extractMeta(contentToScan, 'og:title') ??
        _extractMeta(contentToScan, 'twitter:title') ??
        _extractTitle(contentToScan);

    String? ogDesc = _extractMeta(contentToScan, 'og:description') ??
        _extractMeta(contentToScan, 'twitter:description') ??
        _extractMeta(contentToScan, 'description');

    String? siteName = _extractMeta(contentToScan, 'og:site_name');

    String? favicon = _extractFavicon(contentToScan);

    if (ogImage != null && ogImage.isNotEmpty) {
      ogImage = _resolveUrl(ogImage, baseUri);
    }
    if (favicon != null && favicon.isNotEmpty) {
      favicon = _resolveUrl(favicon, baseUri);
    }

    return LinkMetadata(
      url: baseUri.toString(),
      title: _decodeHtml(ogTitle?.trim()),
      description: _decodeHtml(ogDesc?.trim()),
      imageUrl: ogImage,
      siteName: _decodeHtml(siteName?.trim()),
      faviconUrl: favicon,
    );
  }

  String? _extractMeta(String html, String name) {
    final pattern1 = RegExp(
      '''<meta\\s+[^>]*?(?:property|name)=["']${RegExp.escape(name)}["'][^>]*?content=["']([^"']+)["']''',
      caseSensitive: false,
    );
    final match1 = pattern1.firstMatch(html);
    if (match1 != null) return match1.group(1);

    final pattern2 = RegExp(
      '''<meta\\s+[^>]*?content=["']([^"']+)["'][^>]*?(?:property|name)=["']${RegExp.escape(name)}["']''',
      caseSensitive: false,
    );
    final match2 = pattern2.firstMatch(html);
    if (match2 != null) return match2.group(1);

    return null;
  }

  String? _extractTitle(String html) {
    final match = RegExp(r'<title[^>]*>([^<]+)<\/title>', caseSensitive: false).firstMatch(html);
    return match?.group(1);
  }

  String? _extractFavicon(String html) {
    final pattern = RegExp(
      r'<link\s+[^>]*?rel=["' r'](?:shortcut\s+)?icon["' r'][^>]*?href=["' r']([^"' r']+)["' r']',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(html);
    if (match != null) return match.group(1);

    final pattern2 = RegExp(
      r'<link\s+[^>]*?href=["' r']([^"' r']+)["' r'][^>]*?rel=["' r'](?:shortcut\s+)?icon["' r']',
      caseSensitive: false,
    );
    final match2 = pattern2.firstMatch(html);
    return match2?.group(1);
  }

  String _resolveUrl(String relativeOrAbsolute, Uri base) {
    try {
      final trimmed = relativeOrAbsolute.trim();
      if (trimmed.startsWith('//')) {
        return '${base.scheme}:$trimmed';
      }
      return base.resolve(trimmed).toString();
    } catch (_) {
      return relativeOrAbsolute;
    }
  }

  String? _decodeHtml(String? text) {
    if (text == null) return null;
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
  }
}
