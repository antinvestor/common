import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The level at which the user authenticated.
enum LoginLevel { root, organization, branch }

/// The active tenancy context for the current user session.
///
/// Tracks the selected organization and branch within the user's partition.
class TenancyContext extends ChangeNotifier {
  String _partitionId = '';
  String _partitionName = '';
  String _organizationId = '';
  String _organizationName = '';
  String _branchId = '';
  String _branchName = '';
  LoginLevel _loginLevel = LoginLevel.root;

  String get partitionId => _partitionId;
  String get partitionName => _partitionName;
  String get organizationId => _organizationId;
  String get organizationName => _organizationName;
  String get branchId => _branchId;
  String get branchName => _branchName;
  LoginLevel get loginLevel => _loginLevel;

  bool get hasPartition => _partitionId.isNotEmpty;
  bool get hasOrganization => _organizationId.isNotEmpty;
  bool get hasBranch => _branchId.isNotEmpty;

  bool get canSelectOrganization => _loginLevel == LoginLevel.root;
  bool get canSelectBranch => _loginLevel != LoginLevel.branch;

  void initializeFromLogin(
    LoginLevel level, {
    String? partitionId,
    String? partitionName,
    String? orgId,
    String? orgName,
    String? branchId,
    String? branchName,
  }) {
    _loginLevel = level;
    if (partitionId != null) {
      _partitionId = partitionId;
      _partitionName = partitionName ?? '';
    }
    if (orgId != null) {
      _organizationId = orgId;
      _organizationName = orgName ?? '';
    }
    if (branchId != null) {
      _branchId = branchId;
      _branchName = branchName ?? '';
    }
    notifyListeners();
  }

  void selectPartition(String id, String name) {
    if (!canSelectOrganization) return;
    if (_partitionId != id) {
      _partitionId = id;
      _partitionName = name;
      _organizationId = '';
      _organizationName = '';
      _branchId = '';
      _branchName = '';
      notifyListeners();
    }
  }

  void selectOrganization(
    String id,
    String name, {
    String? partitionId,
    String? partitionName,
  }) {
    if (!canSelectOrganization) return;
    if (_organizationId != id) {
      _organizationId = id;
      _organizationName = name;
      if (partitionId != null && partitionId.isNotEmpty) {
        _partitionId = partitionId;
        _partitionName = partitionName ?? '';
      }
      _branchId = '';
      _branchName = '';
      notifyListeners();
    }
  }

  void selectBranch(
    String id,
    String name, {
    String? partitionId,
    String? partitionName,
  }) {
    if (!canSelectBranch) return;
    if (_branchId != id) {
      _branchId = id;
      _branchName = name;
      if (partitionId != null && partitionId.isNotEmpty) {
        _partitionId = partitionId;
        _partitionName = partitionName ?? '';
      }
      notifyListeners();
    }
  }

  void clear() {
    _partitionId = '';
    _partitionName = '';
    _organizationId = '';
    _organizationName = '';
    _branchId = '';
    _branchName = '';
    _loginLevel = LoginLevel.root;
    notifyListeners();
  }

  List<String> get breadcrumbs {
    final trail = <String>[];
    if (_partitionName.isNotEmpty) trail.add(_partitionName);
    if (_organizationName.isNotEmpty) trail.add(_organizationName);
    if (_branchName.isNotEmpty) trail.add(_branchName);
    return trail;
  }
}

final tenancyContextProvider = ChangeNotifierProvider<TenancyContext>((ref) {
  return TenancyContext();
});
