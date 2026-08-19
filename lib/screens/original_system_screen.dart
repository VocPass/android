import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../config/school_config.dart';
import '../services/api_service.dart';

/// 前往原系統 - 將本地儲存的登入 Cookie 寫入 WebView 後開啟原系統首頁 (url.index)
class OriginalSystemScreen extends StatefulWidget {
  final SchoolConfig school;
  final String indexUrl;
  final List<AppCookie> cookies;

  const OriginalSystemScreen({
    super.key,
    required this.school,
    required this.indexUrl,
    required this.cookies,
  });

  @override
  State<OriginalSystemScreen> createState() => _OriginalSystemScreenState();
}

class _OriginalSystemScreenState extends State<OriginalSystemScreen> {
  InAppWebViewController? _controller;
  bool _isPreparing = true;
  String? _webViewUserAgent;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    await _syncCookies();
    final userAgent =
        await ApiService.instance.fetchWebViewUserAgent(widget.school);
    if (!mounted) return;
    setState(() {
      _webViewUserAgent = userAgent;
      _isPreparing = false;
    });
  }

  /// 將本地儲存的 Cookie 寫入 WebView 的 CookieManager
  Future<void> _syncCookies() async {
    final host = Uri.tryParse(widget.school.api)?.host ?? '';
    if (host.isEmpty || widget.cookies.isEmpty) return;

    final cookieManager = CookieManager.instance();
    final rootUrl = WebUri(widget.school.rootUrl);
    final expiresDate =
        DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;

    for (final cookie in widget.cookies) {
      if (cookie.name.isEmpty) continue;
      await cookieManager.setCookie(
        url: rootUrl,
        name: cookie.name,
        value: cookie.value,
        domain: host,
        path: '/',
        isSecure: rootUrl.scheme == 'https',
        expiresDate: expiresDate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.school.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller?.reload(),
          ),
        ],
      ),
      body: _isPreparing
          ? const Center(child: CircularProgressIndicator())
          : InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.indexUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                userAgent: _webViewUserAgent,
              ),
              onWebViewCreated: (controller) => _controller = controller,
            ),
    );
  }
}
