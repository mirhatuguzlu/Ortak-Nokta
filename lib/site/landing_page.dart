import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _ink = Color(0xFF0B1F1A);
const _muted = Color(0xFF51625D);
const _brand = Color(0xFF0E7C66);
const _brandDark = Color(0xFF075446);
const _mint = Color(0xFFE7F4EF);
const _maxWidth = 1120.0;

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _how = GlobalKey(), _features = GlobalKey(), _faq = GlobalKey(), _download = GlobalKey();

  void _goTo(GlobalKey k) => Scrollable.ensureVisible(k.currentContext!,
      duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: Colors.white.withValues(alpha: 0.96),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 1,
          toolbarHeight: 68,
          titleSpacing: 0,
          title: _Width(
            child: Row(children: [
              const _Logo(),
              const Spacer(),
              if (wide) ...[
                _NavLink('Nasıl çalışır', () => _goTo(_how)),
                _NavLink('Özellikler', () => _goTo(_features)),
                _NavLink('SSS', () => _goTo(_faq)),
                const SizedBox(width: 12),
              ],
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _brand),
                onPressed: () => _goTo(_download),
                child: const Text('Uygulamayı indir'),
              ),
            ]),
          ),
        ),
        SliverList.list(children: [
          _Hero(onDownload: () => _goTo(_download), onHow: () => _goTo(_how)),
          const _Compare(),
          _Steps(key: _how),
          _Features(key: _features),
          const _InviteBand(),
          const _Privacy(),
          _Faq(key: _faq),
          _Download(key: _download),
          const _Footer(),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------- yapı taşları

/// İçeriği ortalar ve en fazla [_maxWidth] genişliğe sınırlar; telefonda 16 px kenar boşluğu.
class _Width extends StatelessWidget {
  const _Width({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth + 48),
        child: Padding(padding: EdgeInsets.symmetric(horizontal: pad), child: child),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.color, this.eyebrow, this.title, this.subtitle});
  final Widget child;
  final Color? color;
  final String? eyebrow, title, subtitle;

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 600;
    return ColoredBox(
      color: color ?? Colors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: phone ? 56 : 96),
        child: _Width(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (eyebrow != null)
              Text(eyebrow!.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _brand, fontWeight: FontWeight.w800, letterSpacing: 1.6, fontSize: 13)),
            if (title != null) ...[
              const SizedBox(height: 12),
              Text(title!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _ink, fontSize: phone ? 28 : 40, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.5)),
            ],
            if (subtitle != null) ...[
              const SizedBox(height: 16),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Text(subtitle!,
                      textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 18, height: 1.6)),
                ),
              ),
            ],
            if (title != null) SizedBox(height: phone ? 32 : 56),
            child,
          ]),
        ),
      ),
    );
  }
}

/// Genişliğe göre 1, 2 veya 3 sütunlu ızgara (eşit yükseklik gerekmez).
class _Grid extends StatelessWidget {
  const _Grid({required this.children, this.columns = 3});
  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final n = c.maxWidth < 600 ? 1 : (c.maxWidth < 900 ? math.min(2, columns) : columns);
        const gap = 20.0;
        final w = (c.maxWidth - gap * (n - 1)) / n;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final child in children) SizedBox(width: w, child: child),
        ]);
      });
}

class _Logo extends StatelessWidget {
  const _Logo({this.light = false});
  final bool light;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_brand, _brandDark]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.join_inner, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text('Ortak Nokta',
            style: TextStyle(
                color: light ? Colors.white : _ink, fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.3)),
      ]);
}

class _NavLink extends StatelessWidget {
  const _NavLink(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: _ink),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}

// ---------------------------------------------------------------- bölümler

