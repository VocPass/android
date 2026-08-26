import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/data_export_service.dart';
import '../widgets/grouped_list.dart';

/// 資料匯出 - 將校務資料打包成 JSON，並可到線上工具檢視。
class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  /// 線上檢視工具：使用者上傳匯出的 JSON 後即可瀏覽。
  static const String onlineViewerUrl = 'https://vocpass.com/export';

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  bool _exporting = false;
  List<ExportSection> _sections = const [];
  ExportResult? _result;
  File? _file;
  String? _error;

  Future<void> _startExport() async {
    setState(() {
      _exporting = true;
      _error = null;
      _result = null;
      _file = null;
      _sections = const [];
    });

    try {
      final api = context.read<ApiService>();
      final result = await DataExportService.instance.export(
        api: api,
        onProgress: (sections) {
          if (!mounted) return;
          // 服務層會就地更新同一組物件，複製一份才能讓 UI 取得新狀態。
          setState(() => _sections = List.of(sections));
        },
      );
      final file = await DataExportService.instance.writeToFile(result);
      if (!mounted) return;
      setState(() {
        _result = result;
        _file = file;
        _sections = result.sections;
        _exporting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : '匯出失敗：$e';
        _exporting = false;
      });
    }
  }

  Future<void> _shareFile() async {
    final file = _file;
    final result = _result;
    if (file == null || result == null) return;

    // 在 iPad 上 share sheet 需要一個來源矩形，否則會直接崩潰。
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json', name: result.fileName)],
      subject: result.fileName,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _openOnlineViewer() async {
    final uri = Uri.parse(DataExportScreen.onlineViewerUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟瀏覽器')),
      );
    }
  }

  Future<void> _copyJson() async {
    final result = _result;
    if (result == null) return;
    await Clipboard.setData(ClipboardData(text: result.json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已複製 JSON 內容')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final done = _result != null;

    return Scaffold(
      appBar: AppBar(title: const Text('資料匯出')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          GroupedCard(
            children: [
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('匯出校務資料'),
                subtitle: const Text('缺曠、課表、考試成績、獎懲、學期成績'),
                isThreeLine: false,
              ),
            ],
          ),
          const SectionFootnote(
              '匯出的 JSON 檔僅存在你的裝置上，不會自動上傳。你可以自行保存，或到線上工具開啟檢視。'),

          if (!api.isLoggedIn) ...[
            const SizedBox(height: 8),
            GroupedCard(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline,
                      color: Theme.of(context).colorScheme.error),
                  title: const Text('尚未登入學校帳號'),
                  subtitle: const Text('登入後才能匯出校務資料'),
                ),
              ],
            ),
          ],

          if (_sections.isNotEmpty) ...[
            const SectionHeader('匯出項目'),
            GroupedCard(
              children: [
                for (final section in _sections) _SectionRow(section: section),
              ],
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 8),
            GroupedCard(
              children: [
                ListTile(
                  leading: Icon(Icons.error_outline,
                      color: Theme.of(context).colorScheme.error),
                  title: const Text('匯出失敗'),
                  subtitle: Text(_error!),
                ),
              ],
            ),
          ],

          if (done) ...[
            const SectionHeader('匯出結果'),
            GroupedCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.description),
                  title: Text(_result!.fileName),
                  subtitle: Text(_formatBytes(_result!.json.length)),
                ),
                ListTile(
                  leading: const Icon(Icons.ios_share),
                  title: const Text('分享 / 儲存檔案'),
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _shareFile,
                ),
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('複製 JSON 內容'),
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _copyJson,
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        (_exporting || !api.isLoggedIn) ? null : _startExport,
                    icon: _exporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text(_exporting
                        ? '匯出中…'
                        : (done ? '重新匯出' : '開始匯出')),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _exporting ? null : _openOnlineViewer,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('到線上工具查看'),
                  ),
                ),
              ],
            ),
          ),
          SectionFootnote(
            done
                ? '在線上工具中上傳剛才匯出的 ${_result!.fileName}，即可瀏覽你的課表與成績。'
                : '線上工具：${DataExportScreen.onlineViewerUrl}',
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes 位元組';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// 匯出項目的單一列，依狀態顯示對應的圖示與說明。
class _SectionRow extends StatelessWidget {
  final ExportSection section;

  const _SectionRow({required this.section});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget trailing;
    switch (section.status) {
      case ExportSectionStatus.pending:
        trailing = Icon(Icons.circle_outlined, size: 20, color: Colors.grey[400]);
        break;
      case ExportSectionStatus.running:
        trailing = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case ExportSectionStatus.success:
        trailing = Icon(Icons.check_circle, size: 20, color: scheme.primary);
        break;
      case ExportSectionStatus.skipped:
        trailing = Icon(Icons.remove_circle_outline,
            size: 20, color: Colors.grey[400]);
        break;
      case ExportSectionStatus.failed:
        trailing = Icon(Icons.error_outline, size: 20, color: scheme.error);
        break;
    }

    final subtitle = section.status == ExportSectionStatus.success
        ? '${section.count} 筆'
        : section.message;

    return ListTile(
      title: Text(section.title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing,
    );
  }
}
