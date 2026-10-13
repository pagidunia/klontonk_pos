import '../../core/format.dart';

typedef Json = Map<String, dynamic>;

class Tenant {
  const Tenant({required this.id, required this.name});
  final String id;
  final String name;

  factory Tenant.fromJson(Json j) => Tenant(id: j['id'] as String, name: j['name'] as String);
}

/// Akun yang sedang login (profil dari tabel `profiles`).
class UserSession {
  const UserSession({required this.id, required this.username, required this.name, required this.role, required this.avatar, required this.tenantId, required this.loginTime});
  final String id;
  final String username;
  final String name;
  final String role;
  final String avatar;
  final String tenantId;
  final DateTime loginTime;

  bool get isAdmin => role == 'admin';

  /// Stok tenant hanya boleh diinput oleh akun tenant itu sendiri; admin hanya membaca (juga ditegakkan RLS).
  bool get canEditStock => !isAdmin;

  Json toJson() => {'id': id, 'username': username, 'name': name, 'role': role, 'avatar': avatar, 'tenant': tenantId, 'loginTime': loginTime.toIso8601String()};

  factory UserSession.fromJson(Json j) => UserSession(
        id: j['id'] as String,
        username: j['username'] as String,
        name: j['name'] as String,
        role: j['role'] as String,
        avatar: (j['avatar'] as String?) ?? '',
        tenantId: j['tenant'] as String,
        loginTime: DateTime.parse(j['loginTime'] as String),
      );

  /// Baris tabel `profiles` dengan `tenant:tenant_id`.
  factory UserSession.fromProfile(Json row, DateTime loginTime) => UserSession(
        id: row['id'] as String,
        username: row['username'] as String,
        name: row['name'] as String,
        role: row['role'] as String,
        avatar: (row['avatar'] as String?) ?? '',
        tenantId: row['tenant'] as String,
        loginTime: loginTime,
      );
}

/// Akun pada daftar user (halaman admin).
class AppUser {
  const AppUser({required this.id, required this.username, required this.name, required this.role, required this.avatar, required this.tenantId});
  final String id;
  final String username;
  final String name;
  final String role;
  final String avatar;
  final String tenantId;

  factory AppUser.fromJson(Json j) => AppUser(
        id: j['id'] as String,
        username: j['username'] as String,
        name: j['name'] as String,
        role: j['role'] as String,
        avatar: (j['avatar'] as String?) ?? '',
        tenantId: j['tenant'] as String,
      );
}

class StockItem {
  const StockItem({required this.id, required this.name, required this.qty, required this.unit, this.barcode, this.price});
  final String id;
  final String name;
  final int qty;
  final String unit;
  final String? barcode;
  final int? price;

  bool get hasPrice => price != null && price! > 0;

  /// Bisa dijual bila punya harga dan masih ada stok.
  bool get isSellable => hasPrice && qty > 0;

  StockItem copyWith({String? name, int? qty, String? unit, String? barcode, bool clearBarcode = false, int? price}) => StockItem(
        id: id,
        name: name ?? this.name,
        qty: qty ?? this.qty,
        unit: unit ?? this.unit,
        barcode: clearBarcode ? null : (barcode ?? this.barcode),
        price: price ?? this.price,
      );

  factory StockItem.fromRow(Json r) => StockItem(
        id: r['id'] as String,
        name: r['name'] as String,
        qty: (r['qty'] as num).toInt(),
        unit: r['unit'] as String,
        barcode: r['barcode'] as String?,
        price: (r['price'] as num?)?.toInt(),
      );

  Json toJson() => {'id': id, 'name': name, 'qty': qty, 'unit': unit, 'barcode': barcode, 'price': price};
  factory StockItem.fromJson(Json j) => StockItem.fromRow(j);
}

class SaleLine {
  const SaleLine({required this.id, required this.name, required this.unit, required this.qty, required this.price});
  final String id;
  final String name;
  final String unit;
  final int qty;
  final int price;

  int get subtotal => qty * price;

  Json toJson() => {'id': id, 'name': name, 'unit': unit, 'qty': qty, 'price': price};
  factory SaleLine.fromJson(Json j) => SaleLine(id: j['id'] as String, name: j['name'] as String, unit: j['unit'] as String, qty: (j['qty'] as num).toInt(), price: (j['price'] as num).toInt());

  /// Baris `sale_lines` memakai `item_id`.
  factory SaleLine.fromRow(Json j) => SaleLine(id: j['item_id'] as String, name: j['name'] as String, unit: j['unit'] as String, qty: (j['qty'] as num).toInt(), price: (j['price'] as num).toInt());
}

class Sale {
  const Sale({
    required this.no,
    required this.at,
    required this.cashier,
    required this.method,
    required this.total,
    required this.paid,
    required this.lines,
    this.offline = false,
    this.reviewNote,
    this.pending = false,
    this.failed = false,
    this.clientId,
  });

