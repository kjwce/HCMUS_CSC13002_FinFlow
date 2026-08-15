// Script tải logo ngân hàng & ví điện tử Việt Nam về assets/logos/
// Chạy bằng lệnh: dart run download_logos.dart
// Đặt file này ở thư mục gốc của Flutter project (cùng cấp pubspec.yaml)

import 'dart:io';

// ignore_for_file: avoid_print

const _banks = {
  // Ngân hàng thương mại
  'vietcombank': 'vietcombank.com.vn',
  'vietinbank': 'vietinbank.vn',
  'bidv': 'bidv.com.vn',
  'agribank': 'agribank.com.vn',
  'techcombank': 'techcombank.com.vn',
  'mbbank': 'mbbank.com.vn',
  'vpbank': 'vpbank.com.vn',
  'acb': 'acb.com.vn',
  'sacombank': 'sacombank.com',
  'tpbank': 'tpbank.vn',
  'hdbank': 'hdbank.com.vn',
  'shb': 'shb.com.vn',
  'ocb': 'ocb.com.vn',
  'seabank': 'seabank.com.vn',
  'vib': 'vib.com.vn',
  'lpbank': 'lpbank.com.vn',
  'namabank': 'namabank.com.vn',
  'eximbank': 'eximbank.com.vn',
  // Ngân hàng số
  'timo': 'timo.vn',
  'cake': 'cake.vn',
  'ubank': 'ubank.vn',
  'tnex': 'tnex.com.vn',
  'yolo': 'yolo.com.vn',
  'bvbank': 'bvbank.com.vn',
};

const _ewallets = {
  'momo': 'momo.vn',
  'zalopay': 'zalopay.vn',
  'vnpay': 'vnpay.vn',
  'shopeepay': 'airpay.com.vn',
  'viettelmoney': 'viettelmoney.vn',
  'grabpay': 'grab.com',
  'onepay': 'onepay.vn',
  'paypal': 'paypal.com',
  'applepay': 'apple.com',
  'cash': 'cash', // placeholder, sẽ skip
  'other': 'other', // placeholder, sẽ skip
};

/// Dùng Google Favicon API (sz=256 cho chất lượng tốt, không giới hạn request)
/// Hoặc đổi sang Clearbit nếu muốn logo đẹp hơn:
/// https://logo.clearbit.com/$domain (giới hạn 200 req/tháng free)
String _logoUrl(String domain) =>
    'https://www.google.com/s2/favicons?domain=$domain&sz=256';

// Đổi thành true nếu muốn dùng Clearbit thay Google Favicon
const _useClearbit = false;
String _clearbitUrl(String domain) => 'https://logo.clearbit.com/$domain';

Future<void> main() async {
  final projectRoot = Directory.current.path;
  print('📁 Project root: $projectRoot');

  final banksDir = Directory('$projectRoot/assets/logos/banks');
  final ewalletsDir = Directory('$projectRoot/assets/logos/ewallets');

  final client = HttpClient();
  int success = 0;
  int failed = 0;

  // --- Tải logo ngân hàng ---
  print('🏦 Đang tải logo ngân hàng...');
  for (final entry in _banks.entries) {
    final slug = entry.key;
    final domain = entry.value;
    final savePath = '${banksDir.path}/$slug.png';

    final ok = await _downloadLogo(client, domain, savePath);
    if (ok) {
      print('  ✅ $slug');
      success++;
    } else {
      print('  ❌ $slug ($domain) — tải thất bại');
      failed++;
    }
    // Delay nhỏ tránh bị rate limit
    await Future.delayed(const Duration(milliseconds: 200));
  }

  // --- Tải logo ví điện tử ---
  print('\n💳 Đang tải logo ví điện tử...');
  for (final entry in _ewallets.entries) {
    final slug = entry.key;
    final domain = entry.value;

    // Skip placeholder (cash, other — dùng icon app thay vì logo)
    if (domain == 'cash' || domain == 'other') {
      print('  ⏭️  $slug — dùng icon built-in, bỏ qua');
      continue;
    }

    final savePath = '${ewalletsDir.path}/$slug.png';
    final ok = await _downloadLogo(client, domain, savePath);
    if (ok) {
      print('  ✅ $slug');
      success++;
    } else {
      print('  ❌ $slug ($domain) — tải thất bại');
      failed++;
    }
    await Future.delayed(const Duration(milliseconds: 200));
  }

  client.close();

  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('✅ Thành công: $success');
  print('❌ Thất bại:   $failed');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  if (failed > 0) {
    print(
      '⚠️  Một số logo tải thất bại — tải thủ công và đặt vào đúng thư mục với đúng tên file (slug.png).',
    );
  }
}

Future<bool> _downloadLogo(
  HttpClient client,
  String domain,
  String savePath,
) async {
  try {
    final url = _useClearbit ? _clearbitUrl(domain) : _logoUrl(domain);
    final uri = Uri.parse(url);

    final request = await client.getUrl(uri);
    final response = await request.close();

    if (response.statusCode != 200) return false;

    final file = File(savePath);
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }

    // Kiểm tra file có nội dung hợp lệ không (tối thiểu 100 bytes)
    if (bytes.length < 100) return false;

    await file.writeAsBytes(bytes);
    return true;
  } catch (e) {
    return false;
  }
}
