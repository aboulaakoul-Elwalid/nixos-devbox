---
name: excalidraw
description: Generate .excalidraw diagrams into docs/diagrams/.
---

# Excalidraw Diagram Generation Skill

> Generate .excalidraw files for architecture diagrams, flowcharts, sequence diagrams, wireframes, and ER diagrams.

## Overview

This skill enables you to create Excalidraw diagrams programmatically. Excalidraw files are JSON that can be opened at https://excalidraw.com or in VS Code with the Excalidraw extension.

## Output Location

Save all diagrams to: `docs/diagrams/*.excalidraw`

Create the directory if it doesn't exist:
```bash
mkdir -p docs/diagrams
```

## File Structure

Every .excalidraw file must have this structure:

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "https://excalidraw.com",
  "elements": [ /* array of elements */ ],
  "appState": {
    "gridSize": 20,
    "viewBackgroundColor": "#ffffff"
  },
  "files": {}
}
```

## Element Types

### Base Properties (All Elements)

Every element needs these properties:

```json
{
  "id": "unique-id-string",
  "type": "rectangle",
  "x": 100,
  "y": 100,
  "width": 150,
  "height": 80,
  "angle": 0,
  "strokeColor": "#1e1e1e",
  "backgroundColor": "#a5d8ff",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 1,
  "opacity": 100,
  "groupIds": [],
  "frameId": null,
  "index": "a0",
  "roundness": { "type": 3 },
  "seed": 1234567890,
  "version": 1,
  "versionNonce": 987654321,
  "isDeleted": false,
  "boundElements": null,
  "updated": 1705000000000,
  "link": null,
  "locked": false
}
```

### Shape Types

| Type | Use For |
|------|---------|
| `rectangle` | Boxes, containers, services |
| `ellipse` | States, start/end nodes |
| `diamond` | Decision points |

### Text Element

Add `text` type elements for labels:

```json
{
  "type": "text",
  "text": "Service Name",
  "fontSize": 20,
  "fontFamily": 1,
  "textAlign": "center",
  "verticalAlign": "middle",
  "containerId": "box-id-if-inside-shape",
  "originalText": "Service Name",
  "autoResize": true,
  "lineHeight": 1.25
}
```

**Font families:**
- `1` = Virgil (hand-drawn)
- `2` = Helvetica (clean)
- `3` = Cascadia (code)

### Arrow Element

```json
{
  "type": "arrow",
  "points": [[0, 0], [200, 0]],
  "startBinding": {
    "elementId": "source-box-id",
    "fixedPoint": [1, 0.5],
    "mode": "orbit"
  },
  "endBinding": {
    "elementId": "target-box-id", 
    "fixedPoint": [0, 0.5],
    "mode": "orbit"
  },
  "startArrowhead": null,
  "endArrowhead": "arrow",
  "elbowed": false
}
```

**Binding fixedPoint coordinates:**
- `[0, 0.5]` = left center
- `[1, 0.5]` = right center
- `[0.5, 0]` = top center
- `[0.5, 1]` = bottom center

**Arrowhead types:**
- `"arrow"` - Standard arrow
- `"bar"` - Vertical bar
- `"triangle"` - Filled triangle
- `"diamond"` - Diamond shape
- `"crowfoot_one"` / `"crowfoot_many"` - ER notation

### Line Element

Same as arrow but `type: "line"` and no arrowheads.

## Binding Arrows to Shapes

When an arrow connects to shapes, BOTH must reference each other:

1. **Arrow** has `startBinding` and `endBinding` pointing to shape IDs
2. **Shapes** have `boundElements` array listing the arrow:

```json
{
  "id": "box1",
  "type": "rectangle",
  "boundElements": [
    { "id": "arrow1", "type": "arrow" }
  ]
}
```

## Color Palette

Use these colors for consistency:

| Color | Hex | Use For |
|-------|-----|---------|
| Blue | `#a5d8ff` | Primary components |
| Green | `#b2f2bb` | Success, databases |
| Yellow | `#ffec99` | Warnings, caches |
| Red | `#ffc9c9` | Errors, critical |
| Purple | `#d0bfff` | External services |
| Gray | `#e9ecef` | Infrastructure |
| Orange | `#ffd8a8` | Queues, async |

## ID Generation

Generate unique IDs using this pattern:
- `box-{name}` for rectangles
- `arrow-{source}-{target}` for arrows
- `text-{parent}` for text labels
- `ellipse-{name}` for ellipses

## Diagram Patterns

### Architecture Diagram

Layout: Left-to-right flow with services as boxes, arrows showing data flow.