class _Hero extends StatelessWidget {
  const _Hero({required this.onDownload, required this.onHow});
  final VoidCallback onDownload, onHow;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 900, phone = w < 600;
    final copy = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(999)),
          child: const Text('Ücretsiz · Üyelik yok · Reklam yok',
              style: TextStyle(color: _brandDark, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        const SizedBox(height: 20),
        Text(
          'Ortada değil,\nadil buluşun.',
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: TextStyle(
              color: _ink, fontSize: phone ? 42 : 64, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -1.5),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Haritadaki orta nokta, biri yürüyüp biri araba kullanırken hiç adil değildir. '
            'Ortak Nokta herkesin gerçek yol süresini hesaplar ve kimsenin fazladan yol yapmadığı yeri bulur.',
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 19, height: 1.6),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: _brand, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20)),
              onPressed: onDownload,
              icon: const Icon(Icons.download),
              label: const Text('Uygulamayı indir', style: TextStyle(fontSize: 16)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: _ink, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20)),
              onPressed: onHow,
              child: const Text('Nasıl çalışır?', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ],
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, _mint],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: phone ? 40 : 72, bottom: phone ? 56 : 96),
        child: _Width(
          child: wide
              ? Row(children: [Expanded(child: copy), const SizedBox(width: 48), const _Phone()])
              : Column(children: [copy, const SizedBox(height: 48), const _Phone()]),
        ),
      ),
    );
  }
}

/// Uygulamanın stilize edilmiş bir ekranı (gerçek ekran görüntüsü yerine çizim).
class _Phone extends StatelessWidget {
  const _Phone();

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width < 400 ? 0.82 : 1.0;
    return SizedBox(
      width: 300 * scale,
      height: 610 * scale,
      child: FittedBox(
        child: Container(
          width: 300,
          height: 610,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(46),
            boxShadow: const [BoxShadow(color: Color(0x33075446), blurRadius: 60, offset: Offset(0, 30))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: Stack(children: [
              const Positioned.fill(child: CustomPaint(painter: _MapPainter())),
              const Positioned(left: 70, top: 128, child: _TimeChip('Ayşe · 24 dk', Colors.indigo)),
              const Positioned(left: 150, top: 250, child: _TimeChip('Can · 25 dk', Colors.deepOrange)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16)],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('BULUŞMA · 19:15',
                        style: TextStyle(color: _brand, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    const Text('Kahve Durağı, Moda',
                        style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    const _MiniRow('Ayşe', Icons.directions_walk, Colors.indigo, '24 dk', 'çıkış 18:51', 0.96),
                    const _MiniRow('Can', Icons.directions_car, Colors.deepOrange, '25 dk', 'çıkış 18:50', 1),
                    const SizedBox(height: 10),
                    Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(12)),
                      child: const Text('Gruba gönder',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
      );
}

class _MiniRow extends StatelessWidget {
  const _MiniRow(this.name, this.icon, this.color, this.time, this.leave, this.share);
  final String name, time, leave;
  final IconData icon;
  final Color color;
  final double share;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          CircleAvatar(radius: 12, backgroundColor: color, child: Icon(icon, size: 14, color: Colors.white)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(name, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 12)),
                const Spacer(),
                Text(leave, style: const TextStyle(color: _muted, fontSize: 10)),
                const SizedBox(width: 6),
                Text(time, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 12)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                    value: share, minHeight: 4, color: color, backgroundColor: const Color(0xFFE6EFEC)),
              ),
            ]),
          ),
        ]),
      );
}

