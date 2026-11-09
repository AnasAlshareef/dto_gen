# Figma node → your conventions (recipe, not a converter)

You already have the Figma MCP wired in Claude Code (`mcp__figma__get_figma_data`,
`mcp__figma__download_figma_images`). Don't rebuild Locofy. Drive the MCP, then
map to your house patterns. This is the flow to paste/ask for.

## Steps

1. **Get the node.** From a Figma URL `.../file/<fileKey>/...?node-id=<id>`:
   `get_figma_data(fileKey, nodeId)` → layout, text, color, spacing, auto-layout.
2. **Pull real assets.** `download_figma_images` for icons/images the node uses —
   don't re-trace vectors by hand.
3. **Map to conventions, not raw CSS:**

   **React (LSP: Vite + Tailwind v4, RTL Arabic):**
   - Auto-layout → flex; gap/padding → Tailwind spacing tokens, not arbitrary px.
   - RTL: `dir="rtl"`, logical props (`ps-`/`pe-`, `start`/`end`), never `left`/`right`.
   - Tailwind v4 gotcha (your memory): nested `rgba()`/gradients in arbitrary
     values silently fail — use inline `style` for those.
   - Build from the node tree top-down; one component per Figma frame.

   **Flutter (Pengu etc.):**
   - Auto-layout → `Column`/`Row` + `SizedBox`/`Padding`; no magic numbers, pull
     a spacing constant.
   - Lists → `ListView.builder`/slivers, `.map` only for short static rows
     (your memory rule), never `for` in `children`.
   - Text → your theme text styles, not inline `TextStyle` per widget.

4. **Verify** against the frame at its real width before calling it done.

## Why no standalone converter

Figma Dev Mode, Locofy, builder.io Visual Copilot already do node→code well.
The only gap is *your* conventions (RTL Tailwind v4 / your Flutter patterns),
which is this mapping step — hours of recipe, not a multi-day engine to maintain.
