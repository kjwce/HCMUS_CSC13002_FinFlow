import '../../finance/models/quick_add_draft_model.dart';

class BankNotificationConfiguration {
  const BankNotificationConfiguration({
    required this.enabled,
    required this.packages,
    required this.packagesConfigured,
  });

  factory BankNotificationConfiguration.fromMap(Map<dynamic, dynamic>? map) {
    final rawPackages = map?['packages'];
    return BankNotificationConfiguration(
      enabled: map?['enabled'] == true,
      packages: rawPackages is List
          ? rawPackages.map((value) => value.toString()).toSet()
          : <String>{},
      packagesConfigured: map?['packagesConfigured'] == true,
    );
  }

  final bool enabled;
  final Set<String> packages;
  final bool packagesConfigured;
}

class BankNotificationEnvelope {
  const BankNotificationEnvelope({
    required this.id,
    required this.packageName,
    required this.title,
    required this.text,
    required this.postedAt,
  });

  factory BankNotificationEnvelope.fromMap(Map<dynamic, dynamic> map) {
    return BankNotificationEnvelope(
      id: map['id']?.toString() ?? '',
      packageName: map['packageName']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      postedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['postedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  final String id;
  final String packageName;
  final String title;
  final String text;
  final DateTime postedAt;

  bool get isValid =>
      id.isNotEmpty &&
      packageName.isNotEmpty &&
      (title.isNotEmpty || text.isNotEmpty);
}

class BankNotificationParseResult {
  const BankNotificationParseResult.ignored()
    : isTransaction = false,
      draft = null;

  const BankNotificationParseResult.transaction(this.draft)
    : isTransaction = true;

  final bool isTransaction;
  final QuickAddDraft? draft;
}

class BankNotificationProvider {
  const BankNotificationProvider({
    required this.name,
    required this.packageName,
  });

  final String name;
  final String packageName;

  static const supported = [
    BankNotificationProvider(name: 'Vietcombank', packageName: 'com.VCB'),
    BankNotificationProvider(name: 'MB Bank', packageName: 'com.mbmobile'),
    BankNotificationProvider(
      name: 'Techcombank',
      packageName: 'vn.com.techcombank.bb.app',
    ),
    BankNotificationProvider(name: 'BIDV', packageName: 'com.vnpay.bidv'),
    BankNotificationProvider(
      name: 'VietinBank iPay',
      packageName: 'com.vietinbank.ipay',
    ),
    BankNotificationProvider(
      name: 'Agribank Plus',
      packageName: 'com.vnpay.Agribank3g',
    ),
    BankNotificationProvider(name: 'ACB ONE', packageName: 'mobile.acb.com.vn'),
    BankNotificationProvider(
      name: 'VPBank NEO',
      packageName: 'com.vpbank.vpbankonline',
    ),
    BankNotificationProvider(
      name: 'TPBank Mobile',
      packageName: 'com.tpb.mb.gprsandroid',
    ),
    BankNotificationProvider(
      name: 'MoMo',
      packageName: 'com.mservice.momotransfer',
    ),
    BankNotificationProvider(
      name: 'ZaloPay',
      packageName: 'vn.com.vng.zalopay',
    ),
    BankNotificationProvider(
      name: 'Viettel Money',
      packageName: 'com.bplus.vtpay',
    ),
    BankNotificationProvider(
      name: 'SACOMBANK PAY',
      packageName: 'com.sacombank.ewallet',
    ),
    BankNotificationProvider(
      name: 'SACOMBANK mBanking',
      packageName: 'src.com.sacombank',
    ),
  ];
}
