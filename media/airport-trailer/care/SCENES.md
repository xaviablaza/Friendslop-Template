# Fresh PET / DOG / PROGRESSION footage

MP4: care-source.mp4 — 126.958333 sec; 1280×720, 24fps, H.264/yuv420p, silent.

Timecodes are MM:SS:FF at 24 fps; ranges are half-open.

| In | Out | Scene |
|---|---|---|
| 00:00:04 | 00:10:23 | cat_closed_open_and_empty_supplies |
| 00:10:23 | 00:15:19 | shared_care_station_finite_portions |
| 00:15:19 | 00:23:05 | cat_food_water_and_animal_care_handoff |
| 00:23:05 | 00:36:06 | rabbit_closed_open_food_water_handoff |
| 00:36:06 | 00:40:09 | kennel_gated_before_training_scan |
| 00:40:09 | 00:48:17 | dog_live_needs_feed_water_and_rest |
| 00:48:17 | 01:01:07 | dog_autonomous_follow_and_patrol |
| 01:01:07 | 01:06:13 | dog_carry_and_harmless_capped_G_throw |
| 01:06:13 | 01:14:02 | real_dog_scanner_crossing_LIVE_animal_Xray_XP |
| 01:14:02 | 01:34:11 | earn_remaining_funds_through_real_routes |
| 01:34:11 | 01:41:22 | earned_scanner_kennel_terminal_purchases |
| 01:41:22 | 01:59:21 | new_international_route_used |
| 01:59:21 | 02:06:21 | probabilistic_scent_clues_not_verdicts |

Assertions: 74 passed, 0 failed. Full MP4 decoded without errors.
Observed RNG scent outcomes: {'correct_silence': 3, 'false_positive': 1, 'correct_alert': 3, 'missed': 1}.

## Disclosures
- Automated single-player inputs, HEAD 663cb3a; scene staging teleports operator/camera and positions catalogue fixture bags between takes.
- Cat/rabbit and two organic + one legal reward fixtures use known catalogue objects and unlocked locks. Each fixture is staged before the real scanner and scanned through normal intake controls before inspection. Rewards, contracts and purchases are live, not pre-awarded.
- Initial food/water explicitly empty to exercise shortage. Currency, rewards, reputation, training XP and purchases are never seeded.
- Dog starts at the actual care station with default live needs; follow/patrol/throw/scanner and care all run the real simulation and interaction gateway.
- Scent scene uses known legal/restricted fixtures; actual live RNG is not replaced, selected or rerolled to manufacture an outcome.
- MovieMaker real OpenGL rendering, 1280x720 at 24fps; silent source footage; no chapter/title overlays.

## Limitations
- Automated fixture-staged solo footage, not a continuous human shift or multiplayer proof.
- All rewards and purchases are live. Staged object positions and known item truth are disclosed above.
- In-game UI is unmodified; no recorded chapter or branding graphics. Parent may add captions outside footage.
- Pet portraits look through the carrier from behind; animals and differing ear silhouettes are visible, not face closeups.
- Scent counts are after the first live pulse, not lifetime totals. Subsequent pulses can alert a previously missed bag, and the live bark HUD may name another bag while the earlier false-positive bag is inspected. Use assertions.json to distinguish these timings.
- Final render has only a software-driver VSync warning, no script errors or shutdown-leak warning. Headless preflight retains an ObjectDB shutdown-leak warning.
