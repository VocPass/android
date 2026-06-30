// 論壇發文頁 - 對應 iOS 的 ForumCreatePostSheet

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import 'forum_widgets.dart';

class ForumCreatePostScreen extends StatefulWidget {
  /// 目前 VocPass 帳號已驗證的學校；為 null 代表尚未驗證，僅能發到公頻。
  final String? verifiedSchool;

  /// 進入時預設要發佈的頻道（"all" 或學校名）。
  final String initialSchool;

  /// 是否為目前學校版主 / 管理員（可置頂、可用管理員標籤）。
  final bool canPinCurrentSchool;
  final bool canUseAdminTags;

  final List<ForumTagOption> tagOptions;

  const ForumCreatePostScreen({
    super.key,
    required this.verifiedSchool,
    required this.initialSchool,
    required this.tagOptions,
    this.canPinCurrentSchool = false,
    this.canUseAdminTags = false,
  });

  @override
  State<ForumCreatePostScreen> createState() => _ForumCreatePostScreenState();
}

class _ForumCreatePostScreenState extends State<ForumCreatePostScreen> {
  static const _maxImages = 5;

  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _picker = ImagePicker();

  final _selectedTags = <String>{};
  final _images = <_PickedImage>[];
  bool _anonymous = false;
  bool _pin = false;
  bool _submitting = false;
  late String _selectedSchool;

  @override
  void initState() {
    super.initState();
    // 只有當預設頻道剛好等於已驗證學校時才預選本校，否則一律公頻。
    _selectedSchool = (widget.initialSchool != 'all' &&
            widget.initialSchool == widget.verifiedSchool)
        ? widget.initialSchool
        : 'all';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  bool get _isSchoolChannel =>
      _selectedSchool != 'all' && _selectedSchool == widget.verifiedSchool;

  /// 只有在發到自己學校頻道且為版主時，才能置頂 / 用管理員標籤。
  bool get _canPinSelectedSchool =>
      widget.canPinCurrentSchool && _isSchoolChannel;

  Iterable<ForumTagOption> get _availableTags => widget.tagOptions.where(
      (t) => !t.adminOnly || (widget.canUseAdminTags && _isSchoolChannel));

  void _selectChannel(String school) {
    setState(() {
      _selectedSchool = school;
      if (!_canPinSelectedSchool) _pin = false;
      // 移除目前頻道不可用的管理員標籤。
      _selectedTags.removeWhere((name) {
        final tag = widget.tagOptions
            .where((t) => t.name == name)
            .cast<ForumTagOption?>()
            .firstWhere((t) => true, orElse: () => null);
        if (tag == null) return false;
        return tag.adminOnly && !(widget.canUseAdminTags && _isSchoolChannel);
      });
    });
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) return;
    try {
      final picked = await _picker.pickMultiImage();
      if (picked.isEmpty) return;
      for (final file in picked.take(remaining)) {
        final bytes = await file.readAsBytes();
        _images.add(_PickedImage(bytes: bytes, mimeType: _mimeFor(file.name)));
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('選取圖片失敗：$e')));
      }
    }
  }

  String _mimeFor(String name) =>
      name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty) {
      _toast('請輸入標題');
      return;
    }
    if (content.isEmpty) {
      _toast('請輸入內容');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ForumService.instance.createPost(
        school: _selectedSchool,
        title: title,
        content: content,
        anonymous: _anonymous,
        pin: _canPinSelectedSchool && _pin,
        tags: _selectedTags.toList(),
        images: _images
            .map((e) => ForumImageUpload(data: e.bytes, mimeType: e.mimeType))
            .toList(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(e.toString());
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final availableTags = _availableTags.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('發文'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('送出'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 發佈頻道
          const Text('發佈頻道', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ChannelButton(
                  title: '公頻',
                  icon: Icons.public,
                  selected: _selectedSchool == 'all',
                  enabled: true,
                  onTap: () => _selectChannel('all'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChannelButton(
                  title: widget.verifiedSchool ?? '本校',
                  icon: Icons.account_balance,
                  selected: widget.verifiedSchool != null &&
                      _selectedSchool == widget.verifiedSchool,
                  enabled: widget.verifiedSchool != null,
                  onTap: widget.verifiedSchool == null
                      ? null
                      : () => _selectChannel(widget.verifiedSchool!),
                ),
              ),
            ],
          ),
          if (widget.verifiedSchool == null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('完成學校驗證後，才能選擇自己的學校論壇。',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          const SizedBox(height: 16),

          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: '標題',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentCtrl,
            decoration: const InputDecoration(
              labelText: '內容',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 6,
          ),
          const SizedBox(height: 16),

          // 標籤
          if (availableTags.isNotEmpty) ...[
            const Text('標籤', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final tag in availableTags)
                  FilterChip(
                    label: Text(tag.name),
                    avatar: tag.adminOnly
                        ? const Icon(Icons.shield, size: 14)
                        : null,
                    selected: _selectedTags.contains(tag.name),
                    selectedColor:
                        colorFromHex(tag.colorHex)?.withValues(alpha: 0.2),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _selectedTags.add(tag.name);
                      } else {
                        _selectedTags.remove(tag.name);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // 圖片
          Row(
            children: [
              const Text('圖片', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${_images.length}/$_maxImages',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _images.length; i++)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_images[i].bytes,
                          width: 84, height: 84, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.black54),
                        iconSize: 20,
                        onPressed: () => setState(() => _images.removeAt(i)),
                      ),
                    ),
                  ],
                ),
              if (_images.length < _maxImages)
                InkWell(
                  onTap: _pickImages,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_a_photo, color: Colors.grey),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('匿名發文'),
            value: _anonymous,
            onChanged: (v) => setState(() => _anonymous = v),
          ),
          if (_canPinSelectedSchool)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('置頂文章'),
              subtitle: const Text('僅版主可置頂'),
              value: _pin,
              onChanged: (v) => setState(() => _pin = v),
            ),
        ],
      ),
    );
  }
}

class _ChannelButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _ChannelButton({
    required this.title,
    required this.icon,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final color = !enabled
        ? Colors.grey
        : (selected ? primary : Theme.of(context).colorScheme.onSurface);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.12) : null,
          border: Border.all(
              color: selected ? primary : Colors.grey.shade400,
              width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class _PickedImage {
  final Uint8List bytes;
  final String mimeType;
  _PickedImage({required this.bytes, required this.mimeType});
}
