import '../models/models.dart';

class HtmlParser {
  static ExamScoreData parseExamScores(String html) {
    final data = ExamScoreData.empty();

    final studentIdMatch = RegExp(r'學號：(\d+)').firstMatch(html);
    if (studentIdMatch != null) {
      data.studentInfo = StudentInfo(
        studentId: studentIdMatch.group(1) ?? '',
        name: '',
        className: '',
      );
    }

    final examInfoMatch =
        RegExp(r'<span class="bluetext"[^>]*>(.*?)</span>',
                dotAll: true)
            .firstMatch(html);
    if (examInfoMatch != null) {
      data.examInfo = _stripHtml(examInfoMatch.group(1) ?? '');
    }

    final tableMatch = RegExp(r'<table[^>]*id="Table1"[^>]*>(.*?)</table>',
            dotAll: true, caseSensitive: false)
        .firstMatch(html);
    if (tableMatch != null) {
      final tableContent = tableMatch.group(1) ?? '';
      final rowMatches =
          RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true)
              .allMatches(tableContent)
              .toList();

      for (var i = 1; i < rowMatches.length; i++) {
        final rowContent = rowMatches[i].group(1) ?? '';
        final cells = _extractTableCells(rowContent);
        if (cells.length >= 3 && cells[0].isNotEmpty) {
          data.subjects.add(ExamSubjectScore(
            subject: cells[0],
            personalScore: cells[1],
            classAverage: cells[2],
          ));
        }
      }
    }

    return data;
  }

  static List<String> _extractTableCells(String rowHtml) {
    final matches =
        RegExp(r'<t[dh][^>]*>(.*?)</t[dh]>', dotAll: true)
            .allMatches(rowHtml)
            .toList();
    return matches
        .map((m) => _stripHtml(m.group(1) ?? '').trim())
        .toList();
  }

  static String _stripHtml(String html) {
    var result = html;
    result = result.replaceAll(RegExp(r'<[^>]+>'), '');
    result = result.replaceAll('&nbsp;', ' ');
    result = result.replaceAll('&amp;', '&');
    result = result.replaceAll('&lt;', '<');
    result = result.replaceAll('&gt;', '>');
    result = result.replaceAll('&quot;', '"');
    result = result.replaceAll('&apos;', '\'');
    result = _decodeHtmlEntities(result);
    return result.trim();
  }

  static String _decodeHtmlEntities(String input) {
    var result = input;
    final decimal = RegExp(r'&#(\d+);?');
    result = result.replaceAllMapped(decimal, (match) {
      final code = int.tryParse(match.group(1) ?? '');
      if (code == null) return match.group(0) ?? '';
      return String.fromCharCode(code);
    });

    final hex = RegExp(r'&#[xX]([0-9a-fA-F]+);?');
    result = result.replaceAllMapped(hex, (match) {
      final code = int.tryParse(match.group(1) ?? '', radix: 16);
      if (code == null) return match.group(0) ?? '';
      return String.fromCharCode(code);
    });

    return result;
  }
}
