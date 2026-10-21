
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/expert.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart';



String _formatPdfDateValue(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) {
    return 'غير متوفر';
  }

  try {
    final raw = value.toString().trim();
    final date = DateTime.parse(raw.replaceFirst(' ', 'T'));

    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    // استخدام الشرطة العادية بدل الفواصل السابقة.
    return '$year-$month-$day $hour:$minute';
  } catch (_) {
    return value.toString();
  }
}

String _formatPdfDuration(dynamic value) {
  if (value == null || value is! num) {
    return 'غير متوفر';
  }

  final seconds = value.round();
  if (seconds < 0) return 'وقت غير صحيح';

  final duration = Duration(seconds: seconds);
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);
  final remainingSeconds = duration.inSeconds.remainder(60);

  if (days > 0) {
    return '$days يوم، $hours ساعة، $minutes دقيقة';
  }
  if (hours > 0) {
    return '$hours ساعة، $minutes دقيقة';
  }
  if (minutes > 0) {
    return '$minutes دقيقة';
  }
  return '$remainingSeconds ثانية';
}


Future<Uint8List> _buildReportPdfInBackground(
  Map<String, dynamic> input,
) async {
  final fontBytes = input['fontBytes'] as Uint8List;
  final font = pw.Font.ttf(ByteData.sublistView(fontBytes));
  final pdf = pw.Document();

  final details = List<Map<String, dynamic>>.from(
    (input['details'] as List).map(
      (item) => Map<String, dynamic>.from(item as Map),
    ),
  );

  // عرض التاريخ والأرقام من اليسار إلى اليمين.
  pw.Widget dateCell(String value) {
    return pw.Directionality(
      textDirection: pw.TextDirection.ltr,
      child: pw.Text(
        value,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: pw.Font.helvetica(),
          fontSize: 7,
        ),
      ),
    );
  }

  // عرض النصوص العربية من اليمين إلى اليسار.
  pw.Widget arabicCell(String value) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Text(
        value,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(
          font: font,
          fontSize: 8,
        ),
      ),
    );
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
      ),
      maxPages: 500,
      build: (context) => [
        // معلومات التقرير.
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  'التقرير التفصيلي لإجابات الخبراء',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'اسم الخبير: ${input['expertName']}',
                style: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 4),

              // فصل التاريخ عن النص العربي.
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'الفترة: ',
                    style: pw.TextStyle(font: font),
                  ),
                  pw.Directionality(
                    textDirection: pw.TextDirection.ltr,
                    child: pw.Text(
                      '${input['startDate']} - ${input['endDate']}',
                      style: pw.TextStyle(
                        font: pw.Font.helvetica(),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 4),
              pw.Text(
                'عدد الإجابات: ${details.length}',
                style: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 12),
            ],
          ),
        ),

        // جدول الإجابات.
        pw.TableHelper.fromTextArray(
          headers: const [
            'نص الاستفسار',
            'تاريخ ووقت الاستفسار',
            'نص الرد',
            'تاريخ ووقت الرد',
            'الفارق الزمني',
          ],
          data: details.map((item) {
            return [
              item['question']?.toString() ?? '',
              _formatPdfDateValue(item['question_date']),
              item['answer']?.toString() ?? '',
              _formatPdfDateValue(item['diagnosis_date']),
              _formatPdfDuration(item['response_seconds']),
            ];
          }).toList(),

          cellBuilder: (columnIndex, cellValue, rowIndex) {
            final value = cellValue.toString();

            // صف العناوين.
            if (rowIndex == 0) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Text(
                  value,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              );
            }

            // عمودا التاريخ والوقت.
            if (columnIndex == 1 || columnIndex == 3) {
              return dateCell(value);
            }

            // النصوص العربية وبقية الأعمدة.
            return arabicCell(value);
          },

          headerStyle: pw.TextStyle(
            font: font,
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: pw.TextStyle(
            font: font,
            fontSize: 7,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColors.teal100,
          ),
          border: pw.TableBorder.all(
            color: PdfColors.grey600,
          ),
          cellAlignment: pw.Alignment.centerRight,
          headerAlignment: pw.Alignment.center,
          cellPadding: const pw.EdgeInsets.all(4),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.2),
            1: const pw.FlexColumnWidth(1.3),
            2: const pw.FlexColumnWidth(2.5),
            3: const pw.FlexColumnWidth(1.3),
            4: const pw.FlexColumnWidth(1.5),
          },
        ),
      ],
    ),
  );

  return pdf.save();
}



