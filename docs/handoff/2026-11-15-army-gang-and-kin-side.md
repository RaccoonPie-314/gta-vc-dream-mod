# Handoff: the army gang's gun, the kin side, and the wander gate

Date: 2026-11-15
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `aebb665` (committed this session)
Installed: `vcmods build 582` in `~/Games/VC/reVC.app`
Published: `gta-vc-dream-mod` pushed with this work
Harness: 48 harnesses green (`cd reVC/utils && for f in test_vc_*.py; do python3 "$f"; done`)

## Session result

Four defects found in play on the army-gang build, all fixed, played and
confirmed; the whole uncommitted tree (this session's fixes plus the earlier
CALL GANG, ammo, save and army-gang work) is committed as `aebb665` and shipped.

### Army-gang shots did nothing

Shooting a cop as the army gang played the rifle animation with no round, no
sound and no damage. `CPed::CanBeDamagedByThisGangMember` tests
`m_gangFlags & (1 << gangIndex)` and `m_gangFlags` is one byte: GANG9 is index 8,
bit `0x100`, which the field can never hold, so every ped read as immune.
`CWeapon::FireInstantHit` then returned before damage, the gunshot event, the
flash and the tracer.

Fix: a gang index past the byte (GANG9) is never masked, in
`src/peds/PedAI.cpp`. GANG1..GANG8 read the mask exactly as stock.

### The wander restarted while controls were disabled

`VCModStreetWanderBreak` ends the walk when `pad->ArePlayerControlsDisabled()`
is set (the debug menu sets it while open, and so do garages, phones and
cutscenes), but the mode's fallback start did not check it. Every frame the walk
ended and was re-issued: `wander started` / `wander ended (controls taken)`
alternating in `reVC.log` for hundreds of frames. The start now takes the same
break gate (`VCModUpdateNpcMode`, `src/extras/vcmodnpc.cpp`).

### One gang is one side

Playing as a gang, a stray hit on kin made them fight back and drew blood. Stock
already swallows same-ped-type gang bullets in `DoBulletImpact`; what still went
through was melee, rams, the army bridge (GANG9 vs the base's army-modeled
GANG3), shotgun pellets and drive-bys.

`VCModGangSameGang` (`src/extras/vcmodgang.cpp`) gates:

- `CPed::InflictDamage` — no damage from a same-side ped or their car;
- `CPed::ReactToAttack` — a kin hit never provokes, victim or kin;
- the blood spawns in `DoBulletImpact`, `FireShotgun`, `FireInstantHitFromCar`
  and `CPed::Fight` — trace, dust and report still play, blood does not.

The player's side follows the worn body: the mode's own identity while it runs,
otherwise the model's gang (the GANGS-shelf army alias is GANG9). Turning the
mode off therefore no longer drops the immunity, which was the "disband then hit
a member" report.

A CALL GANG member never flees on his own: both `SetFlee` overloads and the flee
objective gate (`VCModGangRefuseFleeObjective`) take `VCModGangGroupOwnsPed`, so
a chased man holds the leader instead of breaking off.

### Asked and answered, no code

When a cop shoots a member, the rest of the group is not alerted. That is stock:
`RegisterThreatWithGangPeds` only spreads an attack when the attacker is the
player or a gang member, and the leader only shares combat targets downward
(`UpdateFromLeader`). The rally-on-member-hit idea was declined — stick to stock.

## Verification

- Harness: `test_vc_gangfaction.py` gained the GANG9 gate, the body-side cases,
  the group flee case and the no-blood source checks; `test_vc_npcmode.py` the
  controls-gate restart case; `test_vc_ganggroup.py` the flee hooks. Full suite
  green.
- Installed builds 574, 576, 580, 582 with the game closed; the shooting fix, the
  kin side, the no-blood tweak and the flee gate were all confirmed in play.
- `scripts/sync.sh`, `VC_MODS_OPERATOR=RaccoonPie-314 scripts/publish.sh
  ./gta-vc-dream-mod`, then the handout commit and `push origin main`.

## Next steps

1. The two rows that have never been played: `INFINITE AMMO` below 100% and the
   pause menu `SAVE GAME` (the autosave has fired after missions in the log).
2. The CALL GANG walk-up join into a world kin circle, and the body-side rule
   outside the mode, are harness-pinned only.
3. Whether the bridged army counts the barracks/rhino crews (COP type, army
   model) as one army is still an open call; today only the repainted GANG3
   soldiers bridge.

## Do not touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
  read-only.
- `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.

## Paste-ready prompt

> Continue vc-mod, reVC checkout `reVC/`, branch `vcmods`, HEAD `aebb665`,
> installed `vcmods build 582` in `~/Games/VC/reVC.app`; the work is published to
> `gta-vc-dream-mod`. Read `docs/handoff/2026-11-15-army-gang-and-kin-side.md`.
> The army gang (GANG9) ships with CALL GANG, infinite ammo, save-anywhere and
> autosave. Open items: play `INFINITE AMMO` below 100% and the pause menu
> `SAVE GAME`; the walk-up kin-circle join; and decide whether army-modeled COP
> crews (barracks/rhino) count as the same army for the one-side rule. No git
> actions unless asked; game data and the `uchg` anim files stay untouched.
