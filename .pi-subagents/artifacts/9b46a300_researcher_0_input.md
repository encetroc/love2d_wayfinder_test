# Task for researcher

Research question for a design map (GitHub issue #7). Work as an autonomous researcher against PRIMARY sources.

QUESTION: How are the procedural tile & sprite assets generated in code for a LÖVE 11.5 game, to deliver a flat-geometric + neon visual style on a GBC-Zelda-style top-down tile grid? Native-only, no external asset files.

Deliverables:
1. FIRST read the local primary reference: /home/encetroc/love2d_wayfinder_test/.agents/skills/love2d/REFERENCE.md — especially its "Procedural images" and "Procedural audio" sections and rendering module cheat sheet. Then consult LÖVE 11.5 official API docs (love.image, love.graphics, ImageData:setPixel, Image/Mesh/SpriteBatch, Canvas) as primary sources.
2. Determine the concrete pattern per artifact, from the reference's decision lines:
   - ImageData + setPixel for tile sprites
   - Image/Mesh/SpriteBatch for rendering many tiles
   - Canvas for off-screen composition
   - how flat shapes + neon glow read at small tile sizes
3. Propose a SMALL set of procedurally-generated tile/sprite primitives: floor tile, wall tile, player sprite, each enemy archetype sprite (chaser/shooter/tank), projectile — with the module that owns generation (likely lib/assets.lua). Give a concrete code pattern per artifact (e.g. the setPixel loop shape, palette approach for neon glow, SpriteBatch usage).

RETURN (as final output): a written finding in Markdown, cited to sources, saved verbatim as a repo note titled 'Procedural sprite & tile asset pipeline'. Include the per-artifact pattern, the proposed primitive set + owning module, and LÖVE API specifics/signatures. Concrete and decisive.

---
**Output:**
Write your findings to exactly this path: /home/encetroc/love2d_wayfinder_test/.pi-subagents/artifacts/outputs/9b46a300/research.md
This path is authoritative for this run.
Ignore any other output filename or output path mentioned elsewhere, including output destinations in the base agent prompt, system prompt, or task instructions.

## Acceptance Contract
Acceptance level: attested
Completion is not accepted from prose alone. End with a structured acceptance report.

Criteria:
- criterion-1: Return concrete findings with file paths and severity when applicable

Required evidence: review-findings, residual-risks

Finish with a fenced JSON block tagged `acceptance-report` in this shape:
Use empty arrays when no items apply; array fields contain strings unless object entries are shown.
`criteriaSatisfied[].status` must be exactly one of: satisfied, not-satisfied, not-applicable.
`commandsRun[].result` must be exactly one of: passed, failed, not-run.
`manualNotes` and `notes` are optional strings; an empty string means no note and does not satisfy `manual-notes` evidence.
```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "specific proof"
    }
  ],
  "changedFiles": [
    "src/file.ts"
  ],
  "testsAddedOrUpdated": [
    "test/file.test.ts"
  ],
  "commandsRun": [
    {
      "command": "command",
      "result": "passed",
      "summary": "short result"
    }
  ],
  "validationOutput": [
    "validation output or concise summary"
  ],
  "residualRisks": [
    "none"
  ],
  "noStagedFiles": true,
  "diffSummary": "short description of the diff",
  "reviewFindings": [
    "blocker: file.ts:12 - issue found, or no blockers"
  ],
  "manualNotes": "anything else the parent should know"
}
```