import 'dart:io';
import 'dart:convert';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note.dart';
import '../models/task.dart';

class ExportService {
  Future<void> exportToJSON(List<MyNote> notes, List<Task> tasks) async {
    final data = {
      'notes': notes.map((n) => n.toMap()).toList(),
      'tasks': tasks.map((t) => t.toMap()).toList(),
    };
    final jsonString = jsonEncode(data);
    await Share.share(jsonString, subject: 'App Data Export (JSON)');
  }

  Future<void> exportToText(List<MyNote> notes, List<Task> tasks) async {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('--- PERSONAL NOTES ---\n');
    for (var note in notes) {
      buffer.writeln('Title: ${note.title}');
      buffer.writeln('Content: ${note.content}');
      buffer.writeln('Updated: ${note.updatedAt}');
      buffer.writeln('---------------------\n');
    }
    buffer.writeln('--- TASKS ---\n');
    for (var task in tasks) {
      buffer.writeln('Task: ${task.title}');
      buffer.writeln('Status: ${task.status.name}');
      buffer.writeln('Priority: ${task.priority.name}');
      buffer.writeln('---------------------\n');
    }
    await Share.share(buffer.toString(), subject: 'App Data Export (Text)');
  }

  Future<void> exportToPDF(List<MyNote> notes, List<Task> tasks) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Personal Notes & Tasks Report')),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 10)),
          pw.Header(level: 1, child: pw.Text('Notes')),
          ...notes.map((note) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(note.title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(note.content),
              pw.Divider(),
            ],
          )),
          pw.Header(level: 1, child: pw.Text('Tasks')),
          ...tasks.map((task) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(task.title),
              pw.Text(task.status.name),
            ],
          )),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/export.pdf");
    await file.writeAsBytes(await pdf.save());
    
    await Share.shareXFiles([XFile(file.path)], text: 'App Data Export (PDF)');
  }
}
