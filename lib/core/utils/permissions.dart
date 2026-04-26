enum Permission {
  viewAnalytics,
  manageUsers,
  manageCommunities,
  managePages,
  manageCategories,
  manageComplaints,
  managePlugins,
  manageSettings,
  manageSubscriptions,
}

const _adminPermissions = [
  Permission.viewAnalytics,
  Permission.manageUsers,
  Permission.manageCommunities,
  Permission.managePages,
  Permission.manageCategories,
  Permission.manageComplaints,
];

const _superAdminPermissions = [
  ..._adminPermissions,
  Permission.managePlugins,
  Permission.manageSettings,
  Permission.manageSubscriptions,
];

List<Permission> permissionsForRole(String? role) {
  if (role == 'super_admin') return _superAdminPermissions;
  if (role == 'admin') return _adminPermissions;
  return [];
}

bool roleHasPermission(String? role, Permission perm) {
  return permissionsForRole(role).contains(perm);
}
