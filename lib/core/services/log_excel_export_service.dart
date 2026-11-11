import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../data/models/sync_activity_log_model.dart';
import '../../data/repositories/sync_log_repository.dart';

class LogExportResult {
  final String fileName;
  final String displayPath;
  final String? filePath;
  final String? contentUri;
  final int totalLogs;
  final int authLogsCount;
  final int posLogsCount;
  final Uint8List bytes;

  const LogExportResult({
    required this.fileName,
    required this.displayPath,
    this.filePath,
    this.contentUri,
    required this.totalLogs,
    required this.authLogsCount,
    required this.posLogsCount,
    required this.bytes,
  });
}

/// Generates standards-compliant .xlsx workbooks for POS activity, login, and logout logs
/// and saves them to the device Downloads location.
class LogExcelExportService {
  LogExcelExportService._();

  static const MethodChannel _channel = MethodChannel('com.onimta.mobile_pos/file_export');
  static const String _xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  @visibleForTesting
  static Directory? debugOverrideOutputDir;

  static Future<LogExportResult> exportLogsToExcel(
    SyncLogRepository syncLogRepository, {
    Directory? overrideOutputDir,
    Future<Map<String, dynamic>> Function(String fileName, Uint8List bytes)? androidSaver,
  }) async {
    final logs = await syncLogRepository.getLogs(
      actionType: 'ALL',
      status: 'ALL',
      limit: null,
      offset: null,
    );

    final bytes = buildWorkbookBytes(logs);
    final fileName = _buildFileName(DateTime.now());
    final authCount = logs.where((l) => l.actionType.toUpperCase() == 'USER_AUTH').length;
    final posCount = logs.length - authCount;

    final effectiveOverrideDir = overrideOutputDir ?? debugOverrideOutputDir;
    if (effectiveOverrideDir != null) {
      if (!effectiveOverrideDir.existsSync()) {
        effectiveOverrideDir.createSync(recursive: true);
      }
      final file = File(p.join(effectiveOverrideDir.path, fileName));
      file.writeAsBytesSync(bytes, flush: true);
      return LogExportResult(
        fileName: fileName,
        displayPath: file.path,
        filePath: file.path,
        totalLogs: logs.length,
        authLogsCount: authCount,
        posLogsCount: posCount,
        bytes: bytes,
      );
    }

    if (androidSaver != null) {
      final res = await androidSaver(fileName, bytes);
      return LogExportResult(
        fileName: fileName,
        displayPath: (res['path'] as String?) ?? 'Downloads/$fileName',
        filePath: res['path'] as String?,
        contentUri: res['uri'] as String?,
        totalLogs: logs.length,
        authLogsCount: authCount,
        posLogsCount: posCount,
        bytes: bytes,
      );
    }

    if (!kIsWeb && Platform.isAndroid) {
      final rawRes = await _channel.invokeMapMethod<String, dynamic>('saveToDownloads', {
        'fileName': fileName,
        'mimeType': _xlsxMimeType,
        'bytes': bytes,
      });
      final savedPath = rawRes?['path'] as String? ?? 'Downloads/$fileName';
      final savedUri = rawRes?['uri'] as String?;
      return LogExportResult(
        fileName: fileName,
        displayPath: savedPath,
        filePath: savedPath.startsWith('/') ? savedPath : null,
        contentUri: savedUri,
        totalLogs: logs.length,
        authLogsCount: authCount,
        posLogsCount: posCount,
        bytes: bytes,
      );
    }

    final desktopDir = _resolveDesktopDownloadsDir();
    if (!desktopDir.existsSync()) {
      desktopDir.createSync(recursive: true);
    }
    final outFile = File(p.join(desktopDir.path, fileName));
    outFile.writeAsBytesSync(bytes, flush: true);

    return LogExportResult(
      fileName: fileName,
      displayPath: outFile.path,
      filePath: outFile.path,
      totalLogs: logs.length,
      authLogsCount: authCount,
      posLogsCount: posCount,
      bytes: bytes,
    );
  }

