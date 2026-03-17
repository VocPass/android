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
  int _inspectAttempt = 0;

  List<String> get _loginKeywords {
    final fromApi = widget.school.login.successKeywords
            ?.where((e) => e.trim().isNotEmpty)
            .toList() ??
        [];
    if (fromApi.isNotEmpty) return fromApi;
    return const ['登出', 'logout'];
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
            },
            onLoadStart: (controller, url) {
              final currentUrl = url?.toString().toLowerCase() ?? '';
              final loginPath = widget.school.url.login.toLowerCase();
              if (!currentUrl.contains(loginPath) && !_hasLoggedIn) {
                setState(() => _isLoggingIn = true);
              }
            },
            onLoadStop: (controller, url) {
              _inspectLoginState(url?.toString() ?? '');
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

  function fillCredentials() {
    var usernameField = document.querySelector('input[name="' + usernameFieldName + '"]');
    if (usernameField && savedUsername && !usernameField.value) {
      usernameField.value = savedUsername;
      usernameField.dispatchEvent(new Event('input', { bubbles: true }));
      usernameField.dispatchEvent(new Event('change', { bubbles: true }));
    }

    var passwordField = document.querySelector('input[name="' + passwordFieldName + '"]');
    if (passwordField && savedPassword && !passwordField.value) {
      passwordField.value = savedPassword;
      passwordField.dispatchEvent(new Event('input', { bubbles: true }));
      passwordField.dispatchEvent(new Event('change', { bubbles: true }));
    }

    var captchaField = captchaFieldName
      ? document.querySelector('input[name="' + captchaFieldName + '"]')
      : null;

    if (captchaField && !captchaField.value && !hasTriggeredCaptchaRecognition) {
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
    var captchaField = captchaFieldName
      ? document.querySelector('input[name="' + captchaFieldName + '"]')
      : null;
    if (captchaField) {
      captchaField.value = code;
      captchaField.dispatchEvent(new Event('input', { bubbles: true }));
      captchaField.dispatchEvent(new Event('change', { bubbles: true }));
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
    var usernameField = document.querySelector('input[name="' + usernameFieldName + '"]');
    var passwordField = document.querySelector('input[name="' + passwordFieldName + '"]');
    var captchaField = captchaFieldName
      ? document.querySelector('input[name="' + captchaFieldName + '"]')
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

  var loginBtn = form.querySelector('.' + buttonClass);
  if (!loginBtn) return;

  var usernameField = form.querySelector('input[name="' + usernameFieldName + '"]');
  var passwordField = form.querySelector('input[name="' + passwordFieldName + '"]');
  var captchaField = form.querySelector('input[name="' + captchaFieldName + '"]');

  var username = usernameField ? usernameField.value : '';
  var password = passwordField ? passwordField.value : '';
  var captcha = captchaField ? captchaField.value : '';

  if (!captcha || captcha.trim() === '') {
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

  Future<void> _inspectLoginState(String currentUrl) async {
    if (_controller == null || _hasLoggedIn) return;
    if (_inspectAttempt > 8) return;

    final result = await _controller!.evaluateJavascript(source: '''
(function() {
  return {
    readyState: document.readyState || '',
    html: (document.documentElement && document.documentElement.outerHTML) ? document.documentElement.outerHTML : '',
    text: (document.body && document.body.innerText) ? document.body.innerText : ''
  };
})();
''');

    if (result is Map) {
      final readyState = (result['readyState'] ?? '').toString().toLowerCase();
      if (readyState != 'complete' && _inspectAttempt < 8) {
        _inspectAttempt += 1;
        Future.delayed(const Duration(milliseconds: 350), () {
          _inspectLoginState(currentUrl);
        });
        return;
      }

      final html = (result['html'] ?? '').toString().toLowerCase();
      final text = (result['text'] ?? '').toString().toLowerCase();
      final searchable = '$text\n$html';
      final matched = _loginKeywords.firstWhere(
        (key) => searchable.contains(key.toLowerCase()),
        orElse: () => '',
      );

      if (matched.isNotEmpty && !_hasLoggedIn) {
        final cookieManager = CookieManager.instance();
        final cookies = await cookieManager.getCookies(
          url: WebUri(widget.school.rootUrl),
        );
        final mapped = cookies
            .map((c) => AppCookie(name: c.name, value: c.value))
            .toList();

        if (mounted) {
          setState(() {
            _hasLoggedIn = true;
            _isLoggingIn = false;
          });
        }

        if (mounted) {
          final apiService = context.read<ApiService>();
          apiService.setCookies(mapped);
          apiService.markLoggedIn();
        }
        return;
      }

      final loginPath = widget.school.url.login.toLowerCase();
      if (currentUrl.toLowerCase().contains(loginPath)) {
        if (mounted) {
          setState(() => _isLoggingIn = false);
        }
      }
    }
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
    if (!element) {
      element = document.querySelector('#' + '$selector');
    }
    if (!element) {
      element = document.querySelector('[name="' + '$selector' + '"]');
    }
    if (!element) {
      element = document.querySelector('img[alt*="' + '$selector' + '"]');
    }
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
    if (!element) {
      return { error: 'no element' };
    }
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
    final cleaned = text
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    return cleaned;
  }

  int _scoreCandidate(String candidate) {
    var score = 0;
    if (candidate.length >= 3 && candidate.length <= 8) {
      score += 10;
    }
    final hasDigits = candidate.contains(RegExp(r'\d'));
    final hasLetters = candidate.contains(RegExp(r'[A-Z]'));
    if (hasDigits && hasLetters) {
      score += 15;
    } else if (hasDigits || hasLetters) {
      score += 10;
    }
    if (candidate.length < 2 || candidate.length > 10) {
      score -= 20;
    }
    if (candidate.contains(RegExp(r'[^a-zA-Z0-9]'))) {
      score -= 50;
    }
    return score;
  }

  String _escapeJs(String input) {
    return input
        .replaceAll('\\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n');
  }
}
