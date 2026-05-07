# Product Direction Notes

## Current Positioning

Wherehouse should not compete head-on with wardrobe styling apps or generic inventory SaaS. The strongest positioning is a household item locator: users ask where something is, see its position chain, and make low-friction maintenance edits after the initial library exists.

## Main Product Insight

The core pain is cold start, not maintenance. Users may tolerate small ongoing actions such as add, move, mark used up, or delete, but they resist bootstrapping a whole home inventory from zero. Product work should distinguish:

- Bootstrap mode: build a usable initial inventory by container, with batch capture and later review.
- Maintenance mode: keep an existing inventory accurate through tiny lifecycle actions.

## Competitive Takeaways

Existing products such as Sortly, Homebox, Containd, Cratify, BoxQR, and StowQR mostly solve "after entry, search works." They are weaker on initial setup, household semantics, Chinese family scenarios, natural position chains, uncertainty review, and low-friction maintenance actions. QR labels are useful for boxes but should remain optional; over-reliance on QR adds visual and setup friction.

## Directional Bets

- Prefer container-first workflows over single-item-first workflows.
- Treat AI/VLM results as candidates, not authoritative inventory records.
- Use `Thing -> contained_in -> Thing` as the canonical location chain.
- Prioritize "find things" over "AI outfit recommendation"; wardrobe use cases are more credible as location and seasonal storage management than daily styling.
- A service or "human-assisted bootstrap" layer may be commercially stronger later, but the SaaS/App should first make container-level batch intake and maintenance excellent.

## Monetization Notes

A SiYuan-like model fits: local/free basics, one-time Pro unlock for power tools and BYOK, paid AI credits for users who do not want to manage keys, and optional cloud/family sync subscription only when server costs exist. Pro should not include unlimited platform-paid AI usage.
