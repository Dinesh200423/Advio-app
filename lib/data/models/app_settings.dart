class AppSettings {
  const AppSettings({
    this.name = 'Dinesh',
    this.email = 'advio.md@gmail.com',
    this.phone = '+91 89391 27720',
    this.headline = 'Founder, ADVIO',
    this.businessName = 'ADVIO',
    this.businessAddress = 'Chennai, India',
    this.taxId = '',
    this.website = 'dinesh200423.github.io/advio-site',
    this.currency = 'INR',
    this.defaultTaxPercent = 18,
    this.pushNotifications = true,
    this.emailDigest = true,
    this.followUpReminders = true,
    this.invoiceAlerts = true,
    this.taskDeadlines = true,
    this.textScale = 1.0,
  });

  final String name;
  final String email;
  final String phone;
  final String headline;
  final String businessName;
  final String businessAddress;
  final String taxId;
  final String website;
  final String currency;
  final double defaultTaxPercent;
  final bool pushNotifications;
  final bool emailDigest;
  final bool followUpReminders;
  final bool invoiceAlerts;
  final bool taskDeadlines;
  final double textScale;

  String get firstName => name.trim().split(' ').first;

  AppSettings copyWith({
    String? name,
    String? email,
    String? phone,
    String? headline,
    String? businessName,
    String? businessAddress,
    String? taxId,
    String? website,
    String? currency,
    double? defaultTaxPercent,
    bool? pushNotifications,
    bool? emailDigest,
    bool? followUpReminders,
    bool? invoiceAlerts,
    bool? taskDeadlines,
    double? textScale,
  }) =>
      AppSettings(
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        headline: headline ?? this.headline,
        businessName: businessName ?? this.businessName,
        businessAddress: businessAddress ?? this.businessAddress,
        taxId: taxId ?? this.taxId,
        website: website ?? this.website,
        currency: currency ?? this.currency,
        defaultTaxPercent: defaultTaxPercent ?? this.defaultTaxPercent,
        pushNotifications: pushNotifications ?? this.pushNotifications,
        emailDigest: emailDigest ?? this.emailDigest,
        followUpReminders: followUpReminders ?? this.followUpReminders,
        invoiceAlerts: invoiceAlerts ?? this.invoiceAlerts,
        taskDeadlines: taskDeadlines ?? this.taskDeadlines,
        textScale: textScale ?? this.textScale,
      );
}
