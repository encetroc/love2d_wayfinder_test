# Task for researcher

Research question for a design map (GitHub issue #10). Work as an autonomous researcher against PRIMARY sources.

QUESTION: What is the procedural audio scope for a single-floor top-down tiled roguelike shooter in LÖVE 11.5 — which sfx and any music, all generated via SoundData synthesis? Native-only, no external audio files.

Deliverables:
1. FIRST read the local primary reference: /home/encetroc/love2d_wayfinder_test/.agents/skills/love2d/REFERENCE.md — especially its "Procedural audio (no asset files)" section. Then consult LÖVE 11.5 official API docs (love.sound, love.audio, newSoundData, newSource with "static", SoundData:setSample, waveform synthesis) as primary sources.
2. Decide the MINIMUM believable sfx set: shoot sfx, enemy-hit/death sfx, pickup sfx, hurt/player-death. Decide clearly whether floor ambience/music belongs in the destination or is CUT (if questionable, cut for scope — the map's standing preference is to cut questionable scope).
3. Confirm the SoundData synthesis + newSource("static") pattern concretely (e.g. how to build a short waveform sample in code), and confirm no external audio asset files are used.

RETURN (as final output): a written finding in Markdown, cited to sources, saved verbatim as a repo note titled 'Procedural audio scope'. Include the recommended sfx set, the cut decision on ambience/music with reasoning, and the concrete SoundData/newSource pattern with LÖVE API specifics. Concrete and decisive.

---
**Output:**
Write your findings to exactly this path: /home/encetroc/love2d_wayfinder_test/.pi-subagents/artifacts/outputs/027f7da7/research.md
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