  final String no;
  final DateTime at;
  final String cashier;
  final String method; // 'tunai' | 'nontunai'
  final int total;
  final int paid;
  final List<SaleLine> lines;
  final bool offline;
  final String? reviewNote;
  final bool pending;
  final bool failed;
  final String? clientId;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.qty);

  /// Hasil RPC checkout() dan baris tabel `sales` (dengan `lines:sale_lines`).
  factory Sale.fromServer(Json j, {required bool lineFromRow}) {
    final raw = (j['lines'] as List).cast<Map<String, dynamic>>();
    return Sale(
      no: j['no'] as String,
      at: parseWaktu(j['at'] as String),
      cashier: j['cashier'] as String,
      method: j['method'] as String,
      total: (j['total'] as num).toInt(),
      paid: (j['paid'] as num).toInt(),
      offline: j['offline'] == true,
      reviewNote: (j['review_note'] as String?)?.isEmpty ?? true ? null : j['review_note'] as String,
      clientId: j['client_id'] as String?,
      lines: raw.map(lineFromRow ? SaleLine.fromRow : SaleLine.fromJson).toList(),
    );
  }
}

class StockReturn {
  const StockReturn({required this.no, required this.at, required this.cashier, required this.kind, required this.itemId, required this.name, required this.unit, required this.qty, required this.amount, required this.reason, this.note});
  final String no;
  final DateTime at;
  final String cashier;
  final String kind; // 'pelanggan' | 'supplier'
  final String itemId;
  final String name;
  final String unit;
  final int qty;
  final int amount;
  final String reason;
  final String? note;

  factory StockReturn.fromRow(Json j) => StockReturn(
        no: j['no'] as String,
        at: parseWaktu(j['at'] as String),
        cashier: j['cashier'] as String,
        kind: j['kind'] as String,
        itemId: j['item_id'] as String,
        name: j['name'] as String,
        unit: j['unit'] as String,
        qty: (j['qty'] as num).toInt(),
        amount: (j['amount'] as num).toInt(),
        reason: j['reason'] as String,
        note: j['note'] as String?,
      );
}

class AppUpdate {
  const AppUpdate({required this.id, required this.kind, required this.title, required this.description, required this.color});
  final String id;
  final String kind; // 'update' | 'maintenance'
  final String title;
  final String description;
  final String color; // '#RRGGBB'

  factory AppUpdate.fromRow(Json j) => AppUpdate(
        id: j['id'].toString(),
        kind: j['kind'] as String,
        title: j['title'] as String,
        description: (j['description'] as String?) ?? '',
        color: j['color'] as String,
      );
}

class CartLine {
  const CartLine({required this.id, required this.name, required this.unit, required this.price, required this.stock, required this.qty});
  final String id;
  final String name;
  final String unit;
  final int price;
  final int stock;
  final int qty;

  int get subtotal => price * qty;
}

/// Satu penjualan yang dibuat saat offline, menunggu dikirim ke database.
class OutboxEntry {
  const OutboxEntry({
    required this.clientId,
    required this.tenant,
    required this.userId,
    required this.cashier,
    required this.at,
    required this.method,
    required this.paid,
    required this.expectedTotal,
    required this.lines,
    this.status = 'pending',
    this.attempts = 0,
    this.error,
  });

  final String clientId;
  final String tenant;
  final String userId;
  final String cashier;
  final DateTime at;
  final String method;
  final int paid;
  final int expectedTotal;
  final List<SaleLine> lines;
  final String status; // 'pending' | 'failed'
  final int attempts;
  final String? error;

  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';

  OutboxEntry copyWith({String? status, int? attempts, String? error, bool clearError = false}) => OutboxEntry(
        clientId: clientId,
        tenant: tenant,
        userId: userId,
        cashier: cashier,
        at: at,
        method: method,
        paid: paid,
        expectedTotal: expectedTotal,
        lines: lines,
        status: status ?? this.status,
        attempts: attempts ?? this.attempts,
        error: clearError ? null : (error ?? this.error),
      );

  Json toJson() => {
        'clientId': clientId,
        'tenant': tenant,
        'userId': userId,
        'cashier': cashier,
        'at': at.toIso8601String(),
        'method': method,
        'paid': paid,
        'expectedTotal': expectedTotal,
        'lines': lines.map((l) => l.toJson()).toList(),
        'status': status,
        'attempts': attempts,
        'error': error,
      };

  factory OutboxEntry.fromJson(Json j) => OutboxEntry(
        clientId: j['clientId'] as String,
        tenant: j['tenant'] as String,
        userId: j['userId'] as String,
        cashier: j['cashier'] as String,
        at: DateTime.parse(j['at'] as String),
        method: j['method'] as String,
        paid: (j['paid'] as num).toInt(),
        expectedTotal: (j['expectedTotal'] as num).toInt(),
        lines: (j['lines'] as List).map((l) => SaleLine.fromJson(l as Json)).toList(),
        status: (j['status'] as String?) ?? 'pending',
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
        error: j['error'] as String?,
      );
}

class Note {
  const Note({required this.id, required this.text, required this.at});
  final String id;
  final String text;
  final DateTime at;

  Json toJson() => {'id': id, 'text': text, 'at': at.toIso8601String()};
  factory Note.fromJson(Json j) => Note(id: j['id'] as String, text: j['text'] as String, at: DateTime.parse(j['at'] as String));
}

class Option {
  const Option(this.value, this.label);
  final String value;
  final String label;
}
