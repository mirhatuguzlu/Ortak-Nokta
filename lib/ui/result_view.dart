import 'package:flutter/material.dart';

import '../engine/meeting_engine.dart';
import '../models.dart';
import '../services/planner.dart';

/// Sonuç: buluşma yeri, kişi başı süre ve çıkış saati, gerekçeler, yakındaki mekanlar.
class ResultView extends StatelessWidget {
  const ResultView({
    super.key,
    required this.plan,
    required this.people,
    required this.arrival,
    required this.arrivalIsAuto,
    required this.saved,
    required this.venues,
    required this.venuesError,
    required this.busy,
    required this.onShare,
    required this.onDirections,
    required this.onSave,
    required this.onPickArrival,
    required this.onVenue,
    required this.onRetryVenues,
  });

  final VoidCallback onRetryVenues;

  final Plan plan;
  final List<Participant> people;
  final DateTime arrival;
  final bool arrivalIsAuto;
  final bool saved;

  /// null: yükleniyor.
  final List<Venue>? venues;
  final String? venuesError;
  final bool busy;
  final VoidCallback onShare;
  final VoidCallback onDirections;
  final VoidCallback onSave;
  final VoidCallback onPickArrival;

  /// null: adil noktaya geri dön.
  final ValueChanged<Venue?> onVenue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final legs = plan.result.legs;
    final leave = departures(arrival, legs);
    final longest = plan.result.maxSeconds;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 16),
      Card(
        color: scheme.primaryContainer,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: scheme.primary,
                child: Icon(plan.venue?.kind.icon ?? Icons.location_on, color: scheme.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(plan.label,
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
                  Text(plan.venue?.kind.label ?? 'Adil buluşma noktası',
                      style: text.bodySmall?.copyWith(color: scheme.onPrimaryContainer.withValues(alpha: 0.75))),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Material(
              color: scheme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onPickArrival,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    Icon(Icons.schedule, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        const TextSpan(text: 'Buluşma '),
                        TextSpan(text: formatClock(arrival), style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (arrivalIsAuto) const TextSpan(text: '  ·  en uzaktaki şimdi çıkarsa'),
                      ])),
                    ),
                    Text('Değiştir', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < people.length; i++)
              _PersonRow(
                person: people[i],
                leg: legs[i],
                share: longest == 0 ? 1 : legs[i].seconds / longest,
                leaveAt: leave[i],
              ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(onPressed: onShare, icon: const Icon(Icons.ios_share), label: const Text('Paylaş')),
              FilledButton.tonalIcon(
                  onPressed: onDirections, icon: const Icon(Icons.directions), label: const Text('Yol tarifi')),
              OutlinedButton.icon(
                onPressed: saved ? null : onSave,
                icon: Icon(saved ? Icons.check : Icons.bookmark_add_outlined),
                label: Text(saved ? 'Kaydedildi' : 'Buluşmayı kaydet'),
              ),
            ]),
          ]),
        ),
      ),
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const Icon(Icons.lightbulb_outline),
          title: const Text('Neden burası?'),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          children: [
            for (final r in plan.reasons)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: CircleAvatar(radius: 3, backgroundColor: scheme.primary),
                  ),
                  Expanded(child: Text(r)),
                ]),
              ),
          ],
        ),
      ),
      Row(children: [
        Text('Yakında buluşabileceğiniz yerler', style: text.titleSmall),
        const Spacer(),
        if (plan.venue != null)
          TextButton.icon(
            onPressed: busy ? null : () => onVenue(null),
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Adil noktaya dön'),
          ),
      ]),
      const SizedBox(height: 8),
      _venueList(context),
    ]);
  }

  Widget _venueList(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = venues;
    if (venuesError != null) {
      return Row(children: [
        Expanded(child: Text(venuesError!, style: TextStyle(color: scheme.onSurfaceVariant))),
        TextButton(onPressed: onRetryVenues, child: const Text('Tekrar dene')),
      ]);
    }
    if (v == null) return const LinearProgressIndicator();
    if (v.isEmpty) {
      return Text('Bu noktanın yakınında kayıtlı kafe, restoran veya park yok.',
          style: TextStyle(color: scheme.onSurfaceVariant));
    }
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: v.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final venue = v[i];
          final selected = plan.venue?.point == venue.point;
          return SizedBox(
            width: 150,
            child: Card(
              margin: EdgeInsets.zero,
              color: selected ? scheme.secondaryContainer : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: selected ? scheme.secondary : scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: busy || selected ? null : () => onVenue(venue),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(venue.kind.icon, color: scheme.secondary),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(venue.name,
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text('${venue.kind.label} · ${formatDistance(venue.meters)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.leg, required this.share, required this.leaveAt});
  final Participant person;
  final Leg leg;
  final double share;
  final DateTime leaveAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: person.color, child: Icon(person.mode.icon, size: 18, color: Colors.white)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(person.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(formatDuration(leg.seconds), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share.clamp(0.04, 1),
                minHeight: 6,
                color: person.color,
                backgroundColor: scheme.surface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text('${person.mode.label} · ${formatDistance(leg.meters)}',
                    style: text.bodySmall?.copyWith(color: scheme.onPrimaryContainer.withValues(alpha: 0.75))),
              ),
              Text('Çıkış ${formatClock(leaveAt)}',
                  style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: scheme.onPrimaryContainer)),
            ]),
          ]),
        ),
      ]),
    );
  }
}
