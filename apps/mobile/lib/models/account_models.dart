// ============================================================================
// ★ MODELOS DE USUÁRIOS E CONTAS (ACCOUNT_MODELS.DART) ★
// Estruturas de dados tipadas para o perfil, organização e sessão:
// 1) UserProfile: Foto, nome, cargo, e-mail e empresa :3
// 2) Organization & Workspace: Dados cadastrais e CNPJ da firma (✿◠‿◠)
// 3) OrgInvite & Member: Convites de acesso e membros da equipe! (｡•̀ᴗ-)✧
// ============================================================================

import '../core/format.dart';

// O perfil completo do usuário que está usando o aplicativo :3
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.surname,
    this.orgId,
    this.orgName,
    this.positionLabel,
    this.company,
    this.sector,
    this.phone,
    this.country,
    this.gender,
    this.dob,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: toInt(json['id']),
        name: toText(json['name']) ?? '',
        surname: toText(json['surname']),
        email: toText(json['email']) ?? '',
        role: toText(json['role']) ?? 'viewer',
        orgId: toText(json['org_id']),
        orgName: toText(json['org_name']),
        positionLabel: toText(json['position_label']),
        company: toText(json['company']),
        sector: toText(json['sector']),
        phone: toText(json['phone']),
        country: toText(json['country']),
        gender: toText(json['gender']),
        dob: toText(json['dob'])?.split('T').first,
        avatarUrl: toText(json['avatar_url']),
      );

  final int id;
  final String name;
  final String? surname;
  final String email;
  final String role;
  final String? orgId;
  final String? orgName;
  final String? positionLabel;
  final String? company;
  final String? sector;
  final String? phone;
  final String? country;
  final String? gender;
  final String? dob;
  final String? avatarUrl;

  String get fullName {
    final parts = [name, surname].where((s) => s != null && s.trim().isNotEmpty).toList();
    return parts.isEmpty ? name : parts.join(' ');
  }

  String get displayName => fullName.isNotEmpty ? fullName : (name.isNotEmpty ? name : email);

  String get initial => displayName.isEmpty ? '?' : displayName[0].toUpperCase();

  bool get canMove => const {'superadmin', 'admin', 'manager', 'operator'}.contains(role);

  bool get isAdmin => role == 'admin' || role == 'superadmin';
}

class Organization {
  const Organization({
    required this.name,
    this.id,
    this.plan,
    this.email,
    this.phone,
    this.city,
    this.state,
    this.address,
    this.cnpj,
    this.legalName,
    this.workspaceType,
    this.logoUrl,
    this.coverImage,
  });

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
        id: toText(json['id']),
        name: toText(json['name']) ?? 'Organização',
        plan: toText(json['plan']) ?? 'Free',
        email: toText(json['email']),
        phone: toText(json['phone']),
        city: toText(json['city']),
        state: toText(json['state']),
        address: toText(json['address']),
        cnpj: toText(json['cnpj']),
        legalName: toText(json['legal_name']),
        workspaceType: toText(json['workspace_type']),
        logoUrl: toText(json['logo_url']),
        coverImage: toText(json['cover_image']),
      );

  final String? id;
  final String name;
  final String? plan;
  final String? email;
  final String? phone;
  final String? city;
  final String? state;
  final String? address;
  final String? cnpj;
  final String? legalName;
  final String? workspaceType;
  final String? logoUrl;
  final String? coverImage;

  String get planLabel => (plan != null && plan!.isNotEmpty) ? plan! : 'Free';

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : 'O';

  String? get location {
    final parts = [city, state].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(' / ');
  }
}

class OrgUnit {
  const OrgUnit({
    required this.id,
    required this.code,
    required this.name,
    required this.unitType,
    required this.status,
    this.city,
    this.state,
    this.address,
  });

  factory OrgUnit.fromJson(Map<String, dynamic> json) => OrgUnit(
        id: toInt(json['id']),
        code: toText(json['code']) ?? '',
        name: toText(json['name']) ?? '',
        unitType: toText(json['unit_type']) ?? 'branch',
        status: toText(json['status']) ?? 'active',
        city: toText(json['city']),
        state: toText(json['state']),
        address: toText(json['address']),
      );

  final int id;
  final String code;
  final String name;
  final String unitType;
  final String status;
  final String? city;
  final String? state;
  final String? address;

  bool get isActive => status == 'active';
}

class OrgInvite {
  const OrgInvite({
    required this.id,
    required this.email,
    required this.role,
    this.code = '',
    this.expiresAt,
    this.createdAt,
    this.status = 'pending',
  });

  factory OrgInvite.fromJson(Map<String, dynamic> json) => OrgInvite(
        id: toInt(json['id']),
        email: toText(json['email']) ?? '',
        role: toText(json['role']) ?? 'viewer',
        code: toText(json['code']) ?? toText(json['invite_code']) ?? '',
        expiresAt: toDate(json['expires_at']),
        createdAt: toDate(json['created_at']),
        status: toText(json['status']) ?? 'pending',
      );

  final int id;
  final String email;
  final String role;
  final String code;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final String status;
}

class OrgMember {
  const OrgMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    this.surname,
    this.positionLabel,
    this.department,
    this.company,
    this.sector,
    this.phone,
    this.avatarUrl,
  });

  factory OrgMember.fromJson(Map<String, dynamic> json) => OrgMember(
        id: toInt(json['id']),
        name: toText(json['name']) ?? '',
        surname: toText(json['surname']),
        email: toText(json['email']) ?? '',
        role: toText(json['role']) ?? 'viewer',
        active: json['is_active'] != 0,
        positionLabel: toText(json['position_label']) ?? toText(json['position_name']),
        department: toText(json['department']),
        company: toText(json['company']),
        sector: toText(json['sector']),
        phone: toText(json['phone']),
        avatarUrl: toText(json['avatar_url']),
      );

  final int id;
  final String name;
  final String? surname;
  final String email;
  final String role;
  final bool active;
  final String? positionLabel;
  final String? department;
  final String? company;
  final String? sector;
  final String? phone;
  final String? avatarUrl;

  String get fullName {
    final parts = [name, surname].where((s) => s != null && s.trim().isNotEmpty).toList();
    return parts.isEmpty ? name : parts.join(' ');
  }

  String get displayName => fullName.isNotEmpty ? fullName : name;

  String get initial => displayName.isEmpty ? '?' : displayName[0].toUpperCase();
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
    required this.setupDone,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: toText(json['token']) ?? '',
        user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
        setupDone: json['setup_done'] == true,
      );

  final String token;
  final UserProfile user;
  final bool setupDone;
}

class OAuthConfig {
  const OAuthConfig({
    this.googleEnabled = false,
    this.googleClientId,
    this.googleNonce,
  });

  factory OAuthConfig.fromJson(Map<String, dynamic> json) {
    final google = json['google'] as Map<String, dynamic>? ?? {};
    return OAuthConfig(
      googleEnabled: google['enabled'] == true,
      googleClientId: toText(google['clientId']),
      googleNonce: toText(google['nonce']),
    );
  }

  final bool googleEnabled;
  final String? googleClientId;
  final String? googleNonce;
}

class WorkspaceContext {
  const WorkspaceContext({
    required this.type,
    this.setupDone = true,
  });

  factory WorkspaceContext.fromJson(Map<String, dynamic> json) => WorkspaceContext(
        type: toText(json['type']) ?? 'corporate',
        setupDone: json['setupDone'] == true,
      );

  final String type;
  final bool setupDone;

  bool get isPersonal => type == 'personal';
  bool get isCorporate => type == 'corporate';
}
