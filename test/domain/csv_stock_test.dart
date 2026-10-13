import 'package:flutter_test/flutter_test.dart';
import 'package:klontonk_pos/data/models/models.dart';
import 'package:klontonk_pos/domain/csv_import.dart';
import 'package:klontonk_pos/domain/stock_rules.dart';

void main() {
  group('parseCsv', () {
    test('mengenali titik koma, kutip, kutip ganda, BOM, dan CRLF', () {
      final rows = parseCsv('﻿nama;jumlah\r\n"Beras; Premium";10\r\n"Kecap ""Manis""";5\r\n');
      expect(rows, [
        ['nama', 'jumlah'],
        ['Beras; Premium', '10'],
        ['Kecap "Manis"', '5'],
      ]);
    });
  });

  group('stockRowsFromCsv', () {
    test('urutan kolom bebas, kolom opsional dibaca', () {
      final r = stockRowsFromCsv('Satuan,Nama,Jumlah,Harga,Barcode\npcs,Teh,5,3500,8991\n');
      expect(r.errors, isEmpty);
      expect(r.rows.single.name, 'Teh');
      expect(r.rows.single.price, 3500);
      expect(r.rows.single.barcode, '8991');
    });

    test('kolom wajib hilang dilaporkan', () {
      final r = stockRowsFromCsv('nama,jumlah\nA,1');
      expect(r.rows, isEmpty);
      expect(r.errors.single.message, contains('satuan'));
    });

    test('baris bermasalah dilewati dengan nomor baris', () {
      final r = stockRowsFromCsv('nama,jumlah,satuan\nA,x,pcs\n,1,pcs\nB,2,pcs\n');
      expect(r.rows.map((e) => e.name), ['B']);
      expect(r.errors.map((e) => e.line), [2, 3]);
    });

    test('berkas kosong', () {
      expect(stockRowsFromCsv('').errors.single.message, 'Berkas kosong.');
    });
  });

  group('validateStock', () {
    const items = [StockItem(id: '1', name: 'Beras', qty: 1, unit: 'kg', barcode: 'ABC1234')];

    ({ValidStock? value, String? error}) v({String name = 'Gula', String qty = '5', String unit = 'kg', String barcode = '', String? ignore}) => validateStock(name: name, qty: qty, unit: unit, barcode: barcode, items: items, ignoreId: ignore);

    test('masukan valid lolos dan dirapikan', () {
      expect(v(name: '  Gula   Pasir ').value!.name, 'Gula Pasir');
    });

    test('menolak nama kosong/ganda, jumlah buruk, satuan salah', () {
      expect(v(name: '').error, isNotNull);
      expect(v(name: 'beras').error, 'Barang dengan nama itu sudah ada.');
      expect(v(qty: '-1').error, isNotNull);
      expect(v(qty: '1.5').error, isNotNull);
      expect(v(unit: 'galon').error, 'Satuan tidak valid.');
    });

    test('barcode harus unik dan berpola benar', () {
      expect(v(barcode: 'abc1234').error, contains('dipakai oleh'));
      expect(v(barcode: 'a b').error, isNotNull);
      expect(v(barcode: 'ABC1234', ignore: '1').error, isNull);
    });
  });

  test('validatePrice membatasi rentang harga', () {
    expect(validatePrice('').error, isNotNull);
    expect(validatePrice('0').error, isNotNull);
    expect(validatePrice('100000001').error, isNotNull);
    expect(validatePrice('1500').price, 1500);
  });
}