/// Sokaklar, nehir, park ve iki rota: uygulamanın haritasının sade bir çizimi.
class _MapPainter extends CustomPainter {
  const _MapPainter();

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFF2EFE9));
    final park = Paint()..color = const Color(0xFFCDE8C8);
    canvas.drawRRect(RRect.fromLTRBR(180, 40, 270, 120, const Radius.circular(18)), park);
    canvas.drawRRect(RRect.fromLTRBR(20, 300, 110, 360, const Radius.circular(18)), park);
    final water = Paint()
      ..color = const Color(0xFFAAD3DF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 34;
    canvas.drawPath(
        Path()
          ..moveTo(-20, 210)
          ..cubicTo(80, 170, 160, 260, 320, 200),
        water);
    final road = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      road.strokeWidth = i.isEven ? 9 : 5;
      canvas.drawLine(Offset(-10, 30.0 + i * 62), Offset(s.width + 10, 10.0 + i * 70), road);
      canvas.drawLine(Offset(20.0 + i * 50, -10), Offset(40.0 + i * 46, s.height + 10), road);
    }
    void route(List<Offset> pts, Color c) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..strokeJoin = StrokeJoin.round);
      canvas.drawPath(
          path,
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeJoin = StrokeJoin.round);
      canvas.drawCircle(pts.first, 13, Paint()..color = Colors.white);
      canvas.drawCircle(pts.first, 10, Paint()..color = c);
    }

    const pin = Offset(150, 200);
    route(const [Offset(40, 80), Offset(70, 110), Offset(115, 140), Offset(130, 175), pin], Colors.indigo);
    route(const [Offset(250, 400), Offset(230, 330), Offset(200, 290), Offset(170, 240), pin], Colors.deepOrange);
    // Buluşma noktası iğnesi
    canvas.drawCircle(pin.translate(0, -16), 15, Paint()..color = _brand);
    canvas.drawPath(
        Path()
          ..moveTo(pin.dx - 10, pin.dy - 8)
          ..lineTo(pin.dx, pin.dy + 4)
          ..lineTo(pin.dx + 10, pin.dy - 8)
          ..close(),
        Paint()..color = _brand);
    canvas.drawCircle(pin.translate(0, -16), 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Compare extends StatelessWidget {
  const _Compare();

  @override
  Widget build(BuildContext context) => const _Section(
        eyebrow: 'Sorun',
        title: 'Haritanın ortası neden yanıltır?',
        subtitle: 'Kuş uçumu orta nokta mesafeyi böler, zamanı değil. '
            'Trafik, köprüler, deniz ve yürüme hızı hesaba girince biri hep fazla yol yapar. Örnek bir buluşma:',
        child: _Grid(columns: 2, children: [
          _CompareCard(
            good: false,
            title: 'Haritanın ortası',
            rows: [('Ayşe · yürüyerek', 41, 41), ('Can · araçla', 9, 41)],
            note: 'Fark 32 dk: Ayşe yürürken Can çoktan oturmuş.',
          ),
          _CompareCard(
            good: true,
            title: 'Ortak Nokta',
            rows: [('Ayşe · yürüyerek', 24, 25), ('Can · araçla', 25, 25)],
            note: 'Fark 1 dk: ikiniz de aynı anda kapıdasınız.',
          ),
        ]),
      );
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.good, required this.title, required this.rows, required this.note});
  final bool good;
  final String title, note;

  /// (etiket, dakika, karşılaştırma için en büyük dakika)
  final List<(String, int, int)> rows;

  @override
  Widget build(BuildContext context) {
    final accent = good ? _brand : const Color(0xFFC2410C);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: good ? _mint : const Color(0xFFFFF4ED),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(good ? Icons.check_circle : Icons.cancel, color: accent),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 24),
        for (final (label, min, of) in rows) ...[
          Row(children: [
            Expanded(child: Text(label, style: const TextStyle(color: _ink, fontWeight: FontWeight.w600))),
            Text('$min dk', style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 18)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: min / 45,
              minHeight: 10,
              color: accent.withValues(alpha: min == of ? 1 : 0.55),
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
        ],
        Text(note, style: const TextStyle(color: _muted, fontSize: 15)),
      ]),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({super.key});

  @override
  Widget build(BuildContext context) => const _Section(
        color: Color(0xFFF7FAF9),
        eyebrow: 'Nasıl çalışır',
        title: 'Üç adımda adil buluşma',
        child: _Grid(children: [
          _Step(1, Icons.person_pin_circle_outlined, 'Kim nereden geliyor?',
              'Herkesin başlangıç noktasını ve aracını seç. Ya da linki gruba at, herkes kendini eklesin.'),
          _Step(2, Icons.route_outlined, 'Gerçek yol süresi',
              'Ortak Nokta onlarca aday noktaya herkesin yol süresini hesaplar: yürüyüş, araç ve trafik tahmini.'),
          _Step(3, Icons.celebration_outlined, 'Buluşun',
              'En adil nokta, çevresindeki kafeler ve herkesin kaçta çıkması gerektiği tek ekranda.'),
        ]),
      );
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.icon, this.title, this.body);
  final int n;
  final IconData icon;
  final String title, body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE3EBE8)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _brand,
              child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const Spacer(),
            Icon(icon, color: _brand, size: 32),
          ]),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: _muted, fontSize: 16, height: 1.55)),
        ]),
      );
}