```
[Client] --> [API Gateway] --> [Service A] --> [Database]
                           --> [Service B] --> [Cache]
```

- Use rectangles for services
- Use arrows for data flow
- Add text labels inside or below boxes
- Group related services with similar colors
- Vertical spacing: 120px between rows
- Horizontal spacing: 200px between columns

### Flowchart

Layout: Top-to-bottom with decision diamonds.

```
    [Start]
       |
    [Process]
       |
    <Decision>
    /        \
  Yes        No
   |          |
[Action]  [Action]
   \          /
    [End]
```

- Use ellipses for start/end
- Use rectangles for processes
- Use diamonds for decisions
- Arrows with "Yes"/"No" labels

### Sequence Diagram

Layout: Vertical lifelines with horizontal arrows.

```
[Actor A]     [Actor B]     [Actor C]
    |             |             |
    |--- msg ---->|             |
    |             |--- msg ---->|
    |             |<--- resp ---|
    |<--- resp ---|             |
```

- Rectangles at top for actors
- Vertical dashed lines as lifelines
- Horizontal arrows for messages
- Add text labels on arrows

### Wireframe

Layout: Nested rectangles representing UI components.

- Use rectangles with light gray backgrounds
- Add text for labels/content
- Use dashed strokes for placeholder areas

### ER Diagram

Layout: Tables as rectangles with relationship arrows.

- Use rectangles for entities
- Text inside for attributes
- Use crowfoot arrowheads for relationships:
  - `crowfoot_one` = exactly one
  - `crowfoot_many` = many
  - `crowfoot_one_or_many` = one or more

## Generation Steps

1. **Understand the request** - What type of diagram? What components?
2. **Plan layout** - Sketch positions mentally (grid-based, 100px increments)
3. **Create shapes first** - All boxes, ellipses, diamonds
4. **Add text labels** - Inside or near shapes
5. **Add arrows** - Connect shapes with proper bindings
6. **Update boundElements** - Ensure shapes reference their arrows
7. **Write file** - Save to `docs/diagrams/{name}.excalidraw`

## Validation Checklist

Before saving, verify:
- [ ] All elements have unique IDs
- [ ] All elements have required properties (seed, version, etc.)
- [ ] Arrows have proper startBinding/endBinding
- [ ] Shapes with arrows have boundElements array
- [ ] Text inside shapes has containerId set
- [ ] JSON is valid (no trailing commas)

## Example: Simple Architecture

