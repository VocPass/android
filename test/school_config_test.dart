import 'package:flutter_test/flutter_test.dart';
import 'package:VosPass/config/school_config.dart';

void main() {
  group('FieldConfig', () {
    test('fromJson parses name', () {
      final fc = FieldConfig.fromJson({'name': 'LoginName'});
      expect(fc.name, 'LoginName');
    });

    test('fromJson defaults to empty string', () {
      final fc = FieldConfig.fromJson({});
      expect(fc.name, '');
    });

    test('toJson roundtrip', () {
      final fc = FieldConfig.fromJson({'name': 'X'});
      expect(fc.toJson(), {'name': 'X'});
    });
  });

  group('ButtonConfig', () {
    test('fromJson reads class key', () {
      final bc = ButtonConfig.fromJson({'class': 'loginBtnAdjust'});
      expect(bc.cssClass, 'loginBtnAdjust');
    });

    test('toJson roundtrip', () {
      const bc = ButtonConfig(cssClass: 'btn');
      expect(bc.toJson(), {'class': 'btn'});
    });
  });

  group('UrlConfig', () {
    test('fromJson parses all fields', () {
      final uc = UrlConfig.fromJson({
        'login': '/auth/Online',
        'logined': '/online/student/frames.asp',
        'root': '/',
      });
      expect(uc.login, '/auth/Online');
      expect(uc.logined, '/online/student/frames.asp');
      expect(uc.root, '/');
    });

    test('fromJson defaults to empty strings', () {
      final uc = UrlConfig.fromJson({});
      expect(uc.login, '');
      expect(uc.logined, '');
      expect(uc.root, '');
    });

    test('toJson roundtrip', () {
      const uc = UrlConfig(login: '/a', logined: '/b', root: '/c');
      final json = uc.toJson();
      final restored = UrlConfig.fromJson(json);
      expect(restored.login, '/a');
      expect(restored.logined, '/b');
      expect(restored.root, '/c');
    });
  });

  group('RouteConfig', () {
    test('fromJson parses exam_results', () {
      final rc = RouteConfig.fromJson({'exam_results': '/exam'});
      expect(rc.examResults, '/exam');
    });

    test('fromJson reads examResults alternative key', () {
      final rc = RouteConfig.fromJson({'examResults': '/exam2'});
      expect(rc.examResults, '/exam2');
    });

    test('fromJson returns null when not provided', () {
      final rc = RouteConfig.fromJson({});
      expect(rc.examResults, isNull);
    });

    test('toJson roundtrip', () {
      const rc = RouteConfig(examResults: '/e');
      expect(rc.toJson(), {'exam_results': '/e'});
    });
  });

  group('NoticeConfig', () {
    test('fromJson parses fields', () {
      final nc = NoticeConfig.fromJson({'vision': 'v1', 'url': 'https://notice.tw'});
      expect(nc.vision, 'v1');
      expect(nc.url, 'https://notice.tw');
    });

    test('url is null when not provided', () {
      final nc = NoticeConfig.fromJson({'vision': 'v2'});
      expect(nc.url, isNull);
    });
  });

  group('LoginConfig', () {
    test('fromJson parses all fields including captchaImage', () {
      final json = {
        'username': {'name': 'LoginName'},
        'password': {'name': 'PassString'},
        'captcha': {'name': 'CaptchaCode'},
        'captchaImage': {'selector': '.captcha-img', 'type': 'class'},
        'button': {'class': 'loginBtn'},
        'successKeywords': ['成功', '歡迎'],
      };
      final lc = LoginConfig.fromJson(json);
      expect(lc.username.name, 'LoginName');
      expect(lc.password.name, 'PassString');
      expect(lc.captcha.name, 'CaptchaCode');
      expect(lc.captchaImage!.selector, '.captcha-img');
      expect(lc.captchaImage!.type, 'class');
      expect(lc.button.cssClass, 'loginBtn');
      expect(lc.successKeywords, ['成功', '歡迎']);
    });

    test('fromJson parses success keywords from comma-separated string', () {
      final json = {
        'username': {'name': ''},
        'password': {'name': ''},
        'captcha': {'name': ''},
        'button': {'class': ''},
        'success_keywords': '成功, 歡迎, ok',
      };
      final lc = LoginConfig.fromJson(json);
      expect(lc.successKeywords, ['成功', '歡迎', 'ok']);
    });

    test('fromJson handles captcha_image alternative key', () {
      final json = {
        'username': {'name': ''},
        'password': {'name': ''},
        'captcha': {'name': ''},
        'captcha_image': {'selector': '#captcha', 'type': 'id'},
        'button': {'class': ''},
      };
      final lc = LoginConfig.fromJson(json);
      expect(lc.captchaImage!.selector, '#captcha');
      expect(lc.captchaImage!.type, 'id');
    });

    test('captchaImage is null when not provided', () {
      final json = {
        'username': {'name': ''},
        'password': {'name': ''},
        'captcha': {'name': ''},
        'button': {'class': ''},
      };
      final lc = LoginConfig.fromJson(json);
      expect(lc.captchaImage, isNull);
    });

    test('captchaImage is null when selector and type are both empty', () {
      final json = {
        'username': {'name': ''},
        'password': {'name': ''},
        'captcha': {'name': ''},
        'captchaImage': {'selector': '', 'type': ''},
        'button': {'class': ''},
      };
      final lc = LoginConfig.fromJson(json);
      expect(lc.captchaImage, isNull);
    });

    test('successKeywords is null when empty', () {
      final json = {
        'username': {'name': ''},
        'password': {'name': ''},
        'captcha': {'name': ''},
        'button': {'class': ''},
        'successKeywords': [],
      };
      final lc = LoginConfig.fromJson(json);
      expect(lc.successKeywords, isNull);
    });

    test('toJson roundtrip', () {
      final json = {
        'username': {'name': 'U'},
        'password': {'name': 'P'},
        'captcha': {'name': 'C'},
        'captchaImage': {'selector': 'sel', 'type': 'tp'},
        'button': {'class': 'btn'},
        'successKeywords': ['ok'],
      };
      final lc = LoginConfig.fromJson(json);
      final output = lc.toJson();
      expect(output['username'], {'name': 'U'});
      expect(output['password'], {'name': 'P'});
      expect(output['captcha'], {'name': 'C'});
      expect((output['captchaImage'] as Map)['selector'], 'sel');
      expect(output['successKeywords'], ['ok']);
    });
  });

  group('SchoolConfig', () {
    Map<String, dynamic> fullSchoolJson() => {
          'name': '鶯歌工商',
          'vision': 'v1',
          'app': '1.5.0',
          'beta': false,
          'api': 'https://eschool.ykvs.ntpc.edu.tw',
          'url': {
            'login': '/auth/Online',
            'logined': '/online/student/frames.asp',
            'root': '/',
          },
          'login': {
            'username': {'name': 'LoginName'},
            'password': {'name': 'PassString'},
            'captcha': {'name': 'ShCaptchaGenCode'},
            'captchaImage': {'selector': 'captcha-image', 'type': 'class'},
            'button': {'class': 'loginBtnAdjust'},
          },
          'route': {
            'exam_results': '/online/selection_student/exam',
          },
          'notice': {'vision': 'v1', 'url': 'https://notice.tw'},
          'telephone': '02-12345678',
          'js': 'console.log("hi")',
        };

    test('fromJson parses all fields', () {
      final config = SchoolConfig.fromJson(fullSchoolJson());
      expect(config.name, '鶯歌工商');
      expect(config.vision, 'v1');
      expect(config.app, '1.5.0');
      expect(config.beta, false);
      expect(config.api, 'https://eschool.ykvs.ntpc.edu.tw');
      expect(config.url.login, '/auth/Online');
      expect(config.login.username.name, 'LoginName');
      expect(config.route.examResults, '/online/selection_student/exam');
      expect(config.notice!.vision, 'v1');
      expect(config.telephone, '02-12345678');
      expect(config.js, 'console.log("hi")');
    });

    test('fromApi parses with name argument', () {
      final json = {
        'vision': 'v2',
        'api': 'https://school.tw',
        'url': {'login': '/', 'logined': '/', 'root': '/'},
        'login': {
          'username': {'name': ''},
          'password': {'name': ''},
          'captcha': {'name': ''},
          'button': {'class': ''},
        },
        'route': {},
      };
      final config = SchoolConfig.fromApi('TestSchool', json);
      expect(config.name, 'TestSchool');
      expect(config.vision, 'v2');
    });

    test('isGuest returns true for guest config', () {
      expect(SchoolConfig.guest.isGuest, true);
    });

    test('isGuest returns false for normal config', () {
      final config = SchoolConfig.fromJson(fullSchoolJson());
      expect(config.isGuest, false);
    });

    test('loginUrl returns correct Uri', () {
      final config = SchoolConfig.fromJson(fullSchoolJson());
      expect(config.loginUrl.toString(),
          'https://eschool.ykvs.ntpc.edu.tw/auth/Online');
    });

    test('loginUrl returns null for guest', () {
      expect(SchoolConfig.guest.loginUrl, isNull);
    });

    test('loginedUrl and rootUrl return correct strings', () {
      final config = SchoolConfig.fromJson(fullSchoolJson());
      expect(config.loginedUrl,
          'https://eschool.ykvs.ntpc.edu.tw/online/student/frames.asp');
      expect(config.rootUrl, 'https://eschool.ykvs.ntpc.edu.tw/');
    });

    test('toJson and fromJson roundtrip', () {
      final original = SchoolConfig.fromJson(fullSchoolJson());
      final json = original.toJson();
      final restored = SchoolConfig.fromJson(json);
      expect(restored.name, original.name);
      expect(restored.api, original.api);
      expect(restored.url.login, original.url.login);
      expect(restored.login.username.name, original.login.username.name);
    });

    test('toJsonString and fromJsonString roundtrip', () {
      final original = SchoolConfig.fromJson(fullSchoolJson());
      final jsonStr = original.toJsonString();
      final restored = SchoolConfig.fromJsonString(jsonStr);
      expect(restored, isNotNull);
      expect(restored!.name, original.name);
      expect(restored.api, original.api);
    });

    test('fromJsonString returns null for invalid input', () {
      expect(SchoolConfig.fromJsonString('not json'), isNull);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'name': 'Test',
        'vision': 'v1',
        'api': 'https://test.tw',
        'url': {'login': '/', 'logined': '/', 'root': '/'},
        'login': {
          'username': {'name': ''},
          'password': {'name': ''},
          'captcha': {'name': ''},
          'button': {'class': ''},
        },
        'route': {},
      };
      final config = SchoolConfig.fromJson(json);
      expect(config.notice, isNull);
      expect(config.telephone, isNull);
      expect(config.js, isNull);
      expect(config.app, isNull);
      expect(config.beta, false);
    });

    test('_parseAppVersion handles different types', () {
      final json1 = {
        'vision': 'v1',
        'api': '',
        'app': '1.0.0',
        'url': {'login': '', 'logined': '', 'root': ''},
        'login': {
          'username': {'name': ''},
          'password': {'name': ''},
          'captcha': {'name': ''},
          'button': {'class': ''},
        },
        'route': {},
      };
      expect(SchoolConfig.fromApi('S', json1).app, '1.0.0');

      final json2 = Map<String, dynamic>.from(json1);
      json2['app'] = 2;
      expect(SchoolConfig.fromApi('S', json2).app, '2');

      final json3 = Map<String, dynamic>.from(json1);
      json3['app'] = null;
      expect(SchoolConfig.fromApi('S', json3).app, isNull);
    });

    test('guest config has expected values', () {
      final guest = SchoolConfig.guest;
      expect(guest.name, '訪客模式');
      expect(guest.api, SchoolConfig.guestApiMarker);
      expect(guest.beta, false);
      expect(guest.url.login, '/');
    });
  });

  group('CaptchaImageConfig', () {
    test('toJson returns correct map', () {
      const ci = CaptchaImageConfig(selector: '.img', type: 'class');
      expect(ci.toJson(), {'selector': '.img', 'type': 'class'});
    });
  });
}
