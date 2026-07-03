import 'package:flutter_test/flutter_test.dart';
import 'package:VosPass/models/forum_models.dart';

void main() {
  group('ForumUser', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'fu1',
        'name': 'Alice',
        'username': 'alice123',
        'avatar': 'https://img/alice.png',
      };
      final user = ForumUser.fromJson(json);
      expect(user.id, 'fu1');
      expect(user.name, 'Alice');
      expect(user.username, 'alice123');
      expect(user.avatarURL, 'https://img/alice.png');
      expect(user.displayName, 'Alice');
    });

    test('displayName falls back to username when name is empty', () {
      final json = {'name': '', 'username': 'bob456'};
      final user = ForumUser.fromJson(json);
      expect(user.displayName, 'bob456');
    });

    test('id defaults to username when not provided', () {
      final json = {'name': 'Carol', 'username': 'carol789'};
      final user = ForumUser.fromJson(json);
      expect(user.id, 'carol789');
    });

    test('avatarURL returns null for empty avatar', () {
      final json = {'name': 'Dave', 'username': 'dave', 'avatar': ''};
      final user = ForumUser.fromJson(json);
      expect(user.avatarURL, isNull);
    });

    test('avatarURL returns null when avatar is not provided', () {
      final json = {'name': 'Eve', 'username': 'eve'};
      final user = ForumUser.fromJson(json);
      expect(user.avatarURL, isNull);
    });
  });

  group('ForumPost', () {
    test('fromJson parses complete post', () {
      final json = {
        'id': 'p1',
        'post': 'p1-post',
        'school': '鶯歌工商',
        'title': 'Hello World',
        'content': 'This is content',
        'anonymous': false,
        'pin': true,
        'tag': {
          'news': {'color': '#FF0000', 'admin_only': true},
          'general': {'color': '#00FF00'},
        },
        'images': ['https://img/1.png', 'https://img/2.png'],
        'likes': ['user1', 'user2'],
        'user': {'name': 'Alice', 'username': 'alice'},
        'created': '2024-01-01T00:00:00Z',
        'updated': '2024-01-02T00:00:00Z',
      };
      final post = ForumPost.fromJson(json);
      expect(post.id, 'p1');
      expect(post.post, 'p1-post');
      expect(post.school, '鶯歌工商');
      expect(post.title, 'Hello World');
      expect(post.content, 'This is content');
      expect(post.anonymous, false);
      expect(post.pin, true);
      expect(post.tags.length, 2);
      expect(post.images.length, 2);
      expect(post.likes, ['user1', 'user2']);
      expect(post.user!.name, 'Alice');
      expect(post.created, '2024-01-01T00:00:00Z');
    });

    test('tags are sorted by name', () {
      final json = {
        'id': 'p2',
        'school': '',
        'title': '',
        'content': '',
        'tag': {
          'z_tag': {},
          'a_tag': {},
          'm_tag': {},
        },
        'created': '',
        'updated': '',
      };
      final post = ForumPost.fromJson(json);
      expect(post.tags.map((t) => t.name).toList(), ['a_tag', 'm_tag', 'z_tag']);
    });

    test('tags with admin_only parsed correctly', () {
      final json = {
        'id': 'p3',
        'school': '',
        'title': '',
        'content': '',
        'tag': {
          'admin': {'color': '#FFF', 'admin_only': true},
          'public': {'color': '#000', 'admin_only': false},
        },
        'created': '',
        'updated': '',
      };
      final post = ForumPost.fromJson(json);
      final adminTag = post.tags.firstWhere((t) => t.name == 'admin');
      final publicTag = post.tags.firstWhere((t) => t.name == 'public');
      expect(adminTag.adminOnly, true);
      expect(publicTag.adminOnly, false);
    });

    test('title defaults to 未命名文章 when empty', () {
      final json = {
        'id': 'p4',
        'school': '',
        'content': '',
        'created': '',
        'updated': '',
      };
      final post = ForumPost.fromJson(json);
      expect(post.title, '未命名文章');
    });

    test('likeTargetID returns post when available', () {
      final json = {
        'id': 'p5',
        'post': 'post-id',
        'school': '',
        'title': '',
        'content': '',
        'created': '',
        'updated': '',
      };
      final post = ForumPost.fromJson(json);
      expect(post.likeTargetID, 'post-id');
    });

    test('likeTargetID falls back to id when post is null', () {
      final json = {
        'id': 'p6',
        'school': '',
        'title': '',
        'content': '',
        'created': '',
        'updated': '',
      };
      final post = ForumPost.fromJson(json);
      expect(post.likeTargetID, 'p6');
    });

    test('imageURLs filters empty strings', () {
      final json = {
        'id': 'p7',
        'school': '',
        'title': '',
        'content': '',
        'images': ['https://img/1.png', '', 'https://img/2.png'],
        'created': '',
        'updated': '',
      };
      final post = ForumPost.fromJson(json);
      expect(post.imageURLs, ['https://img/1.png', 'https://img/2.png']);
    });

    test('isLikedBy works correctly', () {
      final json = {
        'id': 'p8',
        'school': '',
        'title': '',
        'content': '',
        'likes': ['user1', 'user2'],
        'created': '',
        'updated': '',
      };
      final post = ForumPost.fromJson(json);
      expect(post.isLikedBy('user1'), true);
      expect(post.isLikedBy('user3'), false);
      expect(post.isLikedBy(null), false);
      expect(post.isLikedBy(''), false);
    });

    test('user is null when not a map', () {
      final json = {
        'id': 'p9',
        'school': '',
        'title': '',
        'content': '',
        'user': 'not a map',
        'created': '',
        'updated': '',
      };
      final post = ForumPost.fromJson(json);
      expect(post.user, isNull);
    });
  });

  group('ForumMessage', () {
    test('fromJson parses complete message', () {
      final json = {
        'id': 'msg1',
        'content': 'Hello!',
        'anonymous': true,
        'user': {'name': 'Alice', 'username': 'alice'},
        'created': '2024-01-01',
        'likes': ['u1'],
      };
      final msg = ForumMessage.fromJson(json);
      expect(msg.id, 'msg1');
      expect(msg.content, 'Hello!');
      expect(msg.anonymous, true);
      expect(msg.user!.name, 'Alice');
      expect(msg.created, '2024-01-01');
      expect(msg.likes, ['u1']);
    });

    test('isLikedBy works correctly', () {
      final json = {
        'id': 'msg2',
        'content': '',
        'likes': ['u1', 'u2'],
        'created': '',
      };
      final msg = ForumMessage.fromJson(json);
      expect(msg.isLikedBy('u1'), true);
      expect(msg.isLikedBy('u3'), false);
      expect(msg.isLikedBy(null), false);
      expect(msg.isLikedBy(''), false);
    });

    test('fromJson reads alternative content keys', () {
      final json = {
        'id': 'msg3',
        'body': 'Body content',
        'created': '',
      };
      final msg = ForumMessage.fromJson(json);
      expect(msg.content, 'Body content');
    });
  });

  group('ForumPostListData', () {
    test('fromJson parses forums list and total pages', () {
      final json = {
        'forums': [
          {
            'id': 'p1',
            'school': 's',
            'title': 'T1',
            'content': 'C1',
            'created': '',
            'updated': '',
          },
          {
            'id': 'p2',
            'school': 's',
            'title': 'T2',
            'content': 'C2',
            'created': '',
            'updated': '',
          },
        ],
        'total_pages': 5,
      };
      final data = ForumPostListData.fromJson(json);
      expect(data.forums.length, 2);
      expect(data.forums[0].id, 'p1');
      expect(data.totalPages, 5);
    });

    test('fromJson handles missing forums', () {
      final json = <String, dynamic>{};
      final data = ForumPostListData.fromJson(json);
      expect(data.forums, isEmpty);
      expect(data.totalPages, 1);
    });
  });

  group('ForumMessageListData', () {
    test('fromJson parses messages list', () {
      final json = {
        'forums': [
          {'id': 'm1', 'content': 'C1', 'created': ''},
        ],
        'totalPages': 3,
      };
      final data = ForumMessageListData.fromJson(json);
      expect(data.forums.length, 1);
      expect(data.totalPages, 3);
    });
  });

  group('ForumAdminInfo', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'admin1',
        'school': '鶯歌工商',
        'icon': 'https://img/admin.png',
        'admin': ['u1', 'u2'],
      };
      final info = ForumAdminInfo.fromJson(json);
      expect(info.id, 'admin1');
      expect(info.school, '鶯歌工商');
      expect(info.iconURL, 'https://img/admin.png');
      expect(info.admin, ['u1', 'u2']);
    });

    test('iconURL returns null for empty icon', () {
      final json = {
        'id': 'admin2',
        'school': 's',
        'icon': '',
        'admin': [],
      };
      final info = ForumAdminInfo.fromJson(json);
      expect(info.iconURL, isNull);
    });

    test('iconURL returns null when icon is not provided', () {
      final json = {
        'id': 'admin3',
        'school': 's',
        'admin': [],
      };
      final info = ForumAdminInfo.fromJson(json);
      expect(info.iconURL, isNull);
    });
  });
}