Request: "Auth service architecture"

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "https://excalidraw.com",
  "elements": [
    {
      "id": "box-client",
      "type": "rectangle",
      "x": 50,
      "y": 100,
      "width": 120,
      "height": 60,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#e9ecef",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 1,
      "opacity": 100,
      "angle": 0,
      "groupIds": [],
      "frameId": null,
      "index": "a0",
      "roundness": { "type": 3 },
      "seed": 111111111,
      "version": 1,
      "versionNonce": 222222222,
      "isDeleted": false,
      "boundElements": [
        { "id": "text-client", "type": "text" },
        { "id": "arrow-client-auth", "type": "arrow" }
      ],
      "updated": 1705000000000,
      "link": null,
      "locked": false
    },
    {
      "id": "text-client",
      "type": "text",
      "x": 80,
      "y": 115,
      "width": 60,
      "height": 25,
      "text": "Client",
      "fontSize": 20,
      "fontFamily": 1,
      "textAlign": "center",
      "verticalAlign": "middle",
      "containerId": "box-client",
      "originalText": "Client",
      "autoResize": true,
      "lineHeight": 1.25,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 1,
      "opacity": 100,
      "angle": 0,
      "groupIds": [],
      "frameId": null,
      "index": "a1",
      "roundness": null,
      "seed": 333333333,
      "version": 1,
      "versionNonce": 444444444,
      "isDeleted": false,
      "boundElements": null,
      "updated": 1705000000000,
      "link": null,
      "locked": false
    },
    {
      "id": "box-auth",
      "type": "rectangle",
      "x": 300,
      "y": 100,
      "width": 140,
      "height": 60,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#a5d8ff",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 1,
      "opacity": 100,
      "angle": 0,
      "groupIds": [],
      "frameId": null,
      "index": "a2",
      "roundness": { "type": 3 },
      "seed": 555555555,
      "version": 1,
      "versionNonce": 666666666,
      "isDeleted": false,
      "boundElements": [
        { "id": "text-auth", "type": "text" },
        { "id": "arrow-client-auth", "type": "arrow" },
        { "id": "arrow-auth-db", "type": "arrow" }
      ],
      "updated": 1705000000000,
      "link": null,
      "locked": false
    },
    {
      "id": "text-auth",
      "type": "text",
      "x": 320,
      "y": 115,
      "width": 100,
      "height": 25,
      "text": "Auth Service",
      "fontSize": 20,
      "fontFamily": 1,
      "textAlign": "center",
      "verticalAlign": "middle",
      "containerId": "box-auth",
      "originalText": "Auth Service",
      "autoResize": true,
      "lineHeight": 1.25,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 1,
      "opacity": 100,
      "angle": 0,
      "groupIds": [],
      "frameId": null,
      "index": "a3",
      "roundness": null,
      "seed": 777777777,
      "version": 1,
      "versionNonce": 888888888,
      "isDeleted": false,
      "boundElements": null,
      "updated": 1705000000000,
      "link": null,
      "locked": false
    },
    {
      "id": "box-db",
      "type": "rectangle",
      "x": 550,
      "y": 100,
      "width": 120,
      "height": 60,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#b2f2bb",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 1,
      "opacity": 100,
      "angle": 0,
      "groupIds": [],
      "frameId": null,
      "index": "a4",
      "roundness": { "type": 3 },
      "seed": 999999999,
      "version": 1,
      "versionNonce": 101010101,
      "isDeleted": false,
      "boundElements": [
        { "id": "text-db", "type": "text" },
        { "id": "arrow-auth-db", "type": "arrow" }
      ],
      "updated": 1705000000000,
      "link": null,
      "locked": false
    },
    {
      "id": "text-db",
      "type": "text",
      "x": 570,
      "y": 115,
      "width": 80,
      "height": 25,
      "text": "Users DB",
      "fontSize": 20,
      "fontFamily": 1,
      "textAlign": "center",
      "verticalAlign": "middle",
      "containerId": "box-db",
      "originalText": "Users DB",
      "autoResize": true,
      "lineHeight": 1.25,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 1,
      "opacity": 100,
      "angle": 0,
      "groupIds": [],
      "frameId": null,
      "index": "a5",
      "roundness": null,
      "seed": 121212121,
      "version": 1,
      "versionNonce": 131313131,
      "isDeleted": false,
      "boundElements": null,
      "updated": 1705000000000,
      "link": null,
      "locked": false
    },
    {
      "id": "arrow-client-auth",
      "type": "arrow",
      "x": 170,
      "y": 130,
      "width": 130,
      "height": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 1,
      "opacity": 100,
      "angle": 0,
      "groupIds": [],
      "frameId": null,
      "index": "a6",
      "roundness": { "type": 2 },
      "seed": 141414141,
      "version": 1,
      "versionNonce": 151515151,
      "isDeleted": false,
      "boundElements": null,
      "updated": 1705000000000,
      "link": null,
      "locked": false,
      "points": [[0, 0], [130, 0]],
      "startBinding": {
        "elementId": "box-client",
        "fixedPoint": [1, 0.5],
        "mode": "orbit"
      },
      "endBinding": {
        "elementId": "box-auth",
        "fixedPoint": [0, 0.5],
        "mode": "orbit"
      },
      "startArrowhead": null,
      "endArrowhead": "arrow",
      "elbowed": false
    },
    {
      "id": "arrow-auth-db",
      "type": "arrow",
      "x": 440,
      "y": 130,
      "width": 110,
      "height": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 1,
      "opacity": 100,
      "angle": 0,
      "groupIds": [],
      "frameId": null,
      "index": "a7",
      "roundness": { "type": 2 },
      "seed": 161616161,
      "version": 1,
      "versionNonce": 171717171,
      "isDeleted": false,
      "boundElements": null,
      "updated": 1705000000000,
      "link": null,
      "locked": false,
      "points": [[0, 0], [110, 0]],
      "startBinding": {
        "elementId": "box-auth",
        "fixedPoint": [1, 0.5],
        "mode": "orbit"
      },
      "endBinding": {
        "elementId": "box-db",
        "fixedPoint": [0, 0.5],
        "mode": "orbit"
      },
      "startArrowhead": null,
      "endArrowhead": "arrow",
      "elbowed": false
    }
  ],
  "appState": {
    "gridSize": 20,
    "viewBackgroundColor": "#ffffff"
  },
  "files": {}
}
```

## Tips

1. **Start simple** - Get the basic shapes right before adding complexity
2. **Use grid alignment** - Position at multiples of 20 for clean layouts
3. **Consistent spacing** - 150-200px horizontal, 100-120px vertical
4. **Group by color** - Related components share background colors
5. **Label everything** - Every box should have descriptive text
