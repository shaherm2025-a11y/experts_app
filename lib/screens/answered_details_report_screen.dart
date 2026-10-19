
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/expert.dart';
import '../services/api_service.dart';

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
    final font = await _loadArabicPdfFont();
    final pdf = pw.Document();
    final rows = details.map((rawItem) {
      final item = Map<String, dynamic>.from(rawItem as Map);
      return [
        item['question']?.toString() ?? '',
        _displayDateTime(item['question_date']),
        item['answer']?.toString() ?? '',
        _displayDateTime(item['diagnosis_date']),
        formatResponseDuration(item['response_seconds']),
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(child: pw.Text('التقرير التفصيلي لإجابات الخبراء',
                    style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 10),
                pw.Text('اسم الخبير: $_selectedExpertName'),
                pw.SizedBox(height: 4),
                pw.Text('الفترة: ${_formatDate(startDate)} إلى ${_formatDate(endDate)}'),
                pw.Text('عدد الإجابات: ${details.length}'),
                pw.SizedBox(height: 14),
                pw.TableHelper.fromTextArray(
                  headers: ['نص الاستفسار', 'تاريخ ووقت الاستفسار', 'نص الرد', 'تاريخ ووقت الرد', 'الفارق الزمني'],
                  data: rows,
                  headerStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 9),
                  cellStyle: pw.TextStyle(font: font, fontSize: 8),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal100),
                  border: pw.TableBorder.all(color: PdfColors.grey600),
                  cellAlignment: pw.Alignment.centerRight,
                  headerAlignment: pw.Alignment.centerRight,
                  cellPadding: const pw.EdgeInsets.all(5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  Future<void> _printReport() async {
    try {
      final bytes = await _createReportPdf();
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'answered_details_report.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذرت الطباعة: $e')));
    }
  }

  Future<void> _exportReportPdf() async {
    try {
      final bytes = await _createReportPdf();
      await Printing.sharePdf(bytes: bytes, filename: 'answered_details_report.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء أو مشاركة PDF: $e')));
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
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _printReport,
                            icon: const Icon(Icons.print),
                            label: const Text('طباعة التقرير'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _exportReportPdf,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('تصدير PDF'),
                          ),
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
