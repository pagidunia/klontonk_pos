import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../domain/cart.dart';
import '../../domain/receipt.dart';
import '../../services/receipt_printer.dart';
import '../../services/services.dart';
import '../../viewmodels/app_deps.dart';
import '../../viewmodels/kasir_view_model.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/scanner_page.dart';

class KasirPage extends StatelessWidget {
  const KasirPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDeps>();
    return ChangeNotifierProvider(
      create: (_) => KasirViewModel(stock: deps.stock, sales: deps.sales, session: deps.session, toast: deps.toast),
      child: const _KasirView(),
    );
  }
}

class _KasirView extends StatefulWidget {
  const _KasirView();

  @override
  State<_KasirView> createState() => _KasirViewState();
}

class _KasirViewState extends State<_KasirView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final vm = context.read<KasirViewModel>();
    final toast = context.read<AppDeps>().toast;
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    final found = vm.stock.findByBarcode(code);
    if (found == null) {
      toast.show('Barcode $code belum terdaftar di Stok Awal', type: ToastType.warning, duration: const Duration(milliseconds: 4500));
    } else if (!found.isSellable) {
      toast.show('"${found.name}" ${found.hasPrice ? 'stok habis' : 'belum ada harga'}', type: ToastType.warning);
    } else {
      final msg = vm.addItem(found);
      toast.show(msg ?? '${found.name} ditambahkan', type: msg == null ? ToastType.success : ToastType.warning, duration: const Duration(milliseconds: 1800));
    }
  }

  void _submitSearch(String text) {
    final vm = context.read<KasirViewModel>();
    final found = text.trim().isEmpty ? null : vm.stock.findByBarcode(text);
    if (found != null && found.isSellable) {
      vm.addItem(found);
      _search.clear();
      vm.setQuery('');
    }
  }

  void _openCart() {
    final vm = context.read<KasirViewModel>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => ChangeNotifierProvider.value(value: vm, child: const _CartSheet()),
    ).then((_) => vm.closeReceipt());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vm = context.watch<KasirViewModel>();
    final items = vm.visible;
    final sum = vm.summary;

    return Stack(children: [
      CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                PageHeader(greeting: 'Kasir · ${vm.session.currentTenant.name}', title: 'Transaksi', subtitle: 'Cari atau scan barang, atur jumlah di keranjang, lalu terima pembayaran.'),
                Row(children: [
                  Expanded(child: TextField(controller: _search, onChanged: vm.setQuery, onSubmitted: _submitSearch, textInputAction: TextInputAction.search, decoration: const InputDecoration(hintText: 'Cari nama atau barcode', prefixIcon: Icon(Icons.search)))),
                  const SizedBox(width: 10),
                  SizedBox(height: 52, width: 52, child: OutlinedButton(onPressed: _scan, style: OutlinedButton.styleFrom(padding: EdgeInsets.zero), child: const Icon(Icons.qr_code_scanner))),
                ]),
                Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('${vm.itemCountAll} barang · ${vm.sellableCount} siap dijual', style: TextStyle(fontSize: 12.5, color: p.textMuted))),
                if (vm.itemCountAll == 0)
                  EmptyNote(vm.session.can('/stok/awal') ? 'Belum ada barang. Tambahkan dulu di menu Stok Awal.' : 'Belum ada barang. Stok diinput oleh tenantnya sendiri.')
                else if (items.isEmpty)
                  EmptyNote('Tidak ada barang untuk “${vm.query}”.'),
              ]),
            ),
          ),
          // Grid lazy: hanya kartu yang terlihat di layar yang dibangun (daftar barang bisa ratusan).
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, sum.lineCount > 0 ? 96 : 24),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.35),
              itemCount: items.length,
              itemBuilder: (_, i) => RepaintBoundary(
                child: _ItemCard(
                  key: ValueKey(items[i].id),
                  item: items[i],
                  inCart: vm.cart[items[i].id] ?? 0,
                  onTap: () {
                    final msg = vm.addItem(items[i]);
                    if (msg != null) context.read<AppDeps>().toast.show(msg, type: ToastType.warning);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      if (sum.lineCount > 0)
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: Material(
            color: p.primary,
            borderRadius: BorderRadius.circular(18),
            elevation: 6,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _openCart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Badge(label: Text('${sum.itemCount}'), child: const Icon(Icons.shopping_cart_outlined, color: Colors.white)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${sum.itemCount} barang di keranjang', style: const TextStyle(color: Colors.white70, fontSize: 12)), Text(formatRupiah(sum.total), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))])),
                  const Text('Lihat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({super.key, required this.item, required this.inCart, required this.onTap});
  final StockItem item;
  final int inCart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final sellable = item.isSellable;
    final soldOut = item.qty <= 0;
    final stockColor = soldOut ? p.danger : (item.qty <= AppConfig.lowStockMax ? p.warning : p.textMuted);
    return Opacity(
      opacity: sellable ? 1 : 0.55,
      child: Material(
        color: inCart > 0 ? p.primarySoft : p.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: sellable ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: inCart > 0 ? p.primary : p.border, width: inCart > 0 ? 1.6 : 1)),
            child: Stack(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.hasPrice ? formatRupiah(item.price!) : 'Belum ada harga', style: TextStyle(fontWeight: FontWeight.w800, color: item.hasPrice ? p.primary : p.textMuted, fontSize: item.hasPrice ? 15 : 12.5)),
                  Text(soldOut ? 'Stok habis' : 'Stok ${formatQty(item.qty)} ${item.unit}', style: TextStyle(fontSize: 11.5, color: stockColor, fontWeight: FontWeight.w600)),
                ]),
              ]),
              if (inCart > 0) Positioned(right: 0, top: 0, child: CircleAvatar(radius: 11, backgroundColor: p.primary, child: Text('$inCart', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CartSheet extends StatefulWidget {
  const _CartSheet();

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  final _cash = TextEditingController();

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final vm = context.read<KasirViewModel>();
    final deps = context.read<AppDeps>();
    final error = await vm.pay();
    if (!mounted) return;
    if (error != null) {
      deps.toast.show(error, type: ToastType.danger, duration: const Duration(seconds: 5));
      if (vm.lines.isEmpty) Navigator.pop(context);
      return;
    }
    if (vm.receipt != null && deps.prefs.autoPrint) {
      printReceipt(vm.receipt!);
    }
  }

  Future<void> _clear() async {
    final vm = context.read<KasirViewModel>();
    final yakin = await context.read<AppDeps>().dialog.confirm(title: 'Kosongkan Keranjang', message: 'Semua barang di keranjang akan dihapus. Lanjutkan?', confirmText: 'Ya, Kosongkan', cancelText: 'Batal', danger: true);
    if (!yakin) return;
    vm.clearCart();
    _cash.clear();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KasirViewModel>();
    final receipt = vm.receipt;
    return receipt != null ? _ReceiptView(receipt: receipt) : _cartView(context, vm);
  }

  Widget _cartView(BuildContext context, KasirViewModel vm) {
    final p = context.pal;
    final lines = vm.lines;
    final sum = vm.summary;
    final pay = vm.payState;
    if (lines.isEmpty) {
      return const Padding(padding: EdgeInsets.all(32), child: EmptyNote('Keranjang masih kosong'));
    }
    if (_cash.text != vm.cashText) _cash.value = TextEditingValue(text: vm.cashText, selection: TextSelection.collapsed(offset: vm.cashText.length));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Keranjang', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), Text('${sum.lineCount} jenis · ${sum.itemCount} barang', style: TextStyle(color: p.textSecondary, fontSize: 12.5))])),
            TextButton(onPressed: _clear, child: Text('Kosongkan', style: TextStyle(color: p.danger))),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
        ),
        Flexible(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), children: [
            for (final l in lines) _LineTile(line: l),
            const SizedBox(height: 14),
            SegmentTabs<String>(value: vm.method, options: {'tunai': 'Tunai', 'nontunai': 'QRIS / Transfer', if (vm.session.can('/kasir/utang')) 'utang': 'Utang'}, onChanged: vm.setMethod),
            const SizedBox(height: 14),
            if (vm.method == 'tunai') ...[
              const Text('Uang diterima', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(controller: _cash, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], onChanged: vm.setCash, decoration: const InputDecoration(prefixText: 'Rp ', hintText: '0')),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final a in cashSuggestions(pay.total)) ActionChip(label: Text(a == pay.total ? 'Uang pas' : formatRupiah(a)), onPressed: () => vm.pickCash(a))]),
              const SizedBox(height: 12),
              _ChangeBox(total: pay.total, paid: pay.paid),
            ] else if (vm.method == 'utang')
              const _DebtForm()
            else
              Text('Terima pembayaran lewat QRIS atau transfer sebesar total. Konfirmasi hanya setelah dana masuk.', style: TextStyle(color: p.textSecondary, fontSize: 13)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total', style: TextStyle(color: p.textSecondary, fontSize: 15)), Text(formatRupiah(sum.total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))]),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: pay.canPay && !vm.paying ? _pay : null, child: Text(vm.paying ? 'Memproses…' : (pay.canPay || vm.method == 'nontunai' ? (vm.method == 'utang' ? 'Catat Utang ${formatRupiah(sum.total)}' : 'Bayar ${formatRupiah(sum.total)}') : pay.hint)))),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Isian penjualan utang: nama pelanggan + foto KTP (kamera atau galeri). Foto KTP adalah data pribadi:
/// diunggah ke bucket privat dan tidak disimpan di perangkat.
class _DebtForm extends StatefulWidget {
  const _DebtForm();

  @override
  State<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends State<_DebtForm> {
  final _picker = ImagePicker();
  final _name = TextEditingController();
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _name.text = context.read<KasirViewModel>().customerName;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final vm = context.read<KasirViewModel>();
    final toast = context.read<AppDeps>().toast;
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 75, maxWidth: 1600, maxHeight: 1600, preferredCameraDevice: CameraDevice.rear);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        toast.show('Foto terlalu besar (maksimal 5 MB). Coba foto ulang.', type: ToastType.warning);
        return;
      }
      vm.setKtpPhoto(bytes);
    } catch (_) {
      toast.show('Foto tidak bisa diambil. Periksa izin kamera/galeri di pengaturan perangkat.', type: ToastType.danger);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vm = context.watch<KasirViewModel>();
    final Uint8List? foto = vm.ktpPhoto;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Nama pelanggan', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      TextField(controller: _name, onChanged: vm.setCustomerName, maxLength: 80, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Sesuai KTP', counterText: '', prefixIcon: Icon(Icons.person_outline))),
      const SizedBox(height: 14),
      const Text('Foto KTP', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      if (foto != null)
        Stack(children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(foto, height: 170, width: double.infinity, fit: BoxFit.cover)),
          Positioned(right: 6, top: 6, child: IconButton.filled(style: IconButton.styleFrom(backgroundColor: Colors.black54), icon: const Icon(Icons.close, color: Colors.white, size: 18), tooltip: 'Hapus foto', onPressed: () => vm.setKtpPhoto(null))),
        ])
      else
        Container(
          height: 110,
          width: double.infinity,
          decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.border)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.badge_outlined, color: p.textMuted, size: 30), const SizedBox(height: 4), Text('Belum ada foto KTP', style: TextStyle(color: p.textMuted, fontSize: 12.5))]),
        ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: _picking ? null : () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: Text(foto == null ? 'Foto KTP' : 'Foto ulang'))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(onPressed: _picking ? null : () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Galeri'))),
      ]),
      const SizedBox(height: 8),
      Text('Foto KTP adalah data pribadi: diunggah ke penyimpanan privat dan hanya bisa dilihat pengguna yang berhak atas cabang ini. Penjualan utang butuh internet.', style: TextStyle(fontSize: 11.5, color: p.textMuted)),
    ]);
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vm = context.read<KasirViewModel>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(line.name, style: const TextStyle(fontWeight: FontWeight.w700)), Text('${formatRupiah(line.price)} / ${line.unit}', style: TextStyle(fontSize: 12, color: p.textSecondary))])),
        Text(formatRupiah(line.subtotal), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove, size: 18), onPressed: () => vm.changeLine(line.id, -1)),
            Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.w800)),
            IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add, size: 18), onPressed: line.qty >= line.stock ? null : () => vm.changeLine(line.id, 1)),
          ]),
        ),
        IconButton(visualDensity: VisualDensity.compact, icon: Icon(Icons.delete_outline, size: 20, color: p.danger), onPressed: () => vm.removeItem(line.id)),
      ]),
    );
  }
}

