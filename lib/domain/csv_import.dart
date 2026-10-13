/// Membaca berkas CSV untuk impor stok. Murni; validasi akhir tiap barang tetap dilakukan StockViewModel.
const maxImportRows = 500;

const _headers = {
  'name': ['nama', 'name', 'barang', 'nama barang'],
  'qty': ['jumlah', 'qty', 'stok', 'stock'],
  'unit': ['satuan', 'unit'],
  'price': ['harga', 'price'],
  'barcode': ['barcode', 'kode'],
};
const _requiredLabel = {'name': 'nama', 'qty': 'jumlah', 'unit': 'satuan'};

class ImportRow {
  const ImportRow({required this.name, required this.qty, required this.unit, this.price, this.barcode});
  final String name;
  final String qty;
  final String unit;
  final int? price;
  final String? barcode;
}

class ImportError {
  const ImportError(this.line, this.message);
  final int line;
  final String message;
}

/// Teks CSV -> baris (kolom). Mengenali koma atau titik koma, tanda kutip (termasuk kutip ganda dan
/// baris baru di dalamnya), BOM, dan CRLF. Baris kosong dilewati.
List<List<String>> parseCsv(String text) {
  final source = text.replaceFirst(RegExp('^﻿'), '');
  final firstLine = source.split(RegExp(r'\r?\n')).first;
  final delimiter = ';'.allMatches(firstLine).length > ','.allMatches(firstLine).length ? ';' : ',';
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;

  void endRow() {
    row.add(field.toString());
    field.clear();
    if (row.any((c) => c.isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < source.length; i++) {
    final ch = source[i];
    if (quoted) {
      if (ch != '"') {
        field.write(ch);
      } else if (i + 1 < source.length && source[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        quoted = false;
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == delimiter) {
      row.add(field.toString());
      field.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < source.length && source[i + 1] == '\n') i++;
      endRow();
    } else {
      field.write(ch);
    }
  }
  endRow();
  return rows;
}

/// Teks CSV -> baris barang + daftar galat (nomor baris & pesan). Baris bermasalah dilewati.
({List<ImportRow> rows, List<ImportError> errors}) stockRowsFromCsv(String text) {
  final table = parseCsv(text);
  if (table.isEmpty) return (rows: const [], errors: const [ImportError(1, 'Berkas kosong.')]);

  final header = table.first.map((c) => c.trim().toLowerCase()).toList();
  final index = {for (final e in _headers.entries) e.key: header.indexWhere((c) => e.value.contains(c))};
  final missing = _requiredLabel.keys.where((f) => index[f] == -1).toList();
  if (missing.isNotEmpty) {
    return (rows: const [], errors: [ImportError(1, 'Kolom wajib tidak ditemukan: ${missing.map((f) => _requiredLabel[f]).join(', ')}.')]);
  }

  final rows = <ImportRow>[];
  final errors = <ImportError>[];
  for (var i = 1; i < table.length; i++) {
    final line = i + 1;
    if (rows.length >= maxImportRows) {
      errors.add(ImportError(line, 'Impor dibatasi maksimal $maxImportRows barang per berkas; sisanya diabaikan.'));
      break;
    }
    String cell(String f) {
      final idx = index[f]!;
      if (idx == -1 || idx >= table[i].length) return '';
      return table[i][idx].trim();
    }

    final name = cell('name');
    final qty = cell('qty');
    final unit = cell('unit');
    final priceText = cell('price');
    final barcode = cell('barcode');

    if (name.isEmpty) {
      errors.add(ImportError(line, 'Nama barang kosong.'));
      continue;
    }
    if (!RegExp(r'^\d+$').hasMatch(qty)) {
      errors.add(ImportError(line, 'Jumlah "$qty" harus bilangan bulat 0 atau lebih.'));
      continue;
    }
    if (unit.isEmpty) {
      errors.add(ImportError(line, 'Satuan kosong.'));
      continue;
    }
    if (priceText.isNotEmpty && !RegExp(r'^\d+$').hasMatch(priceText)) {
      errors.add(ImportError(line, 'Harga "$priceText" harus bilangan bulat positif.'));
      continue;
    }
    if (priceText.isNotEmpty && int.parse(priceText) < 1) {
      errors.add(ImportError(line, 'Harga harus lebih dari 0.'));
      continue;
    }
    rows.add(ImportRow(name: name, qty: qty, unit: unit, barcode: barcode.isEmpty ? null : barcode, price: priceText.isEmpty ? null : int.parse(priceText)));
  }
  return (rows: rows, errors: errors);
}
