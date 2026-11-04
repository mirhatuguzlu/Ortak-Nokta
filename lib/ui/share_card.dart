import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../engine/meeting_engine.dart';
import '../models.dart';
import '../services/planner.dart';
import 'theme.dart';

String mapsLink(Plan plan) =>
    'https://www.google.com/maps/search/?api=1&query=${plan.result.point.latitude.toStringAsFixed(6)},'
    '${plan.result.point.longitude.toStringAsFixed(6)}';

List<int> buffersOf(List<Participant> people) => [for (final p in people) p.lateBuffer];

String shareText(Plan plan, List<Participant> people, DateTime arrival, {String spot = ''}) {
  final leave = departures(arrival, plan.result.legs, buffersOf(people));
  return [
    '📍 ${plan.label} · ${formatClock(arrival)}',
    if (spot.trim().isNotEmpty) '📌 Tam yer: ${spot.trim()}',
    for (var i = 0; i < people.length; i++)
      '${people[i].name}: ${formatDuration(plan.result.legs[i].seconds)} (çıkış ${formatClock(leave[i])}'
          '${people[i].lateBuffer > 0 ? ', +${people[i].lateBuffer} dk pay' : ''})',
    mapsLink(plan),
    'Ortak Nokta ile adil buluşma noktası bulundu${siteUrl.isEmpty ? '' : ': $siteUrl'}',
  ].join('\n');
}

/// Önizlemeyi gösterir; "Paylaş" kartı görsel + metin olarak paylaşır.
Future<void> showShareSheet(BuildContext context, Plan plan, List<Participant> people, DateTime arrival,
    {String spot = ''}) {
  final boundary = GlobalKey();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Gruba gönder', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Flexible(
            child: FittedBox(
              child: RepaintBoundary(key: boundary, child: ShareCard(plan: plan, people: people, arrival: arrival)),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.ios_share),
            label: const Text('Görsel olarak paylaş'),
            onPressed: () async {
              final text = shareText(plan, people, arrival, spot: spot);
              try {
                final obj = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
                final image = await obj.toImage(pixelRatio: 3);
                final png = await image.toByteData(format: ui.ImageByteFormat.png);
                await SharePlus.instance.share(ShareParams(
                  text: text,
                  files: [XFile.fromData(png!.buffer.asUint8List(), mimeType: 'image/png', name: 'ortak-nokta.png')],
                ));
              } catch (_) {
                // Görsel üretilemezse (eski cihaz, web) en azından metin gitsin.
                await SharePlus.instance.share(ShareParams(text: text));
              }
            },
          ),
          TextButton(
            onPressed: () => SharePlus.instance.share(ShareParams(text: shareText(plan, people, arrival, spot: spot))),
            child: const Text('Yalnızca metin gönder'),
          ),
        ]),
      ),
    ),
  );
}

/// WhatsApp grubuna / hikâyeye giden kart. Sabit boyut: her cihazda aynı görünür.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.plan, required this.people, required this.arrival});
  final Plan plan;
  final List<Participant> people;
  final DateTime arrival;

  @override
  Widget build(BuildContext context) {
    final legs = plan.result.legs;
    final leave = departures(arrival, legs, buffersOf(people));
    final longest = plan.result.maxSeconds;
    const ink = Palette.ink, muted = Palette.inkSoft;
    return SizedBox(
      width: 360,
      height: 450,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Palette.green, Palette.greenDeep],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(children: [
              Icon(Icons.join_inner, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('Ortak Nokta',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Palette.card, borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('BULUŞMA · ${formatClock(arrival)}',
                        style: const TextStyle(color: Palette.clay, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    Text(plan.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w800, height: 1.2)),
                    const Spacer(),
                    for (var i = 0; i < people.length; i++) ...[
                      Row(children: [
                        CircleAvatar(
                            radius: 11,
                            backgroundColor: people[i].color,
                            child: Icon(people[i].mode.icon, size: 13, color: Colors.white)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(people[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        Text('çıkış ${formatClock(leave[i])}  ', style: const TextStyle(color: muted, fontSize: 11)),
                        Text(formatDuration(legs[i].seconds),
                            style: const TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: longest == 0 ? 1 : (legs[i].seconds / longest).clamp(0.04, 1),
                          minHeight: 5,
                          color: people[i].color,
                          backgroundColor: Palette.paper,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const Spacer(),
                    Row(children: [
                      const Icon(Icons.balance, size: 16, color: Palette.clay),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          plan.result.gapSeconds < 60
                              ? 'Herkes neredeyse aynı sürede varıyor'
                              : 'En hızlı ile en yavaş arası ${formatDuration(plan.result.gapSeconds)}',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              siteUrl.isEmpty ? 'Ortada değil, adil buluşun.' : Uri.parse(siteUrl).host,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ]),
        ),
      ),
    );
  }
}