class _ChangeBox extends StatelessWidget {
  const _ChangeBox({required this.total, required this.paid});
  final int total;
  final int? paid;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    String label;
    String value;
    Color color;
    if (paid == null) {
      label = 'Kembalian';
      value = '—';
      color = p.textMuted;
    } else if (paid! > AppConfig.maxPayment) {
      label = 'Nominal terlalu besar';
      value = '';
      color = p.danger;
    } else if (paid! < total) {
      label = 'Kurang';
      value = formatRupiah(total - paid!);
      color = p.danger;
    } else {
      label = 'Kembalian';
      value = formatRupiah(paid! - total);
      color = p.success;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)), Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18))]),
    );
  }
}

class _ReceiptView extends StatelessWidget {
  const _ReceiptView({required this.receipt});
  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vm = context.read<KasirViewModel>();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 28, backgroundColor: p.success.withValues(alpha: 0.15), child: Icon(Icons.check, color: p.success, size: 34)),
          const SizedBox(height: 10),
          Text(receipt.pending ? 'Tersimpan Offline' : 'Pembayaran Berhasil', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          Text(formatRupiah(receipt.total), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: p.primary)),
          const SizedBox(height: 4),
          Text('${receipt.no}\n${formatDateTime(receipt.at)} · ${receipt.cashier} · ${receipt.tenant}', textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary, fontSize: 12.5)),
          if (receipt.pending)
            Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: p.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Text('Belum terkirim ke server. Akan dikirim otomatis saat internet kembali; nomor transaksi resmi terbit setelah itu.', style: TextStyle(color: p.warning, fontSize: 12.5, fontWeight: FontWeight.w600))),
          const SizedBox(height: 10),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final l in receipt.lines) Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text('${l.name}\n${l.qty} × ${formatRupiah(l.price)}', style: const TextStyle(fontSize: 13.5))), Text(formatRupiah(l.subtotal), style: const TextStyle(fontWeight: FontWeight.w700))])),
              const Divider(),
              InfoRow('Total (${receipt.itemCount} barang)', formatRupiah(receipt.total)),
              if (receipt.isCash) ...[InfoRow('Tunai', formatRupiah(receipt.paid)), InfoRow('Kembalian', formatRupiah(receipt.change), last: true, strong: true)] else if (receipt.isDebt) ...[InfoRow('Metode', 'Utang'), InfoRow('Pelanggan', receipt.customerName ?? '-'), InfoRow('Status', 'Belum lunas', last: true, strong: true)] else InfoRow('Metode', Receipt.paymentLabel[receipt.method] ?? receipt.method, last: true),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => printReceipt(receipt), icon: const Icon(Icons.print_outlined), label: const Text('Cetak Struk'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: () {
              vm.closeReceipt();
              Navigator.pop(context);
            }, child: const Text('Transaksi Baru'))),
          ]),
        ]),
      ),
    );
  }
}