class _Features extends StatelessWidget {
  const _Features({super.key});

  @override
  Widget build(BuildContext context) => const _Section(
        eyebrow: 'Özellikler',
        title: 'Buluşmayı baştan sona adil planlar',
        subtitle: 'Ortak Nokta yalnızca bir orta nokta bulmaz; kimin kaçta çıkacağını ve nerede oturacağınızı da söyler.',
        child: _Grid(children: [
          _Feature(Icons.balance, 'Süreye göre adalet',
              'Mesafeyi değil yolda geçen zamanı eşitler. Herkes kendi aracıyla: yürüyüş ya da araç.'),
          _Feature(Icons.schedule, 'Kim kaçta çıksın?',
              'Herkesin aynı anda varması için kişiye özel çıkış saati. Kimse kapıda beklemez.'),
          _Feature(Icons.local_cafe_outlined, 'Yakında ne var?',
              'Adil noktanın çevresindeki kafe, restoran ve parklar. Birine dokun, süreler o mekana göre yenilensin.'),
          _Feature(Icons.autorenew, 'Dönüşümlü adalet',
              'Geçen sefer hep aynı kişi mi uzağa gitti? Adalet defteri bunu hatırlar, sıradaki nokta onun lehine kayar.'),
          _Feature(Icons.tune, 'Adaleti sen seç',
              'En adil, en hızlı ya da eşit süre: grubunuz için "adil" ne demekse.'),
          _Feature(Icons.ios_share, 'Tek dokunuşla paylaş',
              'Buluşma yeri, süreler ve çıkış saatleri tek bir görselde. WhatsApp grubuna ya da hikâyeye gönder.'),
        ]),
      );
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.body);
  final IconData icon;
  final String title, body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: _brand, size: 26),
          ),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: _muted, fontSize: 16, height: 1.55)),
        ]),
      );
}

class _InviteBand extends StatelessWidget {
  const _InviteBand();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('DAVET LİNKİ',
          style: TextStyle(color: Color(0xFF9FE3CF), fontWeight: FontWeight.w800, letterSpacing: 1.6, fontSize: 13)),
      const SizedBox(height: 12),
      const Text('Arkadaşının uygulamayı indirmesi gerekmez',
          style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, height: 1.2)),
      const SizedBox(height: 16),
      const Text(
        'Linki gruba at. Herkes tarayıcıdan adını, nereden geleceğini ve aracını ekler; '
        'sen katılanları canlı görürsün ve tek dokunuşla ortak noktayı bulursun.',
        style: TextStyle(color: Color(0xFFD5EDE6), fontSize: 18, height: 1.6),
      ),
      const SizedBox(height: 20),
      for (final t in ['Üyelik yok', 'En fazla 5 kişi', 'Konumlar 24 saatte silinir'])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            const Icon(Icons.check, color: Color(0xFF9FE3CF), size: 20),
            const SizedBox(width: 8),
            Text(t, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ]),
        ),
    ]);
    final card = Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ayşe seni bir buluşmaya davet etti',
            style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        for (final (icon, label) in [(Icons.person_outline, 'Adın'), (Icons.place_outlined, 'Nereden geleceksin?')]) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD8E2DE)), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(icon, color: _muted),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(color: _muted)),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(14)),
          child: const Text('Gruba katıl', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
    return ColoredBox(
      color: _brandDark,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 88),
        child: _Width(
          child: wide
              ? Row(children: [Expanded(child: copy), const SizedBox(width: 64), card])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  copy,
                  const SizedBox(height: 40),
                  Center(child: card),
                ]),
        ),
      ),
    );
  }
}

