import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/app_logger.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  final BusinessSettings settings;

  const UserManagementScreen({super.key, required this.settings});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<User> _users = [];
  List<AppRole> _roles = [];
  List<BusinessLocation> _locations = [];
  bool _loading = true;
  String _searchQuery = '';
  String _selectedRoleFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final db = await DatabaseService.initialize();
      final list = await db.getUsers();
      final roles = await db.getRoles();
      final locs = await db.getBusinessLocations();
      if (mounted) {
        setState(() {
          _users = list;
          _roles = roles;
          _locations = locs;
          _loading = false;
        });
      }
    } catch (e, st) {
      AppLogger.error('UserManagementScreen', 'Failed to load users', e, st);
      if (mounted) setState(() => _loading = false);
    }
  }

  List<User> get _filteredUsers {
    return _users.where((u) {
      if (_selectedRoleFilter != 'All' &&
          u.role.toLowerCase() != _selectedRoleFilter.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = u.name.toLowerCase().contains(q);
        final matchesUsername = u.username.toLowerCase().contains(q);
        final matchesEmail = u.email.toLowerCase().contains(q);
        final matchesPhone = u.phone.toLowerCase().contains(q);
        final matchesRole = u.role.toLowerCase().contains(q);
        if (!matchesName &&
            !matchesUsername &&
            !matchesEmail &&
            !matchesPhone &&
            !matchesRole) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // =========================================================================
  // 1. ADD NEW USER
  // =========================================================================
  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool mustChangePassword = true;
    String role = 'salesman';
    String branch = widget.settings.branchName.isNotEmpty
        ? widget.settings.branchName
        : 'Main Branch HQ';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: const [
              ContainerIcon(
                  icon: Icons.person_add_alt_1_rounded,
                  color: Color(0xFF4F46E5)),
              SizedBox(width: 10),
              Text('Create New Staff / Salesman',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Full Name * (e.g. Ali Raza)',
                        isDense: true,
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: usernameCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Username (Login ID) *',
                              isDense: true,
                              border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: 'Password *',
                              isDense: true,
                              border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: (_roles.isNotEmpty && _roles.any((r) => r.name == role))
                              ? role
                              : (_roles.isNotEmpty ? _roles.first.name : role),
                          decoration: const InputDecoration(
                              labelText: 'Role / Designation',
                              isDense: true,
                              border: OutlineInputBorder()),
                          items: _roles.isNotEmpty
                              ? _roles
                                  .map((r) => DropdownMenuItem(
                                        value: r.name,
                                        child: Text(r.displayName),
                                      ))
                                  .toList()
                              : const [
                                  DropdownMenuItem(
                                      value: 'salesman',
                                      child: Text('Salesman (Counter / Field)')),
                                  DropdownMenuItem(
                                      value: 'cashier',
                                      child: Text('Cashier (Front Desk)')),
                                  DropdownMenuItem(
                                      value: 'manager',
                                      child: Text('Store Manager / Supervisor')),
                                  DropdownMenuItem(
                                      value: 'admin',
                                      child: Text('Admin (Operations)')),
                                  DropdownMenuItem(
                                      value: 'superadmin',
                                      child: Text('Owner / Super Admin')),
                                ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => role = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _locations.any((l) => l.name == branch)
                              ? branch
                              : (_locations.isNotEmpty
                                  ? _locations.first.name
                                  : branch),
                          decoration: const InputDecoration(
                              labelText: 'Assigned Branch',
                              isDense: true,
                              border: OutlineInputBorder()),
                          items: _locations.isNotEmpty
                              ? _locations
                                  .map((l) => DropdownMenuItem(
                                      value: l.name, child: Text(l.name)))
                                  .toList()
                              : [
                                  DropdownMenuItem(
                                      value: branch, child: Text(branch))
                                ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => branch = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Email Address',
                              isDense: true,
                              border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Mobile Phone',
                              isDense: true,
                              border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: mustChangePassword,
                    onChanged: (v) =>
                        setDlgState(() => mustChangePassword = v ?? true),
                    title: const Text(
                      'Require password change on first login',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline,
                            color: Color(0xFF4F46E5), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Permissions will be auto-configured based on the selected role. You can customize fine-grained authorizations at any time.',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF3730A3),
                                height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final username = usernameCtrl.text.trim();
                final pass = passwordCtrl.text.trim();

                if (name.isEmpty || username.isEmpty || pass.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Please enter name, username, and password!'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }

                final strengthErr = AuthService.validatePasswordStrength(pass);
                if (strengthErr != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(strengthErr),
                        backgroundColor: Colors.red),
                  );
                  return;
                }

                // Check for duplicate username
                if (_users.any((u) =>
                    u.username.toLowerCase() == username.toLowerCase())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'This username is already taken! Choose another.'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }

                final isAdm = role == 'superadmin' || role == 'admin';
                final isMgr = role == 'manager';
                final matchedLoc =
                    _locations.where((l) => l.name == branch).firstOrNull;
                final matchedRole = _roles
                    .where((r) => r.name.toLowerCase() == role.toLowerCase())
                    .firstOrNull;

                final newUser = User(
                  name: name,
                  username: username,
                  password: AuthService.hashPassword(pass),
                  email: emailCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  role: role,
                  roleId: matchedRole?.id,
                  status: 'active',
                  branchId: matchedLoc?.id ?? 1,
                  branchName: branch,
                  canEditPrice: isAdm || isMgr,
                  canGiveDiscount: true,
                  maxDiscountPercent: isAdm ? 100.0 : (isMgr ? 20.0 : 5.0),
                  canViewCostPrice: isAdm || isMgr,
                  canDeleteSale: isAdm || isMgr,
                  canProcessReturn: isAdm || isMgr,
                  canAccessKhata: true,
                  canAccessInventory: isAdm || isMgr,
                  canAccessReports: isAdm || isMgr,
                  canAccessSettings: isAdm,
                  canManageUsers: isAdm,
                  mustChangePassword: mustChangePassword,
                  passwordChangedAt: DateTime.now().toIso8601String(),
                );

                try {
                  final db = await DatabaseService.initialize();
                  await db.addUser(newUser);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadUsers();

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Staff account for "$name" created successfully!'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                } catch (e, st) {
                  AppLogger.error('UserManagement', 'Failed creating user "$username"', e, st);
                  if (mounted) {
                    await AppErrorHandler.showErrorDialog(
                      context,
                      title: 'Create User Failed',
                      message: 'Could not create user "$username".',
                      error: e,
                      stackTrace: st,
                      tag: 'UserManagement',
                    );
                  }
                }
              },
              child: const Text('Save & Create Account',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. EDIT USER DETAILS & RESET PASSWORD
  // =========================================================================
  void _showEditUserDialog(User user) {
    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phone);
    final newPassCtrl = TextEditingController();
    bool requireChangeOnReset = true;
    bool clearLockout = false;
    String role = user.role;
    String status = user.status;
    String branch = user.branchName.isNotEmpty
        ? user.branchName
        : (widget.settings.branchName.isNotEmpty
            ? widget.settings.branchName
            : 'Main Branch HQ');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const ContainerIcon(
                  icon: Icons.edit_note_rounded, color: Color(0xFF0284C7)),
              const SizedBox(width: 10),
              Text('Edit User: ${user.name}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        isDense: true,
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: (_roles.isNotEmpty && _roles.any((r) => r.name == role))
                              ? role
                              : (_roles.isNotEmpty ? _roles.first.name : role),
                          decoration: const InputDecoration(
                              labelText: 'Role',
                              isDense: true,
                              border: OutlineInputBorder()),
                          items: _roles.isNotEmpty
                              ? _roles
                                  .map((r) => DropdownMenuItem(
                                        value: r.name,
                                        child: Text(r.displayName),
                                      ))
                                  .toList()
                              : const [
                                  DropdownMenuItem(
                                      value: 'salesman', child: Text('Salesman')),
                                  DropdownMenuItem(
                                      value: 'cashier', child: Text('Cashier')),
                                  DropdownMenuItem(
                                      value: 'manager', child: Text('Store Manager')),
                                  DropdownMenuItem(
                                      value: 'admin', child: Text('Admin')),
                                  DropdownMenuItem(
                                      value: 'superadmin',
                                      child: Text('Owner / Superadmin')),
                                ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => role = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: status,
                          decoration: const InputDecoration(
                              labelText: 'Account Status',
                              isDense: true,
                              border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(
                                value: 'active',
                                child: Text('Active (Can Login)')),
                            DropdownMenuItem(
                                value: 'inactive',
                                child: Text('Disabled / Suspended')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => status = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _locations.any((l) => l.name == branch)
                        ? branch
                        : (_locations.isNotEmpty
                            ? _locations.first.name
                            : branch),
                    decoration: const InputDecoration(
                        labelText: 'Assigned Branch / Location',
                        isDense: true,
                        border: OutlineInputBorder()),
                    items: _locations.isNotEmpty
                        ? _locations
                            .map((l) => DropdownMenuItem(
                                value: l.name, child: Text(l.name)))
                            .toList()
                        : [
                            DropdownMenuItem(value: branch, child: Text(branch))
                          ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => branch = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Mobile Phone',
                              isDense: true,
                              border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Email Address',
                              isDense: true,
                              border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: true,
                    onChanged: (_) => setDlgState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Reset Password (leave blank to keep current)',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_reset_rounded, size: 20),
                    ),
                  ),
                  if (newPassCtrl.text.trim().isNotEmpty)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: requireChangeOnReset,
                      onChanged: (v) =>
                          setDlgState(() => requireChangeOnReset = v ?? true),
                      title: const Text(
                        'Require password change on next login',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (user.lockedUntil != null && user.lockedUntil!.isNotEmpty)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: clearLockout,
                      onChanged: (v) =>
                          setDlgState(() => clearLockout = v ?? false),
                      title: const Text(
                        'Unlock account (clear brute-force lockout)',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD97706)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final resetPassText = newPassCtrl.text.trim();
                if (resetPassText.isNotEmpty) {
                  final strengthErr =
                      AuthService.validatePasswordStrength(resetPassText);
                  if (strengthErr != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(strengthErr),
                          backgroundColor: Colors.red),
                    );
                    return;
                  }
                }
                final updatedPass = resetPassText.isNotEmpty
                    ? AuthService.hashPassword(resetPassText)
                    : user.password;

                final matchedLoc =
                    _locations.where((l) => l.name == branch).firstOrNull;
                final matchedRole = _roles
                    .where((r) => r.name.toLowerCase() == role.toLowerCase())
                    .firstOrNull;

                final updated = user.copyWith(
                  name: nameCtrl.text.trim(),
                  role: role,
                  roleId: matchedRole?.id ?? user.roleId,
                  status: status,
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  password: updatedPass,
                  branchName: branch,
                  branchId: matchedLoc?.id ?? user.branchId,
                  mustChangePassword: resetPassText.isNotEmpty
                      ? requireChangeOnReset
                      : user.mustChangePassword,
                  failedLoginAttempts:
                      clearLockout ? 0 : user.failedLoginAttempts,
                  clearLockedUntil: clearLockout,
                  passwordChangedAt: resetPassText.isNotEmpty
                      ? DateTime.now().toIso8601String()
                      : user.passwordChangedAt,
                );

                final db = await DatabaseService.initialize();
                await db.updateUser(updated);
                Navigator.pop(ctx);
                _loadUsers();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('User profile updated successfully!'),
                      backgroundColor: Color(0xFF10B981)),
                );
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 3. DELETE USER
  // =========================================================================
  void _confirmDeleteUser(User user) {
    if (user.isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Cannot delete Primary Business Owner / Superadmin account!'),
            backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Account: ${user.name}?'),
        content: Text(
            'Are you sure you want to permanently remove "@${user.username}"? They will no longer be able to log in to this terminal.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (user.id != null) {
                final db = await DatabaseService.initialize();
                await db.deleteUser(user.id!);
                Navigator.pop(ctx);
                _loadUsers();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('User ${user.name} removed.'),
                      backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. KEY FEATURE: USER AUTHORIZATION & PERMISSIONS CONTROL CENTER
  // =========================================================================
  void _showPermissionsDialog(User user) {
    bool canEditPrice = user.canEditPrice;
    bool canGiveDiscount = user.canGiveDiscount;
    double maxDiscount = user.maxDiscountPercent;
    bool canViewCostPrice = user.canViewCostPrice;
    bool canDeleteSale = user.canDeleteSale;
    bool canProcessReturn = user.canProcessReturn;
    bool canAccessKhata = user.canAccessKhata;
    bool canAccessInventory = user.canAccessInventory;
    bool canAccessReports = user.canAccessReports;
    bool canAccessSettings = user.canAccessSettings;
    bool canManageUsers = user.canManageUsers;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

          return AlertDialog(
            backgroundColor: cardBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_rounded,
                              color: Color(0xFF4F46E5), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Salesman & Staff Authorization Matrix',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Owner Control: Grant or revoke specific permissions for ${user.name} (@${user.username})',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _roleBadge(user.role),
                  ],
                ),
                const SizedBox(height: 12),
                // QUICK PRESETS
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Text('Quick Role Presets:',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(
                                Icons.admin_panel_settings_rounded,
                                size: 16,
                                color: Color(0xFF4F46E5)),
                            label: const Text('Full Owner',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                            backgroundColor: const Color(0xFFEEF2FF),
                            onPressed: () {
                              setDlgState(() {
                                canEditPrice = true;
                                canGiveDiscount = true;
                                maxDiscount = 100.0;
                                canViewCostPrice = true;
                                canDeleteSale = true;
                                canProcessReturn = true;
                                canAccessKhata = true;
                                canAccessInventory = true;
                                canAccessReports = true;
                                canAccessSettings = true;
                                canManageUsers = true;
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.shield_outlined,
                                size: 16, color: Color(0xFF059669)),
                            label: const Text('Store Manager',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                            backgroundColor: const Color(0xFFECFDF5),
                            onPressed: () {
                              setDlgState(() {
                                canEditPrice = true;
                                canGiveDiscount = true;
                                maxDiscount = 20.0;
                                canViewCostPrice = true;
                                canDeleteSale = true;
                                canProcessReturn = true;
                                canAccessKhata = true;
                                canAccessInventory = true;
                                canAccessReports = true;
                                canAccessSettings = false;
                                canManageUsers = false;
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.point_of_sale_rounded,
                                size: 16, color: Color(0xFF2563EB)),
                            label: const Text('Standard Salesman',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                            backgroundColor: const Color(0xFFEFF6FF),
                            onPressed: () {
                              setDlgState(() {
                                canEditPrice = false;
                                canGiveDiscount = true;
                                maxDiscount = 5.0;
                                canViewCostPrice = false;
                                canDeleteSale = false;
                                canProcessReturn = false;
                                canAccessKhata = true;
                                canAccessInventory = false;
                                canAccessReports = false;
                                canAccessSettings = false;
                                canManageUsers = false;
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.lock_outline_rounded,
                                size: 16, color: Color(0xFFDC2626)),
                            label: const Text('Restricted Cashier',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                            backgroundColor: const Color(0xFFFEF2F2),
                            onPressed: () {
                              setDlgState(() {
                                canEditPrice = false;
                                canGiveDiscount = false;
                                maxDiscount = 0.0;
                                canViewCostPrice = false;
                                canDeleteSale = false;
                                canProcessReturn = false;
                                canAccessKhata = false;
                                canAccessInventory = false;
                                canAccessReports = false;
                                canAccessSettings = false;
                                canManageUsers = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 720,
              height: 480,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: POS COUNTER & SALES CONTROLS
                    _sectionHeader(
                        '1. POS COUNTER & SALE CONTROLS (کاؤنٹر سیلز پر کنٹرول)'),
                    _permissionSwitch(
                      icon: Icons.price_change_outlined,
                      title:
                          'Allow Altering Unit Prices at Counter (سیلنگ پرائس تبدیل کرنے کا اختیار)',
                      subtitle:
                          'When OFF, the salesman CANNOT change item retail prices on the counter.',
                      value: canEditPrice,
                      activeColor: Colors.orange,
                      onChanged: (v) => setDlgState(() => canEditPrice = v),
                    ),
                    _permissionSwitch(
                      icon: Icons.discount_outlined,
                      title: 'Allow Giving Discounts (ڈسکاؤنٹ دینے کا اختیار)',
                      subtitle:
                          'Enable or disable invoice & item discounts for this salesman.',
                      value: canGiveDiscount,
                      activeColor: const Color(0xFF4F46E5),
                      onChanged: (v) => setDlgState(() => canGiveDiscount = v),
                    ),
                    if (canGiveDiscount)
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 48, right: 16, bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.percent_rounded,
                                  size: 16, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 8),
                              const Text('Max Allowed Discount Rate: ',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Slider(
                                  value: maxDiscount.clamp(0.0, 100.0),
                                  min: 0,
                                  max: 50,
                                  divisions: 50,
                                  label: '${maxDiscount.toStringAsFixed(0)}%',
                                  onChanged: (val) =>
                                      setDlgState(() => maxDiscount = val),
                                ),
                              ),
                              Container(
                                width: 50,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                    '${maxDiscount.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    _permissionSwitch(
                      icon: Icons.delete_sweep_outlined,
                      title:
                          'Allow Voiding & Deleting Completed Sales (بل ڈیلیٹ یا کینسل کرنا)',
                      subtitle:
                          'Prevents salesmen from voiding invoices or erasing records without owner authorization.',
                      value: canDeleteSale,
                      activeColor: Colors.red,
                      onChanged: (v) => setDlgState(() => canDeleteSale = v),
                    ),

                    const SizedBox(height: 12),
                    // SECTION 2: PROFIT & FINANCIAL CONFIDENTIALITY
                    _sectionHeader(
                        '2. PROFIT & FINANCIAL CONFIDENTIALITY (خریداری قیمت اور منافع کا تحفظ)'),
                    _permissionSwitch(
                      icon: Icons.visibility_off_outlined,
                      title:
                          'View Purchase / Cost Price & Profit Margins (خریداری ریٹ اور نفع دیکھنا)',
                      subtitle:
                          'When OFF, purchase cost & profit margins are hidden (••••••) from the salesman.',
                      value: canViewCostPrice,
                      activeColor: const Color(0xFF059669),
                      onChanged: (v) => setDlgState(() => canViewCostPrice = v),
                    ),
                    _permissionSwitch(
                      icon: Icons.keyboard_return_rounded,
                      title:
                          'Authorize Sales Returns & Cash Refunds (سیلز واپسی اور کیش ریفنڈ)',
                      subtitle:
                          'Requires manager approval for accepting product returns and paying out cash.',
                      value: canProcessReturn,
                      activeColor: const Color(0xFF0284C7),
                      onChanged: (v) => setDlgState(() => canProcessReturn = v),
                    ),
                    _permissionSwitch(
                      icon: Icons.menu_book_rounded,
                      title:
                          'Access Customer Khata & Credit Ledgers (کسٹمر ادھار کھاتہ)',
                      subtitle:
                          'Allows salesman to view customer debit/credit balance & record ledger recoveries.',
                      value: canAccessKhata,
                      activeColor: const Color(0xFF4F46E5),
                      onChanged: (v) => setDlgState(() => canAccessKhata = v),
                    ),

                    const SizedBox(height: 12),
                    // SECTION 3: BACK-OFFICE & ADMINISTRATIVE POWERS
                    _sectionHeader(
                        '3. BACK-OFFICE & SYSTEM POWERS (بیک آفس اور سسٹم کنٹرول)'),
                    _permissionSwitch(
                      icon: Icons.inventory_2_outlined,
                      title:
                          'Inventory Stock Transfers & Adjustments (اسٹاک ٹرانسفر اور آڈٹ)',
                      subtitle:
                          'Allows stock adjustments, warehouse transfers, and inventory balance changes.',
                      value: canAccessInventory,
                      activeColor: const Color(0xFF7C3AED),
                      onChanged: (v) =>
                          setDlgState(() => canAccessInventory = v),
                    ),
                    _permissionSwitch(
                      icon: Icons.bar_chart_rounded,
                      title:
                          'View Sales, Tax & Profit/Loss Reports (رپورٹس اور منافع دیکھنا)',
                      subtitle:
                          'Access to business performance analytics, annual turnover, and tax summaries.',
                      value: canAccessReports,
                      activeColor: const Color(0xFF059669),
                      onChanged: (v) => setDlgState(() => canAccessReports = v),
                    ),
                    _permissionSwitch(
                      icon: Icons.settings_suggest_rounded,
                      title:
                          'Access Store Settings & Configurations (سسٹم سیٹنگز)',
                      subtitle:
                          'Modify store profile, invoice templates, tax setup, and cloud sync parameters.',
                      value: canAccessSettings,
                      activeColor: const Color(0xFFD97706),
                      onChanged: (v) =>
                          setDlgState(() => canAccessSettings = v),
                    ),
                    _permissionSwitch(
                      icon: Icons.supervisor_account_rounded,
                      title:
                          'Manage Other Users & Staff Permissions (دیگر اسٹاف کے اختیارات)',
                      subtitle:
                          'Grant or revoke permissions for other employees.',
                      value: canManageUsers,
                      activeColor: Colors.redAccent,
                      onChanged: (v) => setDlgState(() => canManageUsers = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Apply & Save Authorization',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  // Record explicit per-user overrides for any toggled authorization switches
                  // so DB RBAC resolution honors individual grants/revocations cleanly.
                  final rawTokens = user.permissions
                      .split(',')
                      .map((e) => e.trim().toLowerCase())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  final hadCacheMarker = rawTokens.contains('__rbac__');
                  final overrideTokens = <String>{
                    ...rawTokens.where((e) =>
                        e != '__rbac__' &&
                        (!hadCacheMarker ||
                            e.startsWith('+') ||
                            e.startsWith('-'))),
                  };

                  void syncFlag(String key, bool before, bool after) {
                    if (before == after) return;
                    overrideTokens.remove('+$key');
                    overrideTokens.remove('-$key');
                    overrideTokens.remove(key);
                    overrideTokens.add(after ? '+$key' : '-$key');
                  }

                  void syncGroup(List<String> keys, bool before, bool after) {
                    for (final k in keys) {
                      syncFlag(k, before, after);
                    }
                  }

                  syncFlag('pos.edit_price', user.canEditPrice, canEditPrice);
                  syncFlag('pos.give_discount', user.canGiveDiscount, canGiveDiscount);
                  syncFlag('report.view_cost_price', user.canViewCostPrice, canViewCostPrice);
                  syncFlag('sale.delete', user.canDeleteSale, canDeleteSale);
                  syncFlag('sale.return', user.canProcessReturn, canProcessReturn);
                  syncFlag('contact.khata_payment', user.canAccessKhata, canAccessKhata);
                  syncGroup(
                    const ['inventory.transfer', 'inventory.adjust', 'inventory.audit'],
                    user.canAccessInventory,
                    canAccessInventory,
                  );
                  syncGroup(
                    const ['report.view', 'report.view_profit'],
                    user.canAccessReports,
                    canAccessReports,
                  );
                  syncFlag('settings.manage', user.canAccessSettings, canAccessSettings);
                  syncFlag('user.manage', user.canManageUsers, canManageUsers);

                  final updated = user.copyWith(
                    canEditPrice: canEditPrice,
                    canGiveDiscount: canGiveDiscount,
                    maxDiscountPercent: maxDiscount,
                    canViewCostPrice: canViewCostPrice,
                    canDeleteSale: canDeleteSale,
                    canProcessReturn: canProcessReturn,
                    canAccessKhata: canAccessKhata,
                    canAccessInventory: canAccessInventory,
                    canAccessReports: canAccessReports,
                    canAccessSettings: canAccessSettings,
                    canManageUsers: canManageUsers,
                    permissions: overrideTokens.join(','),
                  );

                  final db = await DatabaseService.initialize();
                  await db.updateUser(updated);

                  // Update currently logged-in user session if self
                  if (AuthService.currentUser?.id == user.id ||
                      AuthService.currentUser?.username == user.username) {
                    final eff = await db.getEffectivePermissionsForUser(updated);
                    AuthService.currentUserNotifier.value = updated.copyWith(
                      permissions: {'__rbac__', ...eff}.join(','),
                    );
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadUsers();

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.verified_user_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                'Authorization updated! Restrictions are now actively enforced for ${user.name}.'),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4F46E5),
            letterSpacing: 0.5),
      ),
    );
  }

  Widget _permissionSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value
              ? activeColor.withValues(alpha: 0.3)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: SwitchListTile(
        dense: true,
        secondary: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (value ? activeColor : Colors.grey).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: value ? activeColor : Colors.grey, size: 18),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        activeThumbColor: activeColor,
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _roleBadge(String role) {
    Color bg;
    Color fg;
    String label;

    switch (role.toLowerCase()) {
      case 'superadmin':
      case 'owner':
        bg = const Color(0xFFEEF2FF);
        fg = const Color(0xFF4F46E5);
        label = 'Owner / Super Admin';
        break;
      case 'admin':
        bg = const Color(0xFFEDE9FE);
        fg = const Color(0xFF7C3AED);
        label = 'Admin';
        break;
      case 'manager':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        label = 'Store Manager';
        break;
      case 'cashier':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        label = 'Cashier';
        break;
      case 'salesman':
      default:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF0284C7);
        label = 'Salesman';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style:
              TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  // =========================================================================
  // 5. MAIN BUILD METHOD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = _users.length;
    final salesmanCount = _users
        .where((u) => u.isSalesman || u.role.toLowerCase() == 'salesman')
        .length;
    final managerCount = _users.where((u) => u.isManager).length;
    final adminCount = _users.where((u) => u.isAdmin).length;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(144),
        child: Container(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.manage_accounts_rounded,
                                    color: Color(0xFF4F46E5), size: 22),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'User Management & Authorization Control Center',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 19, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Owner Controls: Set fine-grained permissions for salesmen, cashiers, supervisors & managers.',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            icon:
                                const Icon(Icons.person_add_rounded, size: 16),
                            label: const Text('Add Staff Member',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: _showAddUserDialog,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded,
                                color: Color(0xFF4F46E5)),
                            tooltip: 'Refresh List',
                            onPressed: _loadUsers,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: const Color(0xFF4F46E5),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF4F46E5),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(
                        icon: const Icon(Icons.people_alt_rounded, size: 17),
                        text: 'Staff & Salesmen Accounts ($totalCount)'),
                    const Tab(
                        icon:
                            Icon(Icons.admin_panel_settings_rounded, size: 17),
                        text: 'Roles & Permissions Matrix'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 0: USERS LIST & AUTHORIZATION TABLE
          _buildUsersTab(
              isDark, totalCount, salesmanCount, managerCount, adminCount),

          // TAB 1: ROLES & PRESETS OVERVIEW
          _buildRolesMatrixTab(isDark),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 0 IMPLEMENTATION: USERS TABLE & STATS
  // =========================================================================
  Widget _buildUsersTab(
      bool isDark, int total, int salesmen, int managers, int admins) {
    final filtered = _filteredUsers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STATS METRICS BAR
          Row(
            children: [
              _metricCard('Total Staff', total.toString(), Icons.people_outline,
                  const Color(0xFF4F46E5), isDark),
              const SizedBox(width: 14),
              _metricCard('Field & Counter Salesmen', salesmen.toString(),
                  Icons.point_of_sale_rounded, const Color(0xFF0284C7), isDark),
              const SizedBox(width: 14),
              _metricCard('Store Managers', managers.toString(),
                  Icons.badge_outlined, const Color(0xFF059669), isDark),
              const SizedBox(width: 14),
              _metricCard('Super Administrators', admins.toString(),
                  Icons.shield_rounded, const Color(0xFF7C3AED), isDark),
            ],
          ),
          const SizedBox(height: 20),

          // SEARCH & FILTER BAR
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText:
                          'Search staff by name, username, email, phone, or role...',
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: Color(0xFF94A3B8)),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedRoleFilter,
                  items: const [
                    DropdownMenuItem(
                        value: 'All', child: Text('Filter Role: All Roles')),
                    DropdownMenuItem(
                        value: 'salesman', child: Text('Salesman Only')),
                    DropdownMenuItem(
                        value: 'cashier', child: Text('Cashier Only')),
                    DropdownMenuItem(
                        value: 'manager', child: Text('Manager Only')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin Only')),
                    DropdownMenuItem(
                        value: 'superadmin',
                        child: Text('Super Admin / Owner Only')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRoleFilter = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // USERS TABLE
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x04000000),
                    blurRadius: 6,
                    offset: Offset(0, 2))
              ],
            ),
            child: _loading
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator()))
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text('No users found matching query.',
                              style: TextStyle(color: Colors.grey.shade500)),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                          ),
                          columns: const [
                            DataColumn(
                                label: Text('Staff Member',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Username',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Role',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Counter Authorization',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Branch / Phone',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Status',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Authorization Control',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                          ],
                          rows: filtered.map((u) {
                            return DataRow(cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color(0xFFEEF2FF),
                                      child: Text(
                                        u.name.isNotEmpty
                                            ? u.name[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF4F46E5),
                                            fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(u.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                        if (u.email.isNotEmpty)
                                          Text(u.email,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(Text(u.username,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4F46E5)))),
                              DataCell(_roleBadge(u.role)),
                              DataCell(
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: [
                                    _pill(
                                      u.canEditPrice
                                          ? 'Price Edit: ON'
                                          : 'Price Edit: OFF',
                                      u.canEditPrice
                                          ? Colors.orange
                                          : Colors.grey,
                                      u.canEditPrice
                                          ? const Color(0xFFFFF7ED)
                                          : const Color(0xFFF1F5F9),
                                    ),
                                    _pill(
                                      u.canGiveDiscount
                                          ? 'Max Disc: ${u.maxDiscountPercent.toInt()}%'
                                          : 'No Disc',
                                      u.canGiveDiscount
                                          ? const Color(0xFF4F46E5)
                                          : Colors.grey,
                                      u.canGiveDiscount
                                          ? const Color(0xFFEEF2FF)
                                          : const Color(0xFFF1F5F9),
                                    ),
                                    _pill(
                                      u.canViewCostPrice
                                          ? 'Cost: Visible'
                                          : 'Cost: Hidden',
                                      u.canViewCostPrice
                                          ? const Color(0xFF059669)
                                          : Colors.red,
                                      u.canViewCostPrice
                                          ? const Color(0xFFECFDF5)
                                          : const Color(0xFFFEF2F2),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(u.branchName,
                                        style: const TextStyle(fontSize: 12)),
                                    if (u.phone.isNotEmpty)
                                      Text(u.phone,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: u.status == 'active'
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    u.status == 'active'
                                        ? 'Active'
                                        : 'Suspended',
                                    style: TextStyle(
                                      color: u.status == 'active'
                                          ? const Color(0xFF059669)
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF4F46E5),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(6)),
                                      ),
                                      icon: const Icon(Icons.shield_outlined,
                                          size: 14),
                                      label: const Text('Authorization',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                      onPressed: () =>
                                          _showPermissionsDialog(u),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 16, color: Color(0xFF0284C7)),
                                      tooltip: 'Edit Profile',
                                      onPressed: () => _showEditUserDialog(u),
                                    ),
                                    if (!u.isSuperAdmin)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 16, color: Colors.red),
                                        tooltip: 'Remove User',
                                        onPressed: () => _confirmDeleteUser(u),
                                      ),
                                  ],
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style:
              TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _metricCard(
      String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A))),
                  Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 1 IMPLEMENTATION: ROLES & PERMISSIONS MATRIX
  // =========================================================================
  Future<void> _showRoleEditorDialog([AppRole? existing]) async {
    final canManageRoles =
        AuthService.currentUser?.hasPermission('role.manage') ?? true;
    if (!canManageRoles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission denied: Only users with "role.manage" can modify roles.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final displayCtrl = TextEditingController(text: existing?.displayName ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final selectedKeys = Set<String>.from(existing?.permissions ?? <String>[]);

    final Map<String, List<AppPermission>> grouped = {};
    for (final perm in PermissionCatalog.all) {
      grouped.putIfAbsent(perm.category, () => []).add(perm);
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  existing == null ? 'Create Custom Role' : 'Edit Role: ${existing.displayName}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${selectedKeys.length} / ${PermissionCatalog.all.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
              ),
            ],
          ),
          content: SizedBox(
            width: 580,
            height: 470,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: displayCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Role Display Name * (e.g. Senior Cashier)',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        enabled: existing?.isSystem != true,
                        decoration: const InputDecoration(
                          labelText: 'Role Key (e.g. senior_cashier)',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Role Description',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: grouped.entries.map((catEntry) {
                      final catPerms = catEntry.value;
                      final allCatChecked =
                          catPerms.every((p) => selectedKeys.contains(p.key));
                      return ExpansionTile(
                        initiallyExpanded: true,
                        tilePadding: EdgeInsets.zero,
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${catEntry.key} (${catPerms.where((p) => selectedKeys.contains(p.key)).length}/${catPerms.length})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setDlgState(() {
                                  if (allCatChecked) {
                                    for (final p in catPerms) {
                                      selectedKeys.remove(p.key);
                                    }
                                  } else {
                                    for (final p in catPerms) {
                                      selectedKeys.add(p.key);
                                    }
                                  }
                                });
                              },
                              child: Text(
                                allCatChecked ? 'Clear Category' : 'Select All',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                        children: catPerms.map((perm) {
                          final checked = selectedKeys.contains(perm.key);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.only(left: 8),
                            value: checked,
                            title: Text(perm.label, style: const TextStyle(fontSize: 12.5)),
                            subtitle: Text(perm.key, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            onChanged: (v) {
                              setDlgState(() {
                                if (v == true) {
                                  selectedKeys.add(perm.key);
                                } else {
                                  selectedKeys.remove(perm.key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.save_rounded, size: 17),
              label: const Text('Save Role Permissions'),
              onPressed: () async {
                final disp = displayCtrl.text.trim();
                final rawName = nameCtrl.text.trim().isNotEmpty
                    ? nameCtrl.text.trim()
                    : disp.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
                if (disp.isEmpty || rawName.isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                final roleObj = AppRole(
                  id: existing?.id,
                  name: rawName,
                  displayName: disp,
                  description: descCtrl.text.trim(),
                  isSystem: existing?.isSystem ?? false,
                  permissions: selectedKeys.toList(),
                );
                final db = await DatabaseService.initialize();
                final savedId = await db.saveRole(roleObj);

                // Refresh active user's effective RBAC permissions if they hold this role.
                final cur = AuthService.currentUser;
                if (cur != null &&
                    (cur.roleId == savedId ||
                        cur.role.toLowerCase() == roleObj.name.toLowerCase())) {
                  final dbUsers = await db.getUsers();
                  final freshCur = dbUsers.cast<User?>().firstWhere(
                        (u) => u?.id == cur.id || u?.username == cur.username,
                        orElse: () => cur,
                      ) ??
                      cur;
                  final eff = await db.getEffectivePermissionsForUser(freshCur);
                  AuthService.currentUserNotifier.value = freshCur.copyWith(
                    permissions: {'__rbac__', ...eff}.join(','),
                  );
                }

                if (ctx.mounted) Navigator.pop(ctx);
                await _loadUsers();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Saved role "$disp" with ${selectedKeys.length} permission(s).',
                      ),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolesMatrixTab(bool isDark) {
    final permLookup = {for (final p in PermissionCatalog.all) p.key: p.label};
    final palette = [
      const Color(0xFF4F46E5),
      const Color(0xFF059669),
      const Color(0xFF0284C7),
      const Color(0xFFD97706),
      const Color(0xFF7C3AED),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Granular Role-Based Access Control (RBAC) Matrix',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_roles.length} configured roles across ${PermissionCatalog.all.length} fine-grained permissions',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_moderator_rounded, size: 18),
                label: const Text('Create Custom Role'),
                onPressed: () => _showRoleEditorDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_roles.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No RBAC roles found.'),
              ),
            )
          else
            ..._roles.asMap().entries.map((entry) {
              final idx = entry.key;
              final role = entry.value;
              final col = palette[idx % palette.length];
              final rights = role.permissions;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: col.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.verified_user_rounded,
                                    color: col, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          role.displayName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            role.name,
                                            style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'),
                                          ),
                                        ),
                                        if (role.isSystem)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE0E7FF),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'SYSTEM',
                                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF3730A3)),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (role.description.isNotEmpty)
                                      Text(
                                        role.description,
                                        style: const TextStyle(
                                            fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: col.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${rights.length} Rights Authorized',
                                  style: TextStyle(
                                      color: col,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.tune_rounded, size: 15),
                              label: const Text('Edit Permissions', style: TextStyle(fontSize: 12)),
                              onPressed: () => _showRoleEditorDialog(role),
                            ),
                            if (!role.isSystem)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                tooltip: 'Delete Custom Role',
                                onPressed: () async {
                                  if (role.id == null) return;
                                  final db = await DatabaseService.initialize();
                                  await db.deleteRole(role.id!);
                                  await _loadUsers();
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: rights.map((rt) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: col, size: 14),
                              const SizedBox(width: 5),
                              Text(permLookup[rt] ?? rt,
                                  style: const TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class ContainerIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const ContainerIcon({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
