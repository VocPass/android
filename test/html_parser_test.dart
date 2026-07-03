import 'package:flutter_test/flutter_test.dart';
import 'package:VosPass/services/html_parser.dart';

void main() {
  group('HtmlParser.parseExamScores', () {
    test('parses student ID from HTML', () {
      const html = '<div>學號：12345678</div>';
      final data = HtmlParser.parseExamScores(html);
      expect(data.studentInfo.studentId, '12345678');
    });

    test('parses exam info from bluetext span', () {
      const html = '<span class="bluetext">112-1 第一次段考</span>';
      final data = HtmlParser.parseExamScores(html);
      expect(data.examInfo, '112-1 第一次段考');
    });

    test('parses subject scores from Table1', () {
      const html = '''
<table id="Table1">
<tr><th>科目</th><th>個人成績</th><th>班級平均</th></tr>
<tr><td>國文</td><td>85</td><td>72</td></tr>
<tr><td>英文</td><td>90</td><td>75</td></tr>
<tr><td>數學</td><td>78</td><td>70</td></tr>
</table>
''';
      final data = HtmlParser.parseExamScores(html);
      expect(data.subjects.length, 3);
      expect(data.subjects[0].subject, '國文');
      expect(data.subjects[0].personalScore, '85');
      expect(data.subjects[0].classAverage, '72');
      expect(data.subjects[1].subject, '英文');
      expect(data.subjects[2].subject, '數學');
    });

    test('skips rows with fewer than 3 cells', () {
      const html = '''
<table id="Table1">
<tr><th>Subject</th><th>Score</th><th>Avg</th></tr>
<tr><td>國文</td><td>85</td><td>72</td></tr>
<tr><td></td><td></td><td></td></tr>
<tr><td>Math</td><td>90</td></tr>
</table>
''';
      final data = HtmlParser.parseExamScores(html);
      expect(data.subjects.length, 1);
      expect(data.subjects[0].subject, '國文');
    });

    test('handles HTML entities in content', () {
      const html = '''
<table id="Table1">
<tr><th>科目</th><th>成績</th><th>平均</th></tr>
<tr><td>Art &amp; Design</td><td>95</td><td>80</td></tr>
</table>
''';
      final data = HtmlParser.parseExamScores(html);
      expect(data.subjects[0].subject, 'Art & Design');
    });

    test('handles decimal HTML entities', () {
      const html = '''
<table id="Table1">
<tr><th>X</th><th>Y</th><th>Z</th></tr>
<tr><td>&#65;</td><td>90</td><td>80</td></tr>
</table>
''';
      final data = HtmlParser.parseExamScores(html);
      expect(data.subjects[0].subject, 'A');
    });

    test('handles hex HTML entities', () {
      const html = '''
<table id="Table1">
<tr><th>X</th><th>Y</th><th>Z</th></tr>
<tr><td>&#x42;</td><td>90</td><td>80</td></tr>
</table>
''';
      final data = HtmlParser.parseExamScores(html);
      expect(data.subjects[0].subject, 'B');
    });

    test('strips nested HTML tags', () {
      const html = '''
<table id="Table1">
<tr><th>X</th><th>Y</th><th>Z</th></tr>
<tr><td><b>Bold</b></td><td>90</td><td>80</td></tr>
</table>
''';
      final data = HtmlParser.parseExamScores(html);
      expect(data.subjects[0].subject, 'Bold');
    });

    test('handles &nbsp; entity', () {
      const html = '''
<table id="Table1">
<tr><th>X</th><th>Y</th><th>Z</th></tr>
<tr><td>Hello&nbsp;World</td><td>90</td><td>80</td></tr>
</table>
''';
      final data = HtmlParser.parseExamScores(html);
      expect(data.subjects[0].subject, 'Hello World');
    });

    test('returns empty data for empty HTML', () {
      final data = HtmlParser.parseExamScores('');
      expect(data.subjects, isEmpty);
      expect(data.examInfo, '');
    });

    test('parses complete page with all sections', () {
      const html = '''
<div>學號：99999</div>
<span class="bluetext">113-1 期中考</span>
<table id="Table1">
<tr><th>科目</th><th>成績</th><th>平均</th></tr>
<tr><td>物理</td><td>88</td><td>65</td></tr>
<tr><td>化學</td><td>92</td><td>70</td></tr>
</table>
''';
      final data = HtmlParser.parseExamScores(html);
      expect(data.studentInfo.studentId, '99999');
      expect(data.examInfo, '113-1 期中考');
      expect(data.subjects.length, 2);
    });

    test('handles &lt; &gt; &quot; &apos; entities', () {
      const html = '''
<table id="Table1">
<tr><th>X</th><th>Y</th><th>Z</th></tr>
<tr><td>&lt;tag&gt;</td><td>&quot;val&quot;</td><td>&apos;x&apos;</td></tr>
</table>
''';
      final data = HtmlParser.parseExamScores(html);
      expect(data.subjects[0].subject, '<tag>');
      expect(data.subjects[0].personalScore, '"val"');
      expect(data.subjects[0].classAverage, "'x'");
    });
  });
}
