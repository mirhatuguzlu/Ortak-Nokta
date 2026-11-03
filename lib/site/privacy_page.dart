import 'package:flutter/material.dart';

/// Mağaza başvurularında da istenen gizlilik metni.
/// shortcut: hukuki inceleme yapılmadı; yayından önce KVKK açısından bir avukata okut.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  static const _sections = [
    (
      'Hangi verileri işliyoruz?',
      'Buluşma noktasını hesaplamak için girdiğin başlangıç konumları, ulaşım aracı ve kişi adları. '
          'Hesap açılmaz; e-posta, telefon numarası veya reklam kimliği toplanmaz.'
    ),
    (
      'Veriler nereye gönderiliyor?',
      'Konumlar yalnızca rota ve süre hesabı için OpenStreetMap tabanlı servislere gönderilir: '
          'OSRM (FOSSGIS e.V., Almanya), Nominatim ve Overpass API. Bu servisler isteği yanıtlamak için '
          'işler; Ortak Nokta bu verileri kendi sunucusunda saklamaz.'
    ),
    (
      'Davet linkleri',
      'Davet linki kullandığında gruptaki kişilerin adı, aracı ve başlangıç konumu, grubu kuran kişinin '
          'ortak noktayı hesaplayabilmesi için sunucumuzda tutulur. Bu bilgilere yalnızca linke sahip '
          'olanlar erişebilir ve grup 24 saat sonra otomatik olarak silinir.'
    ),
    (
      'Cihazında kalanlar',
      'Kaydettiğin buluşmalar ("Adalet defteri") ve tercihlerin yalnızca telefonunda tutulur. '
          'Uygulama içinden istediğin an silebilirsin.'
    ),
    (
      'Konum izni',
      '"Konumum" düğmesine bastığında bir kez konum alınır. Uygulama arka planda konum izlemez.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Text('Gizlilik politikası', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Kısaca: hesap yok, reklam yok, konumların satılmaz ve saklanmaz.'),
            for (final (title, body) in _sections) ...[
              const SizedBox(height: 24),
              Text(title, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(body, style: text.bodyLarge?.copyWith(height: 1.6)),
            ],
          ]),
        ),
      ),
    );
  }
}
