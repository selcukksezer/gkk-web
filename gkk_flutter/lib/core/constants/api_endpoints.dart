class ApiEndpoints {
  const ApiEndpoints._();

  static const String _apiVersion = '/api/v1';

  static const String authLogin = '/functions/v1/auth-login';
  static const String authRegister = '/functions/v1/auth-register';
  static const String authLogout = '/auth/v1/logout';
  static const String authRefresh = '/auth/v1/token?grant_type=refresh_token';
  static const String authResetPassword = '/auth/v1/recover';

  static const String playerProfile = '/functions/v1/player-profile';
  static const String playerUpdate = '$_apiVersion/player/update';
  static const String playerStats = '$_apiVersion/player/stats';
  static const String playerSearch = '$_apiVersion/player/search';

  static const String energyStatus = '$_apiVersion/energy/status';
  static const String energyRefill = '$_apiVersion/energy/refill';
  static const String energySync = '$_apiVersion/energy/sync';

  static const String inventoryRpcGet = '/rest/v1/rpc/get_inventory';
  static const String inventoryRpcAdd = '/rest/v1/rpc/add_inventory_item_v2';
  static const String inventoryRpcRemove = '/rest/v1/rpc/remove_inventory_item';
  static const String inventoryRpcEquip = '/rest/v1/rpc/equip_item';
  static const String inventoryRpcUnequip = '/rest/v1/rpc/unequip_item';
  static const String inventoryRpcRemoveByRow = '/rest/v1/rpc/remove_inventory_item_by_row';
  static const String inventoryRpcUpdatePositions = '/rest/v1/rpc/update_item_positions';
  static const String inventoryRpcEnhance = '/rest/v1/rpc/upgrade_item_enhancement';
  static const String inventoryRpcSwap = '/rest/v1/rpc/swap_slots';

  static const String craftRecipes = '/rest/v1/rpc/get_craft_recipes';
  static const String craftItem = '/rest/v1/rpc/craft_item_async';
  static const String craftQueue = '/rest/v1/rpc/get_craft_queue';
  static const String craftClaim = '/rest/v1/rpc/claim_crafted_item';

  static const String facilityList = '/functions/v1/get_player_facilities';
  static const String facilityUnlock = '/functions/v1/unlock_facility';
  static const String facilityUpgrade = '/functions/v1/upgrade_facility';
  static const String facilityStartProduction = '/functions/v1/start_facility_production';
  static const String facilityCollect = '/functions/v1/collect_facility_production';
  static const String facilityRecipes = '/functions/v1/get_facility_recipes';
  static const String facilityOfflineProduction = '/functions/v1/calculate_offline_production';
  static const String facilitySuspicionIncrement = '/functions/v1/increment_facility_suspicion';
  static const String facilitySuspicionReduce = '/functions/v1/reduce_facility_suspicion';
  static const String facilityBribe = '/functions/v1/bribe_officials';
}
