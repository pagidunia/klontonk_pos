import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/format.dart';
import '../domain/receipt.dart';

/// Struk 58 mm (ukuran printer thermal yang umum di warung) sebagai PDF. Dibuka lewat dialog cetak
/// sistem: printer thermal/biasa yang terpasang, atau "Simpan sebagai PDF".
Future<Uint8List> buildReceiptPdf(Receipt r) async {
  final doc = pw.Document();
  final base = pw.TextStyle(fontSize: 8);
  final bold = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);

  pw.Widget row(String a, String b, {pw.TextStyle? style}) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(a, style: style ?? base), pw.Text(b, style: style ?? base)]);

  doc.addPage(pw.Page(
    pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Center(child: pw.Text(r.tenant, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
      pw.Center(child: pw.Text(r.no, style: base)),
      pw.Center(child: pw.Text(formatDateTime(r.at), style: base)),
      pw.Center(child: pw.Text('Kasir: ${r.cashier}', style: base)),
      pw.Divider(thickness: 0.5),
      for (final l in r.lines) ...[
        pw.Text(l.name, style: bold),
        row('${formatQty(l.qty)} ${l.unit} x ${formatRupiah(l.price)}', formatRupiah(l.qty * l.price)),
        pw.SizedBox(height: 2),
      ],
      pw.Divider(thickness: 0.5),
      row('Total', formatRupiah(r.total), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      if (r.isCash) ...[row('Tunai', formatRupiah(r.paid)), row('Kembalian', formatRupiah(r.change))] else row('Metode', Receipt.paymentLabel[r.method] ?? r.method),
      if (r.isDebt) ...[row('Pelanggan', r.customerName ?? '-'), row('Status', 'BELUM LUNAS', style: bold)],
      if (r.pending) pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Text('Struk sementara. Nomor transaksi resmi terbit setelah data terkirim ke server.', style: pw.TextStyle(fontSize: 7))),
      pw.SizedBox(height: 6),
      pw.Center(child: pw.Text('Terima kasih', style: base)),
    ]),
  ));
  return doc.save();
}

Future<void> printReceipt(Receipt receipt) async {
  final bytes = await buildReceiptPdf(receipt);
  await Printing.layoutPdf(name: 'Struk ${receipt.no}', onLayout: (_) async => bytes);
}
