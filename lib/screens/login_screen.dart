import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../config/school_config.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/school_config_manager.dart';
import '../widgets/captcha_indicator.dart';

class LoginScreen extends StatefulWidget {
  final SchoolConfig school;
  final Uri targetUrl;

  const LoginScreen({super.key, required this.school, required this.targetUrl});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  InAppWebViewController? _controller;
  bool _isLoggingIn = false;
  bool _isCaptchaRecognizing = false;
  String? _lastCaptcha;
  bool _hasLoggedIn = false;
  bool _isCheckingLoginState = false;
  int? _lastContentHash;
  final List<String> _visitedUrls = [];

  List<String> get _loginKeywords {
    final fromApi = widget.school.login.successKeywords
            ?.where((e) => e.trim().isNotEmpty)
            .toList() ??
        [];
    if (fromApi.isNotEmpty) return fromApi;
    return const ['登出', 'logout'];
  }

  void _recordUrl(String url) {
    if (url.isEmpty || _visitedUrls.contains(url)) return;
    _visitedUrls.add(url);
  }

  @override
  Widget build(BuildContext context) {
    final apiService = context.read<ApiService>();
    final cache = context.read<CacheService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.school.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            SchoolConfigManager.instance.clearSelectedSchool();
            apiService.logout();
          },
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest:
                URLRequest(url: WebUri(widget.targetUrl.toString())),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
            ),
            initialUserScripts: UnmodifiableListView([
              UserScript(
                source: _buildUrlTrackingScript(),
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                forMainFrameOnly: false,
              ),
              UserScript(
                source: _buildInjectedScript(cache),
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                forMainFrameOnly: true,
              ),
            ]),
            onWebViewCreated: (controller) {
              _controller = controller;
              controller.addJavaScriptHandler(
                handlerName: 'formSubmit',
                callback: (_) {
                  setState(() => _isLoggingIn = true);
                },
              );
              controller.addJavaScriptHandler(
                handlerName: 'saveCredentials',
                callback: (args) {
                  if (args.isEmpty || args.first is! Map) return;
                  final map = (args.first as Map).cast<String, dynamic>();
                  final username = map['username']?.toString() ?? '';
                  final password = map['password']?.toString() ?? '';
                  if (username.isNotEmpty || password.isNotEmpty) {
                    cache.saveLoginCredentials(
                      username: username,
                      password: password,
                      schoolCode: null,
                    );
                  }
                },
              );
              controller.addJavaScriptHandler(
                handlerName: 'recognizeCaptcha',
                callback: (args) async {
                  if (args.isEmpty || args.first is! Map) return;
                  final map = (args.first as Map).cast<String, dynamic>();
                  final selector = map['selector']?.toString() ?? 'captcha';
                  await _recognizeCaptcha(selector);
                },
              );
              controller.addJavaScriptHandler(
                handlerName: 'urlTracking',
                callback: (args) {
                  if (args.isEmpty) return;
                  final url = args.first?.toString() ?? '';
                  if (url.isNotEmpty) _recordUrl(url);
                },
              );
            },
            onLoadStart: (controller, url) {
              final currentUrl = url?.toString().toLowerCase() ?? '';
              final loginPath = widget.school.url.login.toLowerCase();
              if (!currentUrl.contains(loginPath) && !_hasLoggedIn) {
                setState(() => _isLoggingIn = true);
              }
              if (url != null) _recordUrl(url.toString());
            },
            onLoadStop: (controller, url) {
              if (url != null) _recordUrl(url.toString());
              _injectCustomJsIfNeeded();
              _startContinuousDetection(url?.toString() ?? '');
            },
            onLoadError: (_, __, ___, ____) {
              setState(() => _isLoggingIn = false);
            },
          ),
          if (_isLoggingIn)
            const Positioned(
              top: 12,
              right: 12,
              child: Chip(
                avatar: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                label: Text('登入中...'),
              ),
            ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: CaptchaIndicator(
                isRecognizing: _isCaptchaRecognizing,
                lastText: _lastCaptcha,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildUrlTrackingScript() {
    return '''
(function() {
  function trackURL(url) {
    if (!url || typeof url !== 'string') return;
    try {
      var absolute = new URL(url, window.location.href).href;
      window.flutter_inappwebview.callHandler('urlTracking', absolute);
    } catch(e) {
      window.flutter_inappwebview.callHandler('urlTracking', url);
    }
  }

  var originalFetch = window.fetch;
  window.fetch = function(input, init) {
    var url = (typeof input === 'string') ? input : (input && input.url) ? input.url : String(input);
    trackURL(url);
    return originalFetch.apply(this, arguments);
  };

  var originalOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url) {
    trackURL(String(url));
    return originalOpen.apply(this, arguments);
  };
})();
''';
  }

  String _buildInjectedScript(CacheService cache) {
    final username = _escapeJs(cache.savedUsername ?? '');
    final password = _escapeJs(cache.savedPassword ?? '');
    final usernameField = _escapeJs(widget.school.login.username.name);
    final passwordField = _escapeJs(widget.school.login.password.name);
    final captchaField = _escapeJs(widget.school.login.captcha.name);
    final buttonClass = _escapeJs(widget.school.login.button.cssClass);
    final captchaSelector = _escapeJs(
      widget.school.login.captchaImage?.selector.isNotEmpty == true
          ? widget.school.login.captchaImage!.selector
          : 'captcha',
    );

    return '''
(function() {
  var savedUsername = '$username';
  var savedPassword = '$password';
  var usernameFieldName = '$usernameField';
  var passwordFieldName = '$passwordField';
  var captchaFieldName = '$captchaField';
  var captchaImageSelector = '$captchaSelector';
  var hasTriggeredCaptchaRecognition = false;

  function getNativeValueSetter(element) {
    var prototype = Object.getPrototypeOf(element);
    var descriptor = prototype ? Object.getOwnPropertyDescriptor(prototype, 'value') : null;
    return descriptor && descriptor.set ? descriptor.set : null;
  }

  function dispatchFieldEvents(field, previousValue) {
    field.dispatchEvent(new Event('input', { bubbles: true }));
    if (previousValue !== field.value) {
      field.dispatchEvent(new Event('change', { bubbles: true }));
    }
    field.dispatchEvent(new Event('blur', { bubbles: true }));
  }

  function fillField(field, newValue) {
    if (!field || !newValue) return false;
    var oldValue = field.value || '';
    field.focus();
    var setter = getNativeValueSetter(field);
    if (setter) {
      setter.call(field, '');
      field.dispatchEvent(new Event('input', { bubbles: true }));
      setter.call(field, newValue);
    } else {
      field.value = '';
      field.dispatchEvent(new Event('input', { bubbles: true }));
      field.value = newValue;
    }
    dispatchFieldEvents(field, oldValue);
    return true;
  }

  function fillCredentials() {
    var usernameEl = document.querySelector('input[name="' + usernameFieldName + '"]') ||
                     document.querySelector('input[id="' + usernameFieldName + '"]');
    if (usernameEl && savedUsername && !usernameEl.value) {
      fillField(usernameEl, savedUsername);
    }

    var passwordEl = document.querySelector('input[name="' + passwordFieldName + '"]') ||
                     document.querySelector('input[id="' + passwordFieldName + '"]');
    if (passwordEl && savedPassword && !passwordEl.value) {
      fillField(passwordEl, savedPassword);
    }

    var captchaEl = captchaFieldName
      ? (document.querySelector('input[name="' + captchaFieldName + '"]') ||
         document.querySelector('input[id="' + captchaFieldName + '"]'))
      : null;

    if (captchaEl && !captchaEl.value && !hasTriggeredCaptchaRecognition) {
      var captchaImage = document.querySelector('.' + captchaImageSelector) ||
        document.querySelector('#' + captchaImageSelector) ||
        document.querySelector('[name="' + captchaImageSelector + '"]') ||
        document.querySelector('img[alt*="captcha"]') ||
        document.querySelector('img[alt*="驗證"]') ||
        document.querySelector('img[src*="captcha"]') ||
        document.querySelector('img[src*="code"]');

      if (captchaImage) {
        hasTriggeredCaptchaRecognition = true;
        window.flutter_inappwebview.callHandler('recognizeCaptcha', {
          selector: captchaImageSelector,
          timestamp: Date.now()
        });
      }
    }
  }

  window.fillCaptchaCode = function(code) {
    var captchaEl = captchaFieldName
      ? (document.querySelector('input[name="' + captchaFieldName + '"]') ||
         document.querySelector('input[id="' + captchaFieldName + '"]'))
      : null;
    if (captchaEl) {
      fillField(captchaEl, code);
      return true;
    }
    return false;
  };

  if (document.readyState === 'complete') {
    fillCredentials();
  } else {
    window.addEventListener('load', fillCredentials);
  }
  setTimeout(fillCredentials, 500);
  setTimeout(fillCredentials, 1000);
  setTimeout(fillCredentials, 2000);
})();

document.addEventListener('click', function(e) {
  var target = e.target;
  var buttonClass = '$buttonClass';
  var usernameFieldName = '$usernameField';
  var passwordFieldName = '$passwordField';
  var captchaFieldName = '$captchaField';

  var isLoginButton = buttonClass
    ? (target.classList.contains(buttonClass) || target.closest('.' + buttonClass))
    : (target.matches('button, input[type="submit"]') || target.closest('button, input[type="submit"]'));

  if (isLoginButton) {
    var usernameField = document.querySelector('input[name="' + usernameFieldName + '"]') ||
                        document.querySelector('input[id="' + usernameFieldName + '"]');
    var passwordField = document.querySelector('input[name="' + passwordFieldName + '"]') ||
                        document.querySelector('input[id="' + passwordFieldName + '"]');
    var captchaField = captchaFieldName
      ? (document.querySelector('input[name="' + captchaFieldName + '"]') ||
         document.querySelector('input[id="' + captchaFieldName + '"]'))
      : null;

    var username = usernameField ? usernameField.value : '';
    var password = passwordField ? passwordField.value : '';
    var captcha = captchaField ? captchaField.value : '';

    if (captchaField && (!captcha || captcha.trim() === '')) {
      return;
    }

    if (username || password) {
      window.flutter_inappwebview.callHandler('saveCredentials', {
        username: username,
        password: password
      });
    }

    window.flutter_inappwebview.callHandler('formSubmit', 'login_clicked');
  }
}, true);

document.addEventListener('submit', function(e) {
  var form = e.target;
  var buttonClass = '$buttonClass';
  var usernameFieldName = '$usernameField';
  var passwordFieldName = '$passwordField';
  var captchaFieldName = '$captchaField';

  var loginBtn = buttonClass ? form.querySelector('.' + buttonClass) : form.querySelector('button[type="submit"], input[type="submit"]');
  if (!loginBtn) return;

  var usernameField = form.querySelector('input[name="' + usernameFieldName + '"]') ||
                      form.querySelector('input[id="' + usernameFieldName + '"]');
  var passwordField = form.querySelector('input[name="' + passwordFieldName + '"]') ||
                      form.querySelector('input[id="' + passwordFieldName + '"]');
  var captchaField = captchaFieldName
    ? (form.querySelector('input[name="' + captchaFieldName + '"]') ||
       form.querySelector('input[id="' + captchaFieldName + '"]'))
    : null;

  var username = usernameField ? usernameField.value : '';
  var password = passwordField ? passwordField.value : '';
  var captcha = captchaField ? captchaField.value : '';

  if (captchaField && (!captcha || captcha.trim() === '')) {
    return;
  }

  if (username || password) {
    window.flutter_inappwebview.callHandler('saveCredentials', {
      username: username,
      password: password
    });
  }

  window.flutter_inappwebview.callHandler('formSubmit', 'form_submitted');
}, true);
''';
  }

  void _injectCustomJsIfNeeded() {
    if (_hasLoggedIn) return;
    final customJs = widget.school.js;
    if (customJs == null || customJs.isEmpty) return;

    final wrapped = '''
(function() {
  try {
    if (sessionStorage.getItem('__vocpassCustomJsRan') === '1') return 'session_already';
  } catch (_) {}
  if (window.__vocpassCustomJsRan) return 'window_already';
  var __vp_tries = 0;
  var __vp_maxTries = 60;
  function __vp_markDone() {
    window.__vocpassCustomJsRan = true;
    try { sessionStorage.setItem('__vocpassCustomJsRan', '1'); } catch (_) {}
  }
  function __vp_run() {
    try {
      (function() { $customJs })();
      __vp_markDone();
      return 'ok';
    } catch (err) {
      __vp_tries++;
      if (__vp_tries < __vp_maxTries) {
        setTimeout(__vp_run, 250);
        return 'retry:' + err.message;
      }
      return 'giveup:' + err.message;
    }
  }
  return __vp_run();
})();
''';

    _controller?.evaluateJavascript(source: wrapped);
  }

  void _startContinuousDetection(String currentUrl) {
    if (_isCheckingLoginState) return;
    _isCheckingLoginState = true;
    _inspectLoginStatePeriodic(currentUrl);
  }

  Future<void> _inspectLoginStatePeriodic(String currentUrl) async {
    if (_controller == null || _hasLoggedIn) {
      _isCheckingLoginState = false;
      return;
    }

    final liveUrl = (await _controller!.getUrl())?.toString() ?? currentUrl;

    final result = await _controller!.evaluateJavascript(source: '''
(function() {
  var mainHtml = (document.documentElement && document.documentElement.outerHTML) ? document.documentElement.outerHTML : '';
  var mainText = (document.body && document.body.innerText) ? document.body.innerText : '';
  var iframeHtml = '';
  var iframeText = '';
  try {
    var frames = document.querySelectorAll('iframe, frame');
    for (var i = 0; i < frames.length; i++) {
      try {
        var frameDoc = frames[i].contentDocument || frames[i].contentWindow.document;
        if (frameDoc) {
          iframeHtml += frameDoc.documentElement ? frameDoc.documentElement.outerHTML : '';
          iframeText += frameDoc.body ? frameDoc.body.innerText : '';
        }
      } catch(e) {}
    }
  } catch(e) {}
  return {
    readyState: document.readyState || '',
    html: mainHtml + iframeHtml,
    text: mainText + iframeText
  };
})();
''');

    if (!mounted) {
      _isCheckingLoginState = false;
      return;
    }

    if (result is Map) {
      final readyState = (result['readyState'] ?? '').toString().toLowerCase();
      final html = (result['html'] ?? '').toString();
      final text = (result['text'] ?? '').toString();

      final contentHash = html.hashCode ^ text.hashCode;
      final isNewContent = _lastContentHash != contentHash;
      _lastContentHash = contentHash;

      if (isNewContent &&
          (readyState == 'complete' || readyState == 'interactive')) {
        final searchable =
            '${text.toLowerCase()}\n${html.toLowerCase()}';
        final matched = _loginKeywords.firstWhere(
          (key) => searchable.contains(key.toLowerCase()),
          orElse: () => '',
        );

        if (matched.isNotEmpty && !_hasLoggedIn) {
          await _handleLoginSuccess(liveUrl, html);
          return;
        }

        final loginPath = widget.school.url.login.toLowerCase();
        if (liveUrl.toLowerCase().contains(loginPath)) {
          if (mounted) setState(() => _isLoggingIn = false);
        }
      }
    }

    if (!_hasLoggedIn) {
      await Future.delayed(const Duration(seconds: 1));
      _inspectLoginStatePeriodic(liveUrl);
    } else {
      _isCheckingLoginState = false;
    }
  }

  Future<void> _handleLoginSuccess(String currentUrl, String html) async {
    _hasLoggedIn = true;

    final cookieManager = CookieManager.instance();
    var cookies = await cookieManager.getCookies(
      url: WebUri(widget.school.rootUrl),
    );

    // Extract cookies from visited URL query params
    final extraCookies = <WebUri, Cookie>{};
    for (final urlStr in _visitedUrls) {
      final uri = Uri.tryParse(urlStr);
      if (uri == null || uri.host.isEmpty) continue;
      for (final entry in uri.queryParameters.entries) {
        if (entry.value.isEmpty) continue;
        if (cookies.any((c) => c.name == entry.key)) continue;
        final webUri = WebUri('${uri.scheme}://${uri.host}');
        extraCookies[webUri] = Cookie(
          name: entry.key,
          value: entry.value,
          domain: uri.host,
          path: '/',
          isSecure: true,
          expiresDate: DateTime.now()
              .add(const Duration(days: 30))
              .millisecondsSinceEpoch,
        );
      }
    }
    for (final entry in extraCookies.entries) {
      await cookieManager.setCookie(
        url: entry.key,
        name: entry.value.name,
        value: entry.value.value ?? '',
        domain: entry.value.domain,
        path: entry.value.path ?? '/',
        isSecure: entry.value.isSecure ?? true,
        expiresDate: entry.value.expiresDate,
      );
      cookies = await cookieManager.getCookies(url: WebUri(widget.school.rootUrl));
    }

    // Extract userInfo div
    final userInfoPattern = RegExp(r'<div[^>]*id="userInfo"[^>]*>([^<]*)</div>');
    final userInfoMatch = userInfoPattern.firstMatch(html);
    if (userInfoMatch != null) {
      final userInfoValue = userInfoMatch.group(1)?.trim() ?? '';
      if (userInfoValue.isNotEmpty) {
        final host = Uri.tryParse(currentUrl)?.host ?? '';
        if (host.isNotEmpty && !cookies.any((c) => c.name == 'userInfo')) {
          await cookieManager.setCookie(
            url: WebUri('https://$host'),
            name: 'userInfo',
            value: userInfoValue,
            domain: host,
            path: '/',
            isSecure: true,
            expiresDate: DateTime.now()
                .add(const Duration(days: 30))
                .millisecondsSinceEpoch,
          );
          cookies = await cookieManager.getCookies(url: WebUri(widget.school.rootUrl));
        }
      }
    }

    final mapped = cookies
        .map((c) => AppCookie(name: c.name, value: c.value))
        .toList();

    if (!mounted) return;
    setState(() {
      _hasLoggedIn = true;
      _isLoggingIn = false;
    });
    _isCheckingLoginState = false;

    final apiService = context.read<ApiService>();
    apiService.setCookies(mapped);
    apiService.markLoggedIn();
  }

  Future<void> _recognizeCaptcha(String selector) async {
    if (_controller == null || _isCaptchaRecognizing) return;

    setState(() {
      _isCaptchaRecognizing = true;
      _lastCaptcha = null;
    });

    try {
      final rect = await _getCaptchaRect(selector);
      if (rect == null) {
        _stopCaptchaRecognition();
        return;
      }

      final bytes = await _controller!.takeScreenshot();
      if (bytes == null) {
        _stopCaptchaRecognition();
        return;
      }

      final cropped = _cropImage(bytes, rect);
      if (cropped == null) {
        _stopCaptchaRecognition();
        return;
      }

      final text = await _runOcr(cropped);
      if (text != null && text.isNotEmpty) {
        _lastCaptcha = text;
        await _controller!.evaluateJavascript(
          source: "window.fillCaptchaCode('${_escapeJs(text)}')",
        );
      }
    } finally {
      _stopCaptchaRecognition();
    }
  }

  void _stopCaptchaRecognition() {
    if (!mounted) return;
    setState(() => _isCaptchaRecognizing = false);
  }

  Future<Map<String, num>?> _getCaptchaRect(String selector) async {
    if (_controller == null) return null;
    final script = '''
(function() {
  try {
    var element = null;
    element = document.querySelector('.' + '$selector');
    if (!element) element = document.querySelector('#' + '$selector');
    if (!element) element = document.querySelector('[name="' + '$selector' + '"]');
    if (!element) element = document.querySelector('img[alt*="' + '$selector' + '"]');
    if (!element) {
      var images = document.querySelectorAll('img');
      for (var i = 0; i < images.length; i++) {
        var img = images[i];
        var src = (img.src || '').toLowerCase();
        var alt = (img.alt || '').toLowerCase();
        var className = (img.className || '').toLowerCase();
        if (src.includes('captcha') || src.includes('code') || src.includes('verify') ||
            alt.includes('captcha') || alt.includes('code') || alt.includes('verify') ||
            className.includes('captcha') || className.includes('code') || className.includes('verify')) {
          element = img;
          break;
        }
      }
    }
    if (!element) return { error: 'no element' };
    var rect = element.getBoundingClientRect();
    return {
      x: rect.left,
      y: rect.top,
      width: rect.width,
      height: rect.height,
      scale: window.devicePixelRatio || 1
    };
  } catch (e) {
    return { error: e.toString() };
  }
})();
''';

    final result = await _controller!.evaluateJavascript(source: script);
    if (result is Map && result['error'] == null) {
      final map = result.map((key, value) => MapEntry(key.toString(), value));
      if (map['x'] == null || map['width'] == null) return null;
      return {
        'x': (map['x'] as num),
        'y': (map['y'] as num),
        'width': (map['width'] as num),
        'height': (map['height'] as num),
        'scale': (map['scale'] as num?) ?? 1,
      };
    }
    return null;
  }

  Uint8List? _cropImage(Uint8List bytes, Map<String, num> rect) {
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    final scale = rect['scale']?.toDouble() ?? 1;
    final x = (rect['x']!.toDouble() * scale).round();
    final y = (rect['y']!.toDouble() * scale).round();
    final w = (rect['width']!.toDouble() * scale).round();
    final h = (rect['height']!.toDouble() * scale).round();

    final safeX = x.clamp(0, image.width - 1);
    final safeY = y.clamp(0, image.height - 1);
    final safeW = (safeX + w > image.width) ? (image.width - safeX) : w;
    final safeH = (safeY + h > image.height) ? (image.height - safeY) : h;

    if (safeW <= 0 || safeH <= 0) return null;

    final cropped = img.copyCrop(image, x: safeX, y: safeY, width: safeW, height: safeH);
    return Uint8List.fromList(img.encodePng(cropped));
  }

  Future<String?> _runOcr(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/captcha_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);

    final inputImage = InputImage.fromFilePath(file.path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final result = await recognizer.processImage(inputImage);
    await recognizer.close();

    final candidates = <String>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        candidates.add(line.text);
      }
    }
    if (candidates.isEmpty) {
      candidates.add(result.text);
    }

    final cleaned = candidates
        .map(_cleanupText)
        .where((e) => e.isNotEmpty)
        .toList();

    if (cleaned.isEmpty) return null;
    cleaned.sort((a, b) => _scoreCandidate(b).compareTo(_scoreCandidate(a)));
    return cleaned.first;
  }

  String _cleanupText(String text) {
    return text
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
  }

  int _scoreCandidate(String candidate) {
    var score = 0;
    if (candidate.length >= 3 && candidate.length <= 8) score += 10;
    final hasDigits = candidate.contains(RegExp(r'\d'));
    final hasLetters = candidate.contains(RegExp(r'[A-Z]'));
    if (hasDigits && hasLetters) {
      score += 15;
    } else if (hasDigits || hasLetters) {
      score += 10;
    }
    if (candidate.length < 2 || candidate.length > 10) score -= 20;
    if (candidate.contains(RegExp(r'[^a-zA-Z0-9]'))) score -= 50;
    return score;
  }

  String _escapeJs(String input) {
    return input
        .replaceAll('\\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n');
  }
}
