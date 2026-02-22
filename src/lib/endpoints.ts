// ============================================================
// API Endpoints — Kaynak: core/network/APIEndpoints.gd (133 satır)
// ============================================================

const API_VERSION = "/api/v1";

export const APIEndpoints = {
  // Authentication (Edge Functions)
  AUTH_LOGIN: "/functions/v1/auth-login",
  AUTH_REGISTER: "/functions/v1/auth-register",
  AUTH_LOGOUT: "/auth/v1/logout",
  AUTH_REFRESH: "/auth/v1/token?grant_type=refresh_token",
  AUTH_RESET_PASSWORD: "/auth/v1/recover",

  // Player (Edge Function)
  PLAYER_PROFILE: "/functions/v1/player-profile",
  PLAYER_UPDATE: `${API_VERSION}/player/update`,
  PLAYER_STATS: `${API_VERSION}/player/stats`,
  PLAYER_SEARCH: `${API_VERSION}/player/search`,

  // Energy
  ENERGY_STATUS: `${API_VERSION}/energy/status`,
  ENERGY_REFILL: `${API_VERSION}/energy/refill`,
  ENERGY_SYNC: `${API_VERSION}/energy/sync`,

  // Inventory (RPC)
  INVENTORY_RPC_GET: "/rest/v1/rpc/get_inventory",
  INVENTORY_RPC_ADD: "/rest/v1/rpc/add_inventory_item_v2",
  INVENTORY_RPC_REMOVE: "/rest/v1/rpc/remove_inventory_item",
  INVENTORY_RPC_EQUIP: "/rest/v1/rpc/equip_item",
  INVENTORY_RPC_UNEQUIP: "/rest/v1/rpc/unequip_item",
  INVENTORY_RPC_REMOVE_BY_ROW: "/rest/v1/rpc/remove_inventory_item_by_row",
  INVENTORY_RPC_UPDATE_POSITIONS: "/rest/v1/rpc/update_item_positions",
  INVENTORY_RPC_ENHANCE: "/rest/v1/rpc/upgrade_item_enhancement",
  INVENTORY_RPC_SWAP: "/rest/v1/rpc/swap_slots",
  INVENTORY_LIST: `${API_VERSION}/inventory`,
  INVENTORY_ADD: `${API_VERSION}/inventory/add`,
  INVENTORY_REMOVE: `${API_VERSION}/inventory/remove`,
  INVENTORY_EQUIP: `${API_VERSION}/inventory/equip`,
  INVENTORY_UNEQUIP: `${API_VERSION}/inventory/unequip`,

  // Dungeon
  DUNGEON_LIST: `${API_VERSION}/dungeon/list`,
  DUNGEON_START: `${API_VERSION}/dungeon/start`,
  DUNGEON_COMPLETE: `${API_VERSION}/dungeon/complete`,

  // Chat
  CHAT_HISTORY: `${API_VERSION}/chat/history`,
  CHAT_SEND: `${API_VERSION}/chat/send`,
  CHAT_BLOCK: `${API_VERSION}/chat/block`,
  CHAT_REPORT: `${API_VERSION}/chat/report`,

  // Season
  SEASON_CURRENT: `${API_VERSION}/season/current`,
  SEASON_LEADERBOARD: `${API_VERSION}/season/leaderboard`,
  SEASON_RANK: `${API_VERSION}/season/rank`,
  SEASON_BATTLE_PASS: `${API_VERSION}/season/battle_pass`,
  SEASON_CLAIM_REWARD: `${API_VERSION}/season/claim_reward`,
  SEASON_PURCHASE_PASS: `${API_VERSION}/season/purchase_battle_pass`,

  // Potion/Addiction
  POTION_USE: `${API_VERSION}/potion/use`,
  POTION_TOLERANCE: `${API_VERSION}/potion/tolerance`,
  POTION_LIST: `${API_VERSION}/potion/list`,

  // Hospital (Edge Functions)
  HOSPITAL_STATUS: `${API_VERSION}/hospital/status`,
  HOSPITAL_RELEASE: "/functions/v1/hospital-release",
  HOSPITAL_ADMIT: "/functions/v1/hospital-admit",
  HOSPITAL_CALL_HEALER: `${API_VERSION}/hospital/healer`,
  HOSPITAL_GUILD_HELP: `${API_VERSION}/hospital/guild-help`,

  // Quests
  QUEST_LIST: `${API_VERSION}/quests`,
  QUEST_START: `${API_VERSION}/quests/start`,
  QUEST_COMPLETE: `${API_VERSION}/quests/complete`,
  QUEST_ABANDON: `${API_VERSION}/quests/abandon`,
  QUEST_DAILY: `${API_VERSION}/quests/daily`,
  QUEST_PROGRESS: `${API_VERSION}/quests/progress`,

  // PvP
  PVP_LIST_TARGETS: `${API_VERSION}/pvp/targets`,
  PVP_ATTACK: `${API_VERSION}/pvp/attack`,
  PVP_REVENGE: `${API_VERSION}/pvp/revenge`,
  PVP_HISTORY: `${API_VERSION}/pvp/history`,
  PVP_LEADERBOARD: `${API_VERSION}/pvp/leaderboard`,

  // Market
  MARKET_TICKER: `${API_VERSION}/market/ticker`,
  MARKET_ORDER_BOOK: `${API_VERSION}/market/orderbook`,
  MARKET_CREATE_ORDER: `${API_VERSION}/market/order`,
  MARKET_CANCEL_ORDER: `${API_VERSION}/market/order/cancel`,
  MARKET_MY_ORDERS: `${API_VERSION}/market/orders/mine`,
  MARKET_TRADE_HISTORY: `${API_VERSION}/market/history`,
  MARKET_REGIONS: `${API_VERSION}/market/regions`,

  // Guild
  GUILD_LIST: `${API_VERSION}/guild/list`,
  GUILD_CREATE: `${API_VERSION}/guild/create`,
  GUILD_JOIN: `${API_VERSION}/guild/join`,
  GUILD_LEAVE: `${API_VERSION}/guild/leave`,
  GUILD_INFO: `${API_VERSION}/guild/info`,
  GUILD_MEMBERS: `${API_VERSION}/guild/members`,
  GUILD_INVITE: `${API_VERSION}/guild/invite`,
  GUILD_KICK: `${API_VERSION}/guild/kick`,
  GUILD_PROMOTE: `${API_VERSION}/guild/promote`,
  GUILD_DEMOTE: `${API_VERSION}/guild/demote`,
  GUILD_TREASURY: `${API_VERSION}/guild/treasury`,
  GUILD_DONATE: `${API_VERSION}/guild/donate`,
  GUILD_CHAT: `${API_VERSION}/guild/chat`,

  // Crafting (RPC)
  CRAFT_RECIPES: "/rest/v1/rpc/get_craft_recipes",
  CRAFT_ITEM: "/rest/v1/rpc/craft_item_async",
  CRAFT_QUEUE: "/rest/v1/rpc/get_craft_queue",
  CRAFT_CLAIM: "/rest/v1/rpc/claim_craft_item",
  ENHANCE_ITEM: `${API_VERSION}/enhance`,
  ENHANCE_CALCULATE: `${API_VERSION}/enhance/calculate`,

  // Facilities (Edge Functions)
  FACILITY_LIST: "/functions/v1/get_player_facilities",
  FACILITY_UNLOCK: "/functions/v1/unlock_facility",
  FACILITY_UPGRADE: "/functions/v1/upgrade_facility",
  FACILITY_START_PRODUCTION: "/functions/v1/start_facility_production",
  FACILITY_COLLECT: "/functions/v1/collect_facility_production",
  FACILITY_RECIPES: "/functions/v1/get_facility_recipes",
  FACILITY_OFFLINE_PRODUCTION: "/functions/v1/calculate_offline_production",
  FACILITY_SUSPICION_INCREMENT: "/functions/v1/increment_facility_suspicion",
  FACILITY_SUSPICION_REDUCE: "/functions/v1/reduce_facility_suspicion",
  FACILITY_BRIBE: "/functions/v1/bribe_officials",

  // Leaderboard
  LEADERBOARD_GLOBAL: `${API_VERSION}/leaderboard/global`,
  LEADERBOARD_SEASON: `${API_VERSION}/leaderboard/season`,
  LEADERBOARD_GUILD: `${API_VERSION}/leaderboard/guild`,

  // Shop
  SHOP_LIST: `${API_VERSION}/shop/items`,
  SHOP_BUY: `${API_VERSION}/shop/buy`,
  SHOP_BUNDLES: `${API_VERSION}/shop/bundles`,

  // Config
  CONFIG_GAME: `${API_VERSION}/config/game`,
  CONFIG_ITEMS: `${API_VERSION}/config/items`,
  CONFIG_QUESTS: `${API_VERSION}/config/quests`,

  // Telemetry
  TELEMETRY_EVENT: `${API_VERSION}/telemetry/events`,
  TELEMETRY_BATCH: `${API_VERSION}/telemetry/events`,
} as const;