class _Privacy extends StatelessWidget {
  const _Privacy();

  @override
  Widget build(BuildContext context) => const _Section(
        eyebrow: 'Gizlilik',
        title: 'Konumun sana ait',
        child: _Grid(children: [
          _Feature(Icons.no_accounts_outlined, 'Hesap yok',
              'E-posta, telefon numarası ya da şifre istemiyoruz. Aç ve kullan.'),
          _Feature(Icons.location_off_outlined, 'Konum saklanmaz',
              'Konumlar yalnızca rota hesabı için kullanılır. Davet grupları 24 saat sonra silinir.'),
          _Feature(Icons.phone_android, 'Defter cihazında',
              'Kaydettiğin buluşmalar yalnızca telefonunda durur; istediğin an silersin.'),
        ]),
      );
}

class _Faq extends StatelessWidget {
  const _Faq({super.key});

  static const _items = [
    ('Ücretli mi?', 'Hayır. Ortak Nokta ücretsiz ve reklamsız.'),
    (
      'Trafiği hesaba katıyor mu?',
      'Araç süreleri günün saatine göre tahmini trafikle artırılır (iş çıkışı saatlerinde daha fazla). '
          'Canlı trafik verisi kullanmıyoruz; bu yüzden süreler bir tahmindir.'
    ),
    (
      'Toplu taşıma var mı?',
      'Şu an yürüyüş ve araç destekleniyor. Otobüs ve taksi seçenekleri üzerinde çalışıyoruz.'
    ),
    ('Kaç kişiyle kullanabilirim?', 'Bir buluşmada en fazla 5 kişi.'),
    (
      'Hangi harita verisini kullanıyorsunuz?',
      'Açık kaynak OpenStreetMap verisi, OSRM rota motoru ve Overpass mekan verisi. '
          'Haritada bir hata görürsen OpenStreetMap üzerinden düzeltebilirsin.'
    ),
  ];

  @override
  Widget build(BuildContext context) => _Section(
        color: const Color(0xFFF7FAF9),
        eyebrow: 'SSS',
        title: 'Sık sorulan sorular',
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(children: [
              for (final (q, a) in _items)
                Card(
                  elevation: 0,
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE3EBE8))),
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    expandedAlignment: Alignment.centerLeft,
                    title: Text(q, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 17)),
                    children: [Text(a, style: const TextStyle(color: _muted, fontSize: 16, height: 1.6))],
                  ),
                ),
            ]),
          ),
        ),
      );
}

class _Download extends StatelessWidget {
  const _Download({super.key});

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: phone ? 56 : 96),
      child: _Width(
        child: Container(
          padding: EdgeInsets.all(phone ? 28 : 56),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_brand, _brandDark]),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(children: [
            Text('Bir sonraki buluşma adil olsun',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: phone ? 28 : 40, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text('Ortak Nokta çok yakında Google Play ve App Store\'da.',
                textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFD5EDE6), fontSize: 18)),
            const SizedBox(height: 28),
            const Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
              _StoreBadge(Icons.shop, 'Google Play'),
              _StoreBadge(Icons.apple, 'App Store'),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Mağaza linkleri hazır olunca `onTap` ile gerçek adrese bağlanacak; şimdilik "Yakında".
class _StoreBadge extends StatelessWidget {
  const _StoreBadge(this.icon, this.store);
  final IconData icon;
  final String store;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Yakında', style: TextStyle(color: Colors.white70, fontSize: 11)),
            Text(store, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
          ]),
        ]),
      );
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: _ink,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: _Width(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 16,
              children: [
                const _Logo(light: true),
                Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                    onPressed: () => Navigator.pushNamed(context, '/gizlilik'),
                    child: const Text('Gizlilik'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                    onPressed: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
                    child: const Text('Harita verisi © OpenStreetMap katkıcıları'),
                  ),
                  Text('© ${DateTime.now().year} Ortak Nokta', style: const TextStyle(color: Colors.white54)),
                ]),
              ],
            ),
          ),
        ),
      );
}