class AnsweredDetailsReportScreen extends StatefulWidget {
  final int adminExpertId;

  const AnsweredDetailsReportScreen({
    super.key,
    required this.adminExpertId,
  });

  @override
  State<AnsweredDetailsReportScreen> createState() =>
      _AnsweredDetailsReportScreenState();
}

class _AnsweredDetailsReportScreenState
    extends State<AnsweredDetailsReportScreen> {
  List<Expert> experts = [];
  List<dynamic> details = [];

  int? selectedExpertId;
  DateTime? startDate;
  DateTime? endDate;

  bool loadingExperts = true;
  bool loadingReport = false;
  String? error;

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';

    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _displayDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return 'غير متوفر';
    }

    return value.toString().replaceFirst('T', ' ');
  }

  // هذه هي دالة الخطوة الثالثة: تحويل الثواني إلى مدة مقروءة.
  String formatResponseDuration(dynamic value) {
    if (value == null) return 'غير متوفر';

    final seconds = (value as num).round();

    if (seconds < 0) return 'وقت غير صحيح';

    final duration = Duration(seconds: seconds);
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final remainingSeconds = duration.inSeconds.remainder(60);

    if (days > 0) {
      return '$days يوم، $hours ساعة، $minutes دقيقة';
    }

    if (hours > 0) {
      return '$hours ساعة، $minutes دقيقة';
    }

    if (minutes > 0) {
      return '$minutes دقيقة';
    }

    return '$remainingSeconds ثانية';
  }

  @override
  void initState() {
    super.initState();
    _loadExperts();
  }

  Future<void> _loadExperts() async {
    try {
      final data = await ApiService.getExperts();

      if (!mounted) return;

      setState(() {
        experts = data;
        loadingExperts = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingExperts = false;
        error = 'تعذر تحميل قائمة الخبراء: $e';
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? startDate ?? DateTime.now()
        : endDate ?? startDate ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isStart
          ? 'اختر تاريخ البداية'
          : 'اختر تاريخ النهاية',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        startDate = picked;
      } else {
        endDate = picked;
      }

      details = [];
      error = null;
    });
  }

  Future<void> _loadReport() async {
    if (selectedExpertId == null) {
      setState(() {
        error = 'يرجى اختيار الخبير أولاً';
        details = [];
      });
      return;
    }

    if (startDate != null &&
        endDate != null &&
        startDate!.isAfter(endDate!)) {
      setState(() {
        error = 'تاريخ البداية يجب ألا يكون بعد تاريخ النهاية';
        details = [];
      });
      return;
    }

    setState(() {
      loadingReport = true;
      error = null;
      details = [];
    });

    try {
      final result = await ApiService.getAnsweredDetailsReport(
        adminExpertId: widget.adminExpertId,
        expertId: selectedExpertId!,
        startDate: startDate,
        endDate: endDate,
      );

      if (!mounted) return;

      setState(() {
        details = List<dynamic>.from(result['details'] ?? []);
        loadingReport = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingReport = false;
        error = 'تعذر تحميل التقرير التفصيلي: $e';
      });
    }
  }


  String get _selectedExpertName {
    final matches = experts.where((e) => e.id == selectedExpertId);
    return matches.isEmpty ? '' : matches.first.name;
  }

  Future<pw.Font> _loadArabicPdfFont() async {
    final fontData = await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
    return pw.Font.ttf(fontData);
  }

Future<Uint8List> _createReportPdf() async {
  final fontData = await rootBundle.load(
    'assets/fonts/NotoNaskhArabic-Regular.ttf',
  );

  final fontBytes = fontData.buffer.asUint8List(
    fontData.offsetInBytes,
    fontData.lengthInBytes,
  );

  final input = <String, dynamic>{
    'fontBytes': fontBytes,
    'expertName': _selectedExpertName,
    'startDate': _formatDate(startDate),
    'endDate': _formatDate(endDate),
    'details': details.map((item) {
      return Map<String, dynamic>.from(item as Map);
    }).toList(),
  };

  return compute(_buildReportPdfInBackground, input);
}

  
bool generatingPdf = false;

Future<void> _printReport() async {
  if (generatingPdf || details.isEmpty) return;

  setState(() => generatingPdf = true);

  try {
    final bytes = await _createReportPdf();

    if (!mounted) return;

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'answered_details_report.pdf',
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تعذرت الطباعة: $e')),
    );
  } finally {
    if (mounted) {
      setState(() => generatingPdf = false);
    }
  }
}

