import '../models/capybara.dart';
import '../models/meadow_snapshot.dart';
import '../models/multipliers/multipliers.dart';
import 'game_core.dart';

/// Family roles (Няня / Собиратель / Сторож) within the shared slot pool.
class FamilyRoles extends GamePart {
  FamilyRoles(super.core);

  /// Assign [role] to capy; respects role slot limit. Null clears.
  bool assignRole(String capyId, CapyRole? role) {
    final capy = core.herd.find(capyId);
    if (capy == null) return false;
    if (role != null) {
      // Count slots excluding this capy's current role.
      var used = 0;
      for (final c in state.herd) {
        if (c.id == capyId) continue;
        if (c.role != null) used++;
      }
      for (final e in state.meadows.entries) {
        if (e.key == state.activeMeadowId) continue;
        for (final c in e.value.herd) {
          if (c.role != null) used++;
        }
      }
      if (capy.role == null && used >= state.roleSlots) return false;
    }
    final herd = [
      for (final c in state.herd)
        if (c.id == capyId)
          c.copyWith(role: role, clearRole: role == null)
        else
          c,
    ];
    core.commit(state.copyWith(herd: herd));
    if (role != null) {
      core.messages.roleToast = role.assignToastRu;
    }
    return true;
  }

  /// Give [role] to the first capy on this meadow who has none.
  bool assignRoleToFreeCapy(CapyRole role) {
    for (final capy in state.herd) {
      if (capy.role == role) return true;
    }
    for (final entry in state.meadows.entries) {
      if (entry.key == state.activeMeadowId) continue;
      for (final capy in entry.value.herd) {
        if (capy.role == role) return true;
      }
    }
    for (final capy in state.herd) {
      if (capy.role == null) return assignRole(capy.id, role);
    }
    return false;
  }

  /// Take [role] off whoever holds it, on any meadow of this land.
  bool clearRole(CapyRole role) {
    final synced = state.withActiveSynced();
    final meadows = Map<String, MeadowSnapshot>.from(synced.meadows);
    var changed = false;
    for (final entry in meadows.entries) {
      final next = <Capybara>[];
      for (final capy in entry.value.herd) {
        if (capy.role == role) {
          changed = true;
          next.add(capy.copyWith(clearRole: true));
        } else {
          next.add(capy);
        }
      }
      meadows[entry.key] = entry.value.copyWith(herd: next);
    }
    if (!changed) return false;
    final active = meadows[synced.activeMeadowId]!;
    core.commit(
      synced.copyWith(
        meadows: meadows,
        herd: active.herd,
        herdProgress: active.herdProgress,
        twinIdA: active.twinIdA,
        twinIdB: active.twinIdB,
        clearTwin: active.twinIdA == null || active.twinIdB == null,
      ),
    );
    return true;
  }
}
