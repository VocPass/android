import 'dart:convert';

class NoticeConfig {
  final String vision;
  final String? url;

  const NoticeConfig({required this.vision, this.url});

  factory NoticeConfig.fromJson(Map<String, dynamic> json) {
    return NoticeConfig(
      vision: json['vision']?.toString() ?? '',
      url: json['url']?.toString(),
    );
  }
}

class SchoolConfig {
  final String name;
  final String vision;
  final String? app;
  final bool beta;
  final String api;
  final UrlConfig url;
  final LoginConfig login;
  final RouteConfig route;
  final NoticeConfig? notice;
  final String? telephone;

  const SchoolConfig({
    required this.name,
    required this.vision,
    required this.app,
    required this.beta,
    required this.api,
    required this.url,
    required this.login,
    required this.route,
    this.notice,
    this.telephone,
  });

  Uri? get loginUrl {
    if (url.login.isEmpty) return null;
    return Uri.tryParse('$api${url.login}');
  }

  String get loginedUrl => '$api${url.logined}';
  String get rootUrl => '$api${url.root}';

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'vision': vision,
      'app': app,
      'beta': beta,
      'api': api,
      'url': url.toJson(),
      'login': login.toJson(),
      'route': route.toJson(),
    };
  }

  static SchoolConfig fromJson(Map<String, dynamic> json) {
    final noticeRaw = json['notice'] as Map?;
    return SchoolConfig(
      name: json['name']?.toString() ?? '',
      vision: json['vision']?.toString() ?? '',
      app: json['app']?.toString(),
      beta: json['beta'] == true,
      api: json['api']?.toString() ?? '',
      url: UrlConfig.fromJson((json['url'] as Map?)?.cast<String, dynamic>() ?? {}),
      login: LoginConfig.fromJson((json['login'] as Map?)?.cast<String, dynamic>() ?? {}),
      route: RouteConfig.fromJson((json['route'] as Map?)?.cast<String, dynamic>() ?? {}),
      notice: noticeRaw != null ? NoticeConfig.fromJson(noticeRaw.cast<String, dynamic>()) : null,
      telephone: json['telephone']?.toString(),
    );
  }

  static SchoolConfig fromApi(String name, Map<String, dynamic> json) {
    final noticeRaw = json['notice'] as Map?;
    return SchoolConfig(
      name: name,
      vision: json['vision']?.toString() ?? '',
      app: _parseAppVersion(json['app']),
      beta: json['beta'] == true,
      api: json['api']?.toString() ?? '',
      url: UrlConfig.fromJson((json['url'] as Map?)?.cast<String, dynamic>() ?? {}),
      login: LoginConfig.fromJson((json['login'] as Map?)?.cast<String, dynamic>() ?? {}),
      route: RouteConfig.fromJson((json['route'] as Map?)?.cast<String, dynamic>() ?? {}),
      notice: noticeRaw != null ? NoticeConfig.fromJson(noticeRaw.cast<String, dynamic>()) : null,
      telephone: json['telephone']?.toString(),
    );
  }

  static String? _parseAppVersion(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num) return value.toString();
    return value.toString();
  }

  static SchoolConfig? fromJsonString(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SchoolConfig.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  String toJsonString() => jsonEncode(toJson());
}

class RouteConfig {
  final String? examResults;

  const RouteConfig({required this.examResults});

  factory RouteConfig.fromJson(Map<String, dynamic> json) {
    return RouteConfig(
      examResults: json['exam_results']?.toString() ??
          json['examResults']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'exam_results': examResults,
      };
}

class UrlConfig {
  final String login;
  final String logined;
  final String root;

  const UrlConfig({
    required this.login,
    required this.logined,
    required this.root,
  });

  factory UrlConfig.fromJson(Map<String, dynamic> json) {
    return UrlConfig(
      login: json['login']?.toString() ?? '',
      logined: json['logined']?.toString() ?? '',
      root: json['root']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'login': login,
        'logined': logined,
        'root': root,
      };
}

class LoginConfig {
  final FieldConfig username;
  final FieldConfig password;
  final FieldConfig captcha;
  final CaptchaImageConfig? captchaImage;
  final ButtonConfig button;
  final List<String>? successKeywords;

  const LoginConfig({
    required this.username,
    required this.password,
    required this.captcha,
    required this.captchaImage,
    required this.button,
    required this.successKeywords,
  });

  factory LoginConfig.fromJson(Map<String, dynamic> json) {
    final success = _parseSuccessKeywords(json);
    return LoginConfig(
      username: FieldConfig.fromJson((json['username'] as Map?)?.cast<String, dynamic>() ?? {}),
      password: FieldConfig.fromJson((json['password'] as Map?)?.cast<String, dynamic>() ?? {}),
      captcha: FieldConfig.fromJson((json['captcha'] as Map?)?.cast<String, dynamic>() ?? {}),
      captchaImage: _parseCaptchaImage(json['captchaImage']) ??
          _parseCaptchaImage(json['captcha_image']),
      button: ButtonConfig.fromJson((json['button'] as Map?)?.cast<String, dynamic>() ?? {}),
      successKeywords: success.isEmpty ? null : success,
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username.toJson(),
        'password': password.toJson(),
        'captcha': captcha.toJson(),
        'captchaImage': captchaImage?.toJson(),
        'button': button.toJson(),
        'successKeywords': successKeywords,
      };

  static List<String> _parseSuccessKeywords(Map<String, dynamic> json) {
    dynamic value = json['successKeywords'] ??
        json['success_keywords'] ??
        json['loginSuccessKeywords'] ??
        json['login_success_keywords'];

    if (value is List) {
      return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (value is String) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  static CaptchaImageConfig? _parseCaptchaImage(dynamic value) {
    if (value is Map) {
      final map = value.cast<String, dynamic>();
      final selector = map['selector']?.toString() ?? '';
      final type = map['type']?.toString() ?? '';
      if (selector.isEmpty && type.isEmpty) return null;
      return CaptchaImageConfig(selector: selector, type: type);
    }
    return null;
  }
}

class FieldConfig {
  final String name;

  const FieldConfig({required this.name});

  factory FieldConfig.fromJson(Map<String, dynamic> json) {
    return FieldConfig(name: json['name']?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {'name': name};
}

class CaptchaImageConfig {
  final String selector;
  final String type;

  const CaptchaImageConfig({required this.selector, required this.type});

  Map<String, dynamic> toJson() => {
        'selector': selector,
        'type': type,
      };
}

class ButtonConfig {
  final String cssClass;

  const ButtonConfig({required this.cssClass});

  factory ButtonConfig.fromJson(Map<String, dynamic> json) {
    return ButtonConfig(cssClass: json['class']?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {'class': cssClass};
}
