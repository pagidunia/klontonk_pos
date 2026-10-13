import 'package:flutter/material.dart';

import '../theme.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.greeting, required this.title, this.subtitle});
  final String greeting;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(greeting, style: TextStyle(fontSize: 13, color: p.primary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15)),
        if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle!, style: TextStyle(fontSize: 13.5, color: p.textSecondary))),
      ]),
    );
  }
}

/// Halaman standar: daftar yang bisa digulir dengan tepi 16 dp.
class PageScroll extends StatelessWidget {
  const PageScroll({super.key, required this.children, this.bottomPadding = 24});
  final List<Widget> children;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) => ListView(padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding), children: children);
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.count, this.trailing, required this.child, this.padding = const EdgeInsets.all(16), this.margin = const EdgeInsets.only(bottom: 14)});
  final String? title;
  final String? count;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  if (count != null) TextSpan(text: '  $count', style: TextStyle(fontSize: 12.5, color: p.textMuted, fontWeight: FontWeight.w600)),
                ])),
              ),
              if (trailing != null) trailing!,
            ]),
          ),
        child,
      ]),
    );
  }
}

class StatBox extends StatelessWidget {
  const StatBox({super.key, required this.label, required this.value, this.sub, this.color});
  final String label;
  final String value;
  final String? sub;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 12, color: p.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: color))),
        if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub!, style: TextStyle(fontSize: 11.5, color: p.textMuted))),
      ]),
    );
  }
}

/// Dua kolom kartu statistik; [wide] membuat satu kartu selebar baris.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 10) / 2;
          return Wrap(spacing: 10, runSpacing: 10, children: [for (final c in children) SizedBox(width: c is StatBox ? w : box.maxWidth, child: c)]);
        }),
      );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      );
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.pal.textSecondary, fontSize: 13.5)),
            if (action != null) Padding(padding: const EdgeInsets.only(top: 14), child: action),
          ]),
        ),
      );
}

class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    final p = context.pal;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(message!, style: TextStyle(color: p.danger, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

/// Satu baris label-nilai (info akun, ringkasan).
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.last = false, this.strong = false});
  final String label;
  final String value;
  final bool last;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.border))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: p.textSecondary, fontSize: 14)),
        Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w600, fontSize: 14))),
      ]),
    );
  }
}

/// Segmen pilihan (mis. Harian / Mingguan / Bulanan).
class SegmentTabs<T> extends StatelessWidget {
  const SegmentTabs({super.key, required this.value, required this.options, required this.onChanged});
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (final e in options.entries)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: e.key == value ? p.surface : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(e.value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: e.key == value ? p.primary : p.textSecondary))),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Navigasi periode: sebelumnya / label / berikutnya.
class PeriodNav extends StatelessWidget {
  const PeriodNav({super.key, required this.label, required this.isCurrent, required this.currentText, required this.onPrev, required this.onNext, required this.onToday});
  final String label;
  final bool isCurrent;
  final String currentText;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        IconButton.outlined(onPressed: onPrev, icon: const Icon(Icons.chevron_left), tooltip: 'Sebelumnya'),
        Expanded(
          child: Column(children: [
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            isCurrent ? Text(currentText, style: TextStyle(color: p.success, fontSize: 12, fontWeight: FontWeight.w700)) : GestureDetector(onTap: onToday, child: Text('Kembali ke $currentText', style: TextStyle(color: p.primary, fontSize: 12, fontWeight: FontWeight.w700))),
          ]),
        ),
        IconButton.outlined(onPressed: onNext, icon: const Icon(Icons.chevron_right), tooltip: 'Berikutnya'),
      ]),
    );
  }
}

/// Grafik batang sederhana. [values] bernilai >= 0; [labels] boleh kosong untuk batang tanpa label.
class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.values, required this.labels, this.subLabels, this.height = 120, this.color});
  final List<num> values;
  final List<String> labels;
  final List<String>? subLabels;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final peak = values.fold<num>(0, (m, v) => v > m ? v : m);
    final bar = color ?? p.primary;
    final many = values.length > 12;
    final chart = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++)
          SizedBox(
            width: many ? 14 : null,
            child: _wrap(
              many,
              Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                SizedBox(
                  height: height,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      height: values[i] == 0 || peak == 0 ? 2 : (height * (values[i] / peak)).clamp(4, height).toDouble(),
                      decoration: BoxDecoration(color: values[i] == 0 ? p.border : bar, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(_show(i, many) ? labels[i] : '', style: TextStyle(fontSize: 10, color: p.textMuted), maxLines: 1, overflow: TextOverflow.clip),
                if (subLabels != null) Text(subLabels![i], style: TextStyle(fontSize: 9, color: p.textMuted), maxLines: 1),
              ]),
            ),
          ),
      ],
    );
    return many ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: chart) : chart;
  }

  bool _show(int i, bool many) => !many || i % 3 == 0;
  Widget _wrap(bool many, Widget child) => many ? child : Expanded(child: child);
}