Future<void> _exportReportPdf() async {
  if (generatingPdf || details.isEmpty) return;

  setState(() => generatingPdf = true);

  try {
    final bytes = await _createReportPdf();

    if (!mounted) return;

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'answered_details_report.pdf',
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تعذر إنشاء أو مشاركة PDF: $e')),
    );
  } finally {
    if (mounted) {
      setState(() => generatingPdf = false);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final selectedExpert = experts.where(
      (e) => e.id == selectedExpertId,
    );

    final expertName = selectedExpert.isEmpty
        ? ''
        : selectedExpert.first.name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقرير التفصيلي'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: loadingExperts
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedExpertId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'اختر الخبير',
                      border: OutlineInputBorder(),
                    ),
                    items: experts.map((expert) {
                      return DropdownMenuItem<int>(
                        value: expert.id,
                        child: Text(expert.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedExpertId = value;
                        details = [];
                        error = null;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            'البداية: ${_formatDate(startDate)}',
                          ),
                          onPressed: () => _pickDate(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event),
                          label: Text(
                            'النهاية: ${_formatDate(endDate)}',
                          ),
                          onPressed: () => _pickDate(isStart: false),
                        ),
                      ),
                    ],
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          startDate = null;
                          endDate = null;
                          details = [];
                          error = null;
                        });
                      },
                      child: const Text('مسح التواريخ'),
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.description),
                      label: const Text('عرض التقرير التفصيلي'),
                      onPressed:
                          loadingReport ? null : _loadReport,
                    ),
                  ),

                  const SizedBox(height: 8),
                  
if (!loadingReport && details.isNotEmpty)
  Column(
    children: [
      if (generatingPdf)
        const Padding(
          padding: EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('جارٍ تجهيز ملف PDF...'),
            ],
          ),
        ),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: generatingPdf ? null : _printReport,
              icon: const Icon(Icons.print),
              label: const Text('طباعة التقرير'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: generatingPdf ? null : _exportReportPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('تصدير PDF'),
            ),
          ),
        ],
      ),
    ],
  ),

                  const SizedBox(height: 12),

                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),

                  if (loadingReport)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),

                  if (!loadingReport &&
                      details.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'اسم الخبير: $expertName',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'الفترة: ${_formatDate(startDate)}'
                        ' إلى ${_formatDate(endDate)}',
                      ),
                    ),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'عدد الإجابات: ${details.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  Expanded(
                    child: loadingReport
                        ? const SizedBox.shrink()
                        : details.isEmpty
                            ? Center(
                                child: Text(
                                  error != null
                                      ? 'تعذر عرض التقرير'
                                      : selectedExpertId == null
                                          ? 'اختر الخبير والفترة ثم اعرض التقرير'
                                          : 'لا توجد إجابات ضمن الفترة المحددة',
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : SingleChildScrollView(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor:
                                        WidgetStatePropertyAll(
                                      Colors.teal.shade50,
                                    ),
                                    columnSpacing: 18,
                                    dataRowMinHeight: 60,
                                    dataRowMaxHeight: 180,
                                    columns: const [
                                      DataColumn(
                                        label: Text('نص الاستفسار'),
                                      ),
                                      DataColumn(
                                        label: Text('تاريخ ووقت الاستفسار'),
                                      ),
                                      DataColumn(
                                        label: Text('نص الرد'),
                                      ),
                                      DataColumn(
                                        label: Text('تاريخ ووقت الرد'),
                                      ),
                                      DataColumn(
                                        label: Text('الفارق الزمني'),
                                      ),
                                    ],
                                    rows: details.map((rawItem) {
                                      final item =
                                          Map<String, dynamic>.from(
                                        rawItem as Map,
                                      );

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            SizedBox(
                                              width: 220,
                                              child: Text(
                                                item['question']
                                                        ?.toString() ??
                                                    '',
                                                softWrap: true,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 155,
                                              child: Text(
                                                _displayDateTime(
                                                  item['question_date'],
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 250,
                                              child: Text(
                                                item['answer']
                                                        ?.toString() ??
                                                    '',
                                                softWrap: true,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 155,
                                              child: Text(
                                                _displayDateTime(
                                                  item['diagnosis_date'],
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 150,
                                              child: Text(
                                                formatResponseDuration(
                                                  item['response_seconds'],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                  ),
                ],
              ),
            ),
    );
  }
}
