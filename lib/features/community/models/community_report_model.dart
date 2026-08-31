enum CommunityReportTarget { post, comment }

enum CommunityReportReason {
  spamOrMisleading('spam_misleading'),
  scamOrFraud('scam_fraud'),
  harassmentOrHate('harassment_hate'),
  unsafeOrIllegal('unsafe_illegal'),
  privacyViolation('privacy_violation'),
  other('other');

  const CommunityReportReason(this.code);

  final String code;
}

enum CommunityReportSubmitResult { submitted, alreadyReported }
