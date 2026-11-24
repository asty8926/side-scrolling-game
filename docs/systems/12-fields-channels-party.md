---
title: Hunting fields, channels, parties (multiplayer model)
system: fields-channels-party
priority: P2
milestone: M5 (party co-op), Later (fields, channels)
status: draft
issue: 12
sources:
  - https://elwiki.net/w/Hunting_Fields
  - https://elwiki.net/w/UI_Guide
  - https://elwiki.net/w/Dungeons
  - https://elwiki.net/w/Party_List_System
  - https://elwiki.net/w/Resurrection
  - https://elwiki.net/w/Fever
---

# Hunting fields, channels, parties

> Tracking issue: [#12](https://github.com/asty8926/side-scrolling-game/issues/12) · Milestone epic: [#22](https://github.com/asty8926/side-scrolling-game/issues/22)

## What it is in Elsword

### Parties and dungeon co-op

- Dungeons: solo or party of **1-4** (6 in raids). **Party leader** invites/expels and starts the dungeon; distinct from the **host**: "Choosing the correct person to be the party's host is important in many dungeons... due to the connection being reliant on the host. Some skills and effects do not work properly sometimes if the user is not the host." (Dungeons) → Elsword dungeons are (at least partly) **host-based P2P**, a known source of desync bugs.
- **Party matching:** "Start Dungeon" (F8) queues with players who chose the same difficulty; "Start with current members" goes immediately. **Heroes Assemble buff** scales stats for smaller parties (e.g. solo Lv.4: +123% attack, +39% def/HP). (Dungeons)
- **Party List System:** server-wide list of parties by region/dungeon; create with a title, apply, leader accepts. (Party_List_System)
- Forming a party: right-click a player in town/field → "Party Invite", or via friends/guild/party list. (UI Guide)
- **Fever** gauge: +1 per room the party completes, max 100; when full, random event refills party HP/MP/beads, +100% MP on attack for 20 s.
- Revive: knocks down all enemies in the room; dead players spectate a teammate.

### Channels

- "The channel you are currently in, as well as your location within the game, will be displayed in the top-right... you can quickly select another channel to switch to... (**Can only be used in towns**)." Megaphone messages reach everyone in the channel; the Extreme Megaphone reaches all channels. The "All" community tab lists every player in your **current location**. (UI Guide)
- Players on different channels don't see each other in the same town/field; channels have historically been grouped by **level range** (community/Steam, unverified).

### Hunting fields

- Open shared maps for EXP/drops (Elder: Wally's Memorial Bridge, lvl 9-13; Feita: Pilgrim's Site 37-39, ...).
- Mobs respawn at their spawn point after a set time; if pulled too far, they become invincible and run back (leash).
- **Aggressive** mobs (yellow HP bar) attack on sight; **Reactive** mobs (green HP bar) only when attacked.
- **Safe spots** unreachable by monsters (wider camera view). **Field Bosses** and Field Boss Raids exist. Player capacity per field exists (section on page; number not captured).
- Death in a field: revive with stone or teleport to nearby town/rest area.

## Why Asty loves it

> "...my real goal is for it to be multiplayer! Online co-op parties in dungeons and I suppose channel-based multiplayers on other maps like cities and monster 'fields' (if we include this feature later, like Elsword used to have)."

## What our version must do (acceptance criteria)

**M5 - party co-op (2-4 players in a dungeon)**
- [ ] **Server-authoritative or deterministic-lockstep/rollback** architecture chosen and documented in an ADR before M5 (NOT host-P2P like Elsword, given its host bugs). Simulation already deterministic from M1 (see [roadmap.md](../roadmap.md)).
- [ ] Party: create, invite by code/link, leader starts the dungeon; 1-4 players.
- [ ] All combat (hits, KD, MP, awakening, rank stats) resolved by the authoritative simulation; clients predict local movement/attacks.
- [ ] Playable at 100 ms RTT with no visible desync in a 10-minute session (automated soak test with simulated latency/jitter/loss).
- [ ] Solo scaling (Heroes-Assemble-like) so solo and party are both viable.

**Later - towns, fields, channels**
- [ ] Shared town instances (channels) with N players max per instance; channel switch only in towns.
- [ ] Hunting field with aggressive/reactive mobs, respawn timers, leash, safe spot.
- [ ] Self-hostable server (open source, free), so Asty doesn't pay for infra to test.

## Open questions

1. Netcode model: rollback (fighting-game style, best feel for combos) vs server-authoritative with prediction (better for 4 players + many mobs). Needs an ADR; likely server-authoritative sim + client prediction, with deterministic sim enabling replays.
2. Hosting for public play: free tiers or self-hosting by players? (Constraint: Asty pays only tokens.)
3. Do fields come before or after Henir? Proposal: after, they're the most server-heavy feature.

## Sources

- https://elwiki.net/w/Hunting_Fields
- https://elwiki.net/w/UI_Guide
- https://elwiki.net/w/Dungeons
- https://elwiki.net/w/Party_List_System
- https://elwiki.net/w/Resurrection
- https://elwiki.net/w/Fever
- Steam discussion (community, channels by level): https://steamcommunity.com/app/237310/discussions/0/558747287891054157/

## Images

| Local | What | Source |
|---|---|---|
| `../images/fields-channels/Wally_Memorial_Brigde.png` | Elder's hunting field | https://elwiki.net/w/Hunting_Fields |
| `../images/fields-channels/Full_Party_List.png` | Party List interface | https://elwiki.net/w/Party_List_System |
| `../images/fields-channels/Dungeon_Queue.png` | Dungeon queue button | same |

![Hunting field](../images/fields-channels/Wally_Memorial_Brigde.png)
