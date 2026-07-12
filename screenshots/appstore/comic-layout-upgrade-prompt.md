# Comic Layout Upgrade Prompt

## Goal

Change the comic **layout only**, not the theme.

The current comic is being generated like a single illustrated obituary card per page: one large cinematic image, a top title block, and a bottom caption box. The new direction should feel closer to a proper sequential comic page, like the attached reference image: multiple panels, visible gutters, varied panel sizes, and clear story progression from panel to panel.

Use this file as a drop-in layout upgrade for your existing comic prompts.

---

# Global Layout Replacement Prompt

Replace the current `Composition:` section in each page prompt with the following:

```markdown
COMIC PAGE LAYOUT — IMPORTANT:
Do not compose this as a single poster, card, book cover, or one large hero illustration.

Compose the page as a proper sequential comic page, similar to a modern graphic novel page:
- 4 to 6 clear rectangular panels per page.
- Visible white/ivory gutters between panels.
- Varied panel sizes: two small panels on top, one wide middle panel, two bottom panels, or another balanced comic-page grid.
- Each panel must show a different story beat from the same moment, not repeated portraits.
- Use cinematic panel-to-panel storytelling: establishing shot → character action → reaction close-up → symbolic detail → emotional final beat.
- Maintain the same historical dark painterly obituary-comic theme, palette, character design, and mood.
- Keep the page vertical portrait.
- No large title card covering the artwork.
- No bottom caption box occupying a fixed third of the page.
- Leave small clean negative-space areas inside panels for captions/speech balloons to be added later.
- Speech balloons and caption boxes may appear as blank shapes only, with no readable text.
- Preserve clean reading order from top-left to bottom-right.
- Make the whole page feel like a real comic page, not a poster with text overlays.
```

---

# Text Control Replacement

Replace the current strict text ban with this version:

```markdown
TEXT CONTROL:
No readable text, no fake handwriting, no labels, no book titles, no signs, no captions rendered inside the art.
Blank speech balloons, blank narration boxes, and blank caption areas are allowed.
All final dialogue/captions will be added later in layout.
```

---

# Final Layout Check

Add this at the end of every page prompt:

```markdown
FINAL LAYOUT CHECK:
The output must clearly read as a sequential comic page with multiple panels and gutters.
If it looks like a single poster, single splash art, trading card, book cover, or obituary card, it has failed.
The theme stays dark historical obituary-comic; only the layout changes into a proper panelled comic page.
```

---

# Page-by-Page Layout Direction

## Page 1 — Intro / Obituary Hook

**Layout:** 5 panels.

```markdown
PAGE 1 PANEL PLAN:
Panel 1: Small close-up of a candle burning beside blank manuscript pages.
Panel 2: Close-up of older Cervantes’ tired eyes in shadow.
Panel 3: Wide central panel: Cervantes standing in the Madrid study, windmill shadow behind him.
Panel 4: Small detail panel: stiff left hand partly hidden under cloak.
Panel 5: Final bottom panel: blank pages, cracked lance, barred window fading into open sky.
```

**Purpose:**  
Open with mystery and legacy instead of a static poster portrait.

---

## Page 2 — Youth / Escape from Obscurity

**Layout:** 5 panels.

```markdown
PAGE 2 PANEL PLAN:
Panel 1: Modest family interior, young Cervantes gathering blank papers.
Panel 2: His hand tying a small travel bundle.
Panel 3: Wide panel: narrow Spanish street leading toward distant arches and ship masts.
Panel 4: Close-up of young Cervantes looking forward, ambitious but uncertain.
Panel 5: His silhouette walking away into dusk.
```

**Purpose:**  
Show departure, ambition, and movement toward danger.

---

## Page 3 — Lepanto

**Layout:** 6 panels.

```markdown
PAGE 3 PANEL PLAN:
Panel 1: Feverish Cervantes below deck, lit by lantern.
Panel 2: His hand gripping a ladder or rope, choosing to go above deck.
Panel 3: Wide battle panel: smoke, ropes, ships colliding, chaos without gore.
Panel 4: Close-up: impact or wound implied on chest and left arm.
Panel 5: His left hand hanging stiff, non-gory.
Panel 6: Quiet aftermath: Cervantes standing amid smoke, changed forever.
```

**Purpose:**  
Make the wound feel like a dramatic sequence, not just a single battle image.

---

## Page 4 — Captivity

**Layout:** 5 panels.

```markdown
PAGE 4 PANEL PLAN:
Panel 1: Ship attacked at sea, silhouettes only.
Panel 2: Bound captives arriving near Algiers arches.
Panel 3: Wide panel: barred courtyard, blue night shadows, other captives.
Panel 4: Cervantes hiding blank papers inside his cloak.
Panel 5: Close-up of chain on ground beside his stiff hand.
```

**Purpose:**  
Show captivity as a lived passage of time and endurance.

---

## Page 5 — Return Without Triumph

**Layout:** 5 panels.

```markdown
PAGE 5 PANEL PLAN:
Panel 1: Empty purse on desk.
Panel 2: Failed theatre mask beside blank papers.
Panel 3: Wide panel: Cervantes in cramped office, candlelight and barred window shadow.
Panel 4: Close-up of exhausted face, still alert.
Panel 5: Windmill silhouette outside the window, hinting at what will come.
```

**Purpose:**  
Turn failure into visual buildup for the later literary breakthrough.

---

## Page 6 — Don Quixote Emerges

