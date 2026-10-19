
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/expert.dart';
import '../services/api_service.dart';

class AnsweredReportScreen extends StatefulWidget {
  final int adminExpertId;

  const AnsweredReportScreen({
    super.key,
    required this.adminExpertId,
  });

  @override
  State<AnsweredReportScreen> createState() =>
      _AnsweredReportScreenState();
}

class _AnsweredReportScreenState
    extends State<AnsweredReportScreen> {
  List<Expert> experts = [];
  List<dynamic> report = [];

  int? selectedExpertId;
  DateTime? startDate;
  DateTime? endDate;

  bool loadingExperts = true;
  bool loadingReport = false;
  String? error;

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
      helpText: isStart ? 'اختر تاريخ البداية' : 'اختر تاريخ النهاية',
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
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadReport() async {
    if (startDate != null &&
        endDate != null &&
        startDate!.isAfter(endDate!)) {
      setState(() {
        error = 'تاريخ البداية يجب ألا يكون بعد تاريخ النهاية';
        report = [];
      });
      return;
    }

    setState(() {
      loadingReport = true;
      error = null;
      report = [];
    });

    try {
      final result = await ApiService.getAnsweredReport(
        adminExpertId: widget.adminExpertId,
        expertId: selectedExpertId,
        startDate: startDate,
        endDate: endDate,
      );

      if (!mounted) return;

      setState(() {
        report = List<dynamic>.from(result['experts'] ?? []);
        loadingReport = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingReport = false;
        error = 'تعذر تحميل التقرير: $e';
      });
    }
  }


  Future<pw.Font> _loadArabicPdfFont() async {
    final fontData = await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
    return pw.Font.ttf(fontData);
  }

  Future<Uint8List> _createReportPdf() async {
    final font = await _loadArabicPdfFont();
    final pdf = pw.Document();
    final rows = report.map((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      return [
        item['expert_name']?.toString() ?? 'خبير غير معروف',
        '${item['answered_count'] ?? 0}',
      ];
    }).toList();

    final matches = experts.where((e) => e.id == selectedExpertId);
    final selectedName = selectedExpertId == null
        ? 'جميع الخبراء'
        : (matches.isEmpty ? '' : matches.first.name);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(child: pw.Text('تقرير إجابات الخبراء',
                    style: pw.TextStyle(font: font, fontSize: 20, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 12),
                pw.Text('الخبير: $selectedName'),
                pw.SizedBox(height: 4),
                pw.Text('الفترة: ${_formatDate(startDate)} إلى ${_formatDate(endDate)}'),
                pw.Text('عدد الخبراء في التقرير: ${report.length}'),
                pw.SizedBox(height: 16),
                pw.TableHelper.fromTextArray(
                  headers: ['اسم الخبير', 'عدد الإجابات'],
                  data: rows,
                  headerStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 11),
                  cellStyle: pw.TextStyle(font: font, fontSize: 10),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.green100),
                  border: pw.TableBorder.all(color: PdfColors.grey600),
                  cellAlignment: pw.Alignment.centerRight,
                  headerAlignment: pw.Alignment.centerRight,
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
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'answered_experts_report.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذرت الطباعة: $e')));
    }
  }

  Future<void> _exportReportPdf() async {
    try {
      final bytes = await _createReportPdf();
      await Printing.sharePdf(bytes: bytes, filename: 'answered_experts_report.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء أو مشاركة PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير إجابات الخبراء'),
        backgroundColor: Colors.green.shade700,
      ),
      body: loadingExperts
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<int?>(
                    value: selectedExpertId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'اختر الخبير',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('جميع الخبراء'),
                      ),
                      ...experts.map(
                        (expert) => DropdownMenuItem<int?>(
                          value: expert.id,
                          child: Text(expert.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => selectedExpertId = value);
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
                        });
                      },
                      child: const Text('مسح التواريخ'),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.bar_chart),
                      label: const Text('عرض التقرير'),
                      onPressed: loadingReport ? null : _loadReport,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (report.isNotEmpty)
                    Row(
                      children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: loadingReport ? null : _printReport,
                          icon: const Icon(Icons.print),
                          label: const Text('طباعة التقرير'),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton.icon(
                          onPressed: loadingReport ? null : _exportReportPdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('تصدير PDF'),
                        )),
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
                    const CircularProgressIndicator(),
                  Expanded(
                    child: report.isEmpty
                        ? const Center(
                            child: Text('اختر الخيارات ثم اضغط عرض التقرير'),
                          )
                        : ListView.builder(
                            itemCount: report.length,
                            itemBuilder: (context, index) {
                              final item = report[index]
                                  as Map<String, dynamic>;

                              final name =
                                  item['expert_name']?.toString() ??
                                      'خبير غير معروف';
                              final count =
                                  item['answered_count'] ?? 0;

                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        Colors.green.shade100,
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.green,
                                    ),
                                  ),
                                  title: Text(name),
                                  trailing: Text(
                                    '$count إجابة',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
