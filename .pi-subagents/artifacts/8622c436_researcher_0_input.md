# Task for researcher

Research question for a design map (GitHub issue #12). Work as an autonomous researcher against PRIMARY sources.

QUESTION: Which procedural room-generation algorithm fits a top-down tiled, single-floor roguelike shooter built with seeded RNG in LÖVE 11.5? Compare candidate approaches — BSP tree, grid-of-rooms-with-connecting-corridors, cellular automata — against these needs: a COMPACT single floor, GUARANTEED connectivity, and a natural home for a single exit/boss room.

Deliverables:
1. Investigate against primary sources: the RogueBasin dungeon-generation literature and the grid-based-dungeon PCG canon (e.g. RogueBasin articles on BSP, "grid-based dungeon generation", "random dungeon", cellular automata pages). Consult the local primary reference first: read /home/encetroc/love2d_wayfinder_test/.agents/skills/love2d/REFERENCE.md for LÖVE-relevant gotchas (love.math.random / seeding, tile rendering).
2. Recommend ONE algorithm with a CONCRETE seeded generation recipe — deterministic given a seed — suitable for a compact single floor with perfect connectivity and a clear exit/boss-room slot. Include the algorithm steps in order.
3. Note any LÖVE-relevant gotchas (seeding love.math.randomNoise vs love.math.random, seed reproducibility across runs) and how connectivity/layout is verified.

RETURN (as your final output): a written finding in Markdown, with each claim cited to its source (URL/passage). Structure it so it can be saved verbatim as a repo note titled 'Room generation algorithm'. Include: recommended algorithm, why it wins vs the other two for THIS game, the concrete seeded recipe, and the LÖVE gotchas. Be concrete and decisive — this feeds a real build decision.

---
**Output:**
Write your findings to exactly this path: /home/encetroc/love2d_wayfinder_test/.pi-subagents/artifacts/outputs/8622c436/research.md
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