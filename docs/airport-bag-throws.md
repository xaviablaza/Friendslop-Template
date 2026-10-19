# Weighted baggage throws and two-player catches

Continue `airport-baggage` from `9bc9b819dfcc461c951100bcf702a2417d625763` without changing the sushi branch.

## Player behavior
- G throws a carried bag in the camera aim direction; Q gently places it down. Dog/items retain gentle placement (never throw the dog). E catches a nearby airborne bag or picks up a grounded/belt bag.
- Each bag has an explicit mass. Constant-strength throws produce shorter/slower trajectories for heavier baggage, with common gravity, landing/bounce/friction and slower loaded walking.
- Host owns all flight, collision and catch transitions. A catch requires an empty-handed player within reach of an actually airborne bag; simultaneous attempts cannot create duplicate ownership.
- Bags removed from the conveyor have a yellow silhouette outline, including held, airborne and floor states. Returning a bag to the conveyor removes that highlight.
- Carrying uses a centered camera-visible bag with both forearms/gloved hands visibly supporting it. Remote players have recognizable worker models and a matching two-handed carrying pose.

## Evidence
- Focused unit tests: masses, momentum/range, gravity, landing, invalid throws, catch range/airborne checks, simultaneous ownership, snapshots and disconnects.
- Two actual ENet peers use normal keys for bag removal, ground throws and an aerial relay: player 1 throws to player 2, then player 2 returns the bag and player 1 catches it before it touches ground.
- Record both real player windows together on a private Xvfb display; no cloned actor or manufactured packet success. Warm-up may collect actual arriving bags before capture; disclose automated controls.
- Show weighted ground throws and both players' mid-air catches; inspect yellow outlines and camera-visible two-handed poses in the encoded video. Preserve event heights/owners/masses and both peer reports.
- Preserve prior airport and sushi behavior, review changes, commit/push the named branch and read back its exact SHA.

This is a native Godot greybox, not a recreation of Payday assets, animations or branding. Co-op catch means one owner at a time in a two-player relay, not two simultaneous owners of the same bag.