**Layout:** 5 panels.

```markdown
PAGE 6 PANEL PLAN:
Panel 1: Cervantes watching blank pages swirl in candlelight.
Panel 2: A cracked lance appears in imagination.
Panel 3: Wide dreamlike panel: knight and companion riding toward windmills.
Panel 4: Close-up of Cervantes half in shadow, half lit by imagination.
Panel 5: Windmills and pages dissolving into moonlit dust.
```

**Purpose:**  
Make the literary invention feel magical, but still restrained and historical.

---

## Page 7 — Death / Modest End

**Layout:** 5 panels.

```markdown
PAGE 7 PANEL PLAN:
Panel 1: Rain on Madrid stone.
Panel 2: Candle in convent window.
Panel 3: Wide panel: simple unmarked grave-like slab, no text.
Panel 4: Blank pages blown across cobblestones.
Panel 5: Shadow of writer and knight overlapping, then fading.
```

**Purpose:**  
Keep the death page quiet, respectful, and symbolic.

---

## Page 8 — What Remains

**Layout:** 5 panels.

```markdown
PAGE 8 PANEL PLAN:
Panel 1: Candle nearly burned down.
Panel 2: Stiff glove resting beside blank pages.
Panel 3: Wide panel: chair, cracked lance, dawn through window.
Panel 4: Barred shadow fading into open sky.
Panel 5: Final symbolic panel: distant windmill dissolving into sunrise.
```

**Purpose:**  
End on legacy, not death.

---

# Full Reusable Page Prompt Template

Use this structure for each page:

```markdown
Generate TEXT-FREE vertical historical obituary-comic art for page [PAGE NUMBER] of an 8-page comic about Miguel de Cervantes Saavedra.

Character consistency:
Miguel de Cervantes appears as a 16th/17th-century Spanish man with olive skin, high forehead, dark-to-graying hair, short pointed beard and moustache, tired intelligent dark eyes, sober black Spanish clothing, and a visibly guarded/stiff left hand after Lepanto. Younger pages show a dark-haired version; later pages show graying beard and deeper lines.

Scene:
[Keep the original scene description here.]

PAGE [NUMBER] PANEL PLAN:
Panel 1: [Story beat 1]
Panel 2: [Story beat 2]
Panel 3: [Story beat 3]
Panel 4: [Story beat 4]
Panel 5: [Story beat 5]
Optional Panel 6: [Story beat 6, if needed]

Style:
Premium dark painterly graphic novel, cinematic obituary-comic style, somber memento-mori tone, old Spanish gold against indigo-black shadows, candlelight highlights, restrained texture, museum-quality illustration, clean anatomy, consistent face, dignified historical mood.

COMIC PAGE LAYOUT — IMPORTANT:
Do not compose this as a single poster, card, book cover, or one large hero illustration.

Compose the page as a proper sequential comic page, similar to a modern graphic novel page:
- 4 to 6 clear rectangular panels per page.
- Visible white/ivory gutters between panels.
- Varied panel sizes: two small panels on top, one wide middle panel, two bottom panels, or another balanced comic-page grid.
- Each panel must show a different story beat from the same moment, not repeated portraits.
- Use cinematic panel-to-panel storytelling: establishing shot → character action → reaction close-up → symbolic detail → emotional final beat.
- Maintain the same historical dark painterly obituary-comic theme, palette, character design, and mood.
- Keep the page vertical portrait.
- No large title card covering the artwork.
- No bottom caption box occupying a fixed third of the page.
- Leave small clean negative-space areas inside panels for captions/speech balloons to be added later.
- Speech balloons and caption boxes may appear as blank shapes only, with no readable text.
- Preserve clean reading order from top-left to bottom-right.
- Make the whole page feel like a real comic page, not a poster with text overlays.

TEXT CONTROL:
No readable text, no fake handwriting, no labels, no book titles, no signs, no captions rendered inside the art.
Blank speech balloons, blank narration boxes, and blank caption areas are allowed.
All final dialogue/captions will be added later in layout.

FINAL LAYOUT CHECK:
The output must clearly read as a sequential comic page with multiple panels and gutters.
If it looks like a single poster, single splash art, trading card, book cover, or obituary card, it has failed.
The theme stays dark historical obituary-comic; only the layout changes into a proper panelled comic page.
```

---

# Notes for Better Results

## What to Avoid

Avoid prompts like:

```markdown
cover-like portrait page
strong central figure
lower caption zone
bottom caption band
poster composition
title zone clear
one cinematic illustration
```

These phrases push the model back toward the current obituary-card layout.

## What to Use Instead

Use phrases like:

```markdown
sequential comic page
multiple clear panels
visible gutters
varied panel sizes
panel-to-panel storytelling
top-left to bottom-right reading order
establishing shot, action, reaction, symbolic detail
blank speech balloons allowed
blank narration boxes allowed
```

---

# Short Telegram-Friendly Version

```markdown
Change layout only, not theme. Generate each page as a real sequential comic page, not a poster/card. Use 4–6 rectangular panels with visible ivory gutters, varied panel sizes, and top-left to bottom-right reading order. Each panel should show a different story beat: establishing shot → action → reaction close-up → symbolic detail → emotional final beat. Keep the same dark historical obituary-comic style, palette, characters, and mood. No large title block, no fixed bottom caption box. Blank speech balloons/caption boxes are allowed, but no readable text. If the result looks like one splash illustration, book cover, trading card, or obituary card, it has failed.
```
