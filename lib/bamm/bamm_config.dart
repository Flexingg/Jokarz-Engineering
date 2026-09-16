/// Connection and screen-context settings for the BAMM (Cogep GuideTi) API.
///
/// Mirrors the values `~/repos/BAMM/app/config.py::Config` and the existing
/// `BammConnectionConfig` (`lib/models/bamm_models.dart`) use today, so pointing
/// this layer at the plant or at the offline mock is a one-value change.
class BammConfig {
  final String origin;
  final String usercode;
  final String password;
  final int companyId;
  final int spwId;

  /// The work-order list screen id, used to build a realistic `Referer` header
  /// on `GetListData` calls (`WORK_ORDER_LIST_PATH`'s screen, not `spwId`).
  final int listScreenId;

  final Duration connectTimeout;
  final Duration loginTimeout;
  final Duration apiTimeout;

  /// How long a token pair is trusted before a fresh login is forced.
  /// The reference client uses 55 minutes for a token BAMM issues for 60.
  final Duration tokenLifetime;

  const BammConfig({
    this.origin = 'http://app02-ao-plt:82',
    this.usercode = '',
    this.password = '',
    this.companyId = 3,
    this.spwId = 700000027,
    this.listScreenId = 700000124,
    this.connectTimeout = const Duration(seconds: 10),
    this.loginTimeout = const Duration(seconds: 60),
    this.apiTimeout = const Duration(seconds: 120),
    this.tokenLifetime = const Duration(minutes: 55),
  });

  /// The origin with trailing slashes stripped, ready to prefix a path.
  String get normalizedOrigin => origin.trim().replaceAll(RegExp(r'/+$'), '');

  BammConfig copyWith({
    String? origin,
    String? usercode,
    String? password,
    int? companyId,
    int? spwId,
    int? listScreenId,
    Duration? connectTimeout,
    Duration? loginTimeout,
    Duration? apiTimeout,
    Duration? tokenLifetime,
  }) {
    return BammConfig(
      origin: origin ?? this.origin,
      usercode: usercode ?? this.usercode,
      password: password ?? this.password,
      companyId: companyId ?? this.companyId,
      spwId: spwId ?? this.spwId,
      listScreenId: listScreenId ?? this.listScreenId,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      loginTimeout: loginTimeout ?? this.loginTimeout,
      apiTimeout: apiTimeout ?? this.apiTimeout,
      tokenLifetime: tokenLifetime ?? this.tokenLifetime,
    );
  }
}