  static Future<bool> shareOrOpenExport(LogExportResult result) async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final ok = await _channel.invokeMethod<bool>('shareFile', {
          'uri': result.contentUri,
          'filePath': result.filePath,
          'fileName': result.fileName,
          'mimeType': _xlsxMimeType,
        });
        return ok ?? false;
      } catch (e) {
        debugPrint('Error sharing Excel log export: $e');
        return false;
      }
    }

    if (Platform.isWindows && result.filePath != null) {
      try {
        await Process.start('explorer.exe', ['/select,${result.filePath!}']);
        return true;
      } catch (_) {}
    } else if (Platform.isMacOS && result.filePath != null) {
      try {
        await Process.start('open', ['-R', result.filePath!]);
        return true;
      } catch (_) {}
    }
    return false;
  }

  /// Builds a valid multi-sheet OpenXML (.xlsx) workbook byte payload.
  static Uint8List buildWorkbookBytes(List<SyncActivityLog> logs) {
    final authLogs = logs.where((l) => l.actionType.toUpperCase() == 'USER_AUTH').toList();
    final posLogs = logs.where((l) => l.actionType.toUpperCase() != 'USER_AUTH').toList();

    final archive = Archive();

    void addXml(String path, String xmlContent) {
      final bytes = utf8.encode(xmlContent);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    addXml('[Content_Types].xml', _contentTypesXml);
    addXml('_rels/.rels', _rootRelsXml);
    addXml('xl/workbook.xml', _workbookXml);
    addXml('xl/_rels/workbook.xml.rels', _workbookRelsXml);
    addXml('xl/styles.xml', _stylesXml);
    addXml('xl/worksheets/sheet1.xml', _buildWorksheetXml(logs));
    addXml('xl/worksheets/sheet2.xml', _buildWorksheetXml(authLogs));
    addXml('xl/worksheets/sheet3.xml', _buildWorksheetXml(posLogs));

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  static Directory _resolveDesktopDownloadsDir() {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return Directory(p.join(home.trim(), 'Downloads'));
    }
    return Directory.systemTemp;
  }

  static String _buildFileName(DateTime dt) {
    String pad2(int v) => v.toString().padLeft(2, '0');
    return 'ONIMTA_POS_Logs_${dt.year}${pad2(dt.month)}${pad2(dt.day)}_${pad2(dt.hour)}${pad2(dt.minute)}${pad2(dt.second)}.xlsx';
  }

  static String _formatTimestamp(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      String p2(int v) => v.toString().padLeft(2, '0');
      return '${dt.year}-${p2(dt.month)}-${p2(dt.day)} ${p2(dt.hour)}:${p2(dt.minute)}:${p2(dt.second)}';
    } catch (_) {
      return raw;
    }
  }

  static String _columnLetter(int zeroBasedCol) {
    var index = zeroBasedCol;
    final buffer = StringBuffer();
    while (index >= 0) {
      buffer.writeCharCode(65 + (index % 26));
      index = (index ~/ 26) - 1;
    }
    return buffer.toString().split('').reversed.join();
  }

  static String _escapeXml(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), ' ');
    return cleaned
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _inlineStringCell(int row1Based, int col0Based, String value, {int styleId = 0}) {
    final cellRef = '${_columnLetter(col0Based)}$row1Based';
    final escaped = _escapeXml(value);
    return '<c r="$cellRef" t="inlineStr" s="$styleId"><is><t xml:space="preserve">$escaped</t></is></c>';
  }

  static String _numberCell(int row1Based, int col0Based, num value, {int styleId = 0}) {
    final cellRef = '${_columnLetter(col0Based)}$row1Based';
    return '<c r="$cellRef" t="n" s="$styleId"><v>$value</v></c>';
  }

  static int _statusStyleId(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
        return 2;
      case 'FAILED':
        return 3;
      default:
        return 4;
    }
  }

  static String _buildWorksheetXml(List<SyncActivityLog> rows) {
    const headers = [
      'Log ID',
      'Date & Time',
      'Category',
      'Action / Title',
      'Details',
      'Status',
      'Error Message',
      'Payload / Response',
    ];
    const widths = [10, 22, 16, 34, 58, 12, 34, 42];

    final sb = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
      ..write('<sheetViews><sheetView workbookViewId="0">')
      ..write('<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>')
      ..write('</sheetView></sheetViews>')
      ..write('<cols>');

    for (var i = 0; i < widths.length; i++) {
      final colIdx = i + 1;
      sb.write('<col min="$colIdx" max="$colIdx" width="${widths[i]}" customWidth="1"/>');
    }
    sb.write('</cols><sheetData>');

    // Header row (Row 1)
    sb.write('<row r="1" ht="24" customHeight="1">');
    for (var c = 0; c < headers.length; c++) {
      sb.write(_inlineStringCell(1, c, headers[c], styleId: 1));
    }
    sb.write('</row>');

    // Data rows
    for (var i = 0; i < rows.length; i++) {
      final rowNum = i + 2;
      final log = rows[i];
      sb.write('<row r="$rowNum">');
      if (log.id != null) {
        sb.write(_numberCell(rowNum, 0, log.id!, styleId: 0));
      } else {
        sb.write(_numberCell(rowNum, 0, i + 1, styleId: 0));
      }
      sb.write(_inlineStringCell(rowNum, 1, _formatTimestamp(log.createdAt)));
      sb.write(_inlineStringCell(rowNum, 2, log.actionType));
      sb.write(_inlineStringCell(rowNum, 3, log.title));
      sb.write(_inlineStringCell(rowNum, 4, log.details ?? ''));
      sb.write(_inlineStringCell(rowNum, 5, log.status, styleId: _statusStyleId(log.status)));
      sb.write(_inlineStringCell(rowNum, 6, log.errorMessage ?? ''));
      sb.write(_inlineStringCell(rowNum, 7, log.responseBody ?? ''));
      sb.write('</row>');
    }

    final lastRow = rows.isEmpty ? 1 : rows.length + 1;
    sb
      ..write('</sheetData>')
      ..write('<autoFilter ref="A1:H$lastRow"/>')
      ..write('</worksheet>');
    return sb.toString();
  }

  static const String _contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''';

  static const String _rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

  static const String _workbookXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="All Activity Logs" sheetId="1" r:id="rId1"/>
    <sheet name="Login &amp; Logout" sheetId="2" r:id="rId2"/>
    <sheet name="POS &amp; Shift Actions" sheetId="3" r:id="rId3"/>
  </sheets>
</workbook>''';

  static const String _workbookRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/>
  <Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

  static const String _stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="5">
    <font><sz val="11"/><name val="Calibri"/><color rgb="FF111827"/></font>
    <font><b/><sz val="11"/><name val="Calibri"/><color rgb="FFFFFFFF"/></font>
    <font><b/><sz val="11"/><name val="Calibri"/><color rgb="FF107C41"/></font>
    <font><b/><sz val="11"/><name val="Calibri"/><color rgb="FFE81123"/></font>
    <font><b/><sz val="11"/><name val="Calibri"/><color rgb="FFD83B01"/></font>
  </fonts>
  <fills count="3">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF1E2631"/><bgColor indexed="64"/></patternFill></fill>
  </fills>
  <borders count="2">
    <border><left/><right/><top/><bottom/><diagonal/></border>
    <border>
      <left style="thin"><color rgb="FFD1D5DB"/></left>
      <right style="thin"><color rgb="FFD1D5DB"/></right>
      <top style="thin"><color rgb="FFD1D5DB"/></top>
      <bottom style="thin"><color rgb="FFD1D5DB"/></bottom>
      <diagonal/>
    </border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="5">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="1" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>
    <xf numFmtId="0" fontId="1" fillId="2" borderId="1" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="center" wrapText="1"/></xf>
    <xf numFmtId="0" fontId="2" fillId="0" borderId="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="top"/></xf>
    <xf numFmtId="0" fontId="3" fillId="0" borderId="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="top"/></xf>
    <xf numFmtId="0" fontId="4" fillId="0" borderId="1" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="top"/></xf>
  </cellXfs>
</styleSheet>''';
}
