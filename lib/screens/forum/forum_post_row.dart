// 論壇文章列表項目

import 'package:flutter/material.dart';

import '../../models/forum_models.dart';
import 'forum_widgets.dart';

class ForumPostRow extends StatelessWidget {
  final ForumPost post;
  final String? currentUserID;
  final ForumBadge? badge;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback? onAuthorTap;

  const ForumPostRow({
    super.key,
    required this.post,
    required this.currentUserID,
    required this.badge,
    required this.onTap,
    required this.onLike,
    this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = post.user;
    final anonymous = post.anonymous || user == null;
    final liked = post.isLikedBy(currentUserID);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ForumAvatar(
                  url: anonymous ? null : user.avatarURL,
                  fallbackText: anonymous ? '匿' : user.displayName,
                  size: 34,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: anonymous ? null : onAuthorTap,
                          child: Text(
                            anonymous ? '匿名' : user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ),
                      if (badge != null && !anonymous) ...[
                        const SizedBox(width: 6),
                        ForumBadgeChip(badge: badge!),
                      ],
                    ],
                  ),
                ),
                if (post.pin)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.push_pin, size: 15, color: Colors.orange),
                  ),
                const SizedBox(width: 4),
                Text(forumRelativeTime(post.created),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (post.content.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(post.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.black87)),
            ],
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children:
                    post.tags.map((t) => ForumTagBadge(tag: t)).toList(),
              ),
            ],
            if (post.imageURLs.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    for (final url in post.imageURLs.take(3))
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Image.network(
                          url,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                InkWell(
                  onTap: onLike,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(liked ? Icons.favorite : Icons.favorite_border,
                            size: 18, color: liked ? Colors.red : Colors.grey),
                        const SizedBox(width: 4),
                        Text('${post.likes.length}',
                            style: TextStyle(
                                fontSize: 13,
                                color: liked ? Colors.red : Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
