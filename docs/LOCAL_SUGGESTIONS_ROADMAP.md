# Local-First Suggestions Roadmap

Plan for making word suggestions smarter by learning from the user's own
typing — entirely on device. The keyboard keeps working without Full Access,
without any server, and without uploading typed text. This document is a
roadmap only; nothing here is implemented until its stage begins.

## Privacy Principles

These hold for every stage below:

- **No Full Access required** — the keyboard never asks for it during normal
  setup, and every learning feature works without it.
- **No network by default** — without Full Access, iOS itself denies the
  keyboard any network access; privacy is enforced by the OS, not by promise.
- **No server by default** — there is no server-side learning component.
- **No uploading typed text** — nothing the user types leaves the device.
- **No full sentence storage** — only individual words and word pairs
  (bigrams) are ever stored, never sentences or message text.
- **All normal learning stays on device** — learned data lives in the
  keyboard extension's own sandbox container and is deleted with the app.

Background: without Full Access a keyboard extension has no shared container
with its containing app, but it does have its own container it can write to
([Apple: Custom Keyboard](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html),
[Configuring open access](https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard)).
That is where all learned data lives. In secure (password) fields iOS
replaces custom keyboards with the system one, so passwords are never seen.

## Stage 1 — Local learned word frequency

- [x] Create `learned.sqlite` in the keyboard extension's own container
      (`Application Support`, WAL mode, schema version in a `meta` table)
- [x] Store individual learned words only — no sentences, no context text
- [x] Track per word: `word`, `count`, `picked` (times chosen from the
      suggestion bar), `last_used` timestamp
- [x] Learn when a word is completed (space / punctuation / return after it)
- [x] Learn with extra weight when a suggestion is selected from the bar
- [x] Merge learned words into the current prefix-based suggestions from
      `lezgi_words.sqlite`
- [x] Boost learned words in ranking; boost picked words above merely typed
      ones
- [x] Words are stored from the first use but appear in suggestions only
      after 3 confirmations (typed or picked) — a typo made once or twice
      never surfaces
- [x] Suggestions follow the capitalization context (sentence start, empty
      field, Shift, Caps Lock) — consistently for learned and dictionary words
- [x] Long-press on a learned suggestion offers to remove it from
      `learned.sqlite` via an inline confirmation row inside the suggestion
      bar. Dictionary suggestions are never deleted — if a word exists in
      both, only the learned record goes. (UIKit alerts must not be presented
      from a keyboard extension: the restricted environment kills the
      keyboard and iOS falls back to another one — first attempt used an
      alert and hit exactly that.)

### Known limitation — immediate send

If the user types a word and immediately taps the app's own **Send** button
(no space, punctuation, or return after the word), the keyboard never sees
the word being completed: extensions get no "will send" hook, and by the
time `textDidChange` fires the field is already empty. Sends triggered by
the return key are covered (the word is learned before the newline is
inserted). No fragile workaround is attempted — revisit if Apple ever adds
an API for this.

## Stage 2 — Cleanup / limits

- [ ] Prune old and rare learned words when caps are exceeded
- [ ] Decay counters over time (e.g., halve all counts when the total event
      counter passes a threshold) so stale habits fade out
- [ ] Enforce size limits for `learned.sqlite` (target: a few MB at most,
      hard cap on row counts)
- [ ] Do not learn emails, URLs, tokens with digits, or very short tokens
      (fewer than 2 characters)

## Stage 3 — Local bigrams

- [ ] Store previous word + current word pairs with counts
      (`prev`, `word`, `count`, `last_used`)
- [ ] Use bigrams to rank suggestions by the word before the cursor
      (taken from `documentContextBeforeInput`, which iOS already truncates
      to roughly the current sentence)
- [ ] Use bigrams only locally — same container, same deletion rules
- [ ] No full sentences stored — a bigram is two words and a counter,
      nothing more

## Stage 4 — Next-word suggestions

- [ ] When the prefix is empty right after a space, suggest likely next
      words instead of showing nothing
- [ ] Rank by bigrams for the previous word first, then fall back to
      recent/frequent learned words

## Stage 5 — Reset learned data

- [ ] Add a way to reset learned suggestions from inside the keyboard
      (learned data lives in the keyboard's sandbox, so the reset control
      must be in the keyboard itself — the containing app cannot reach it
      without Full Access)
- [ ] Document the privacy behavior clearly in the app and README: what is
      stored, where it lives, that deleting the app deletes it, and how to
      reset it manually

## Stage 6 — Optional future local improvements

- [ ] `UILexicon` integration — contact names and the user's text
      replacements appear in suggestions (available without Full Access)
- [ ] Ranking weight tuning (context vs. personal frequency vs. base
      dictionary)
- [ ] Better recency scoring (exponential decay on `last_used` instead of a
      simple boost)
- [ ] Local-only diagnostics if useful (e.g., suggestion acceptance rate
      kept on device, never transmitted)

## Stage 7 — Optional Full Access / improvement mode

**This is NOT required for the keyboard to work.** Future idea only — no
part of it may begin without researching Apple's privacy and App Store
requirements first.

- [ ] An optional, user-controlled setting for people who explicitly want to
      help improve the keyboard
- [ ] Strictly opt-in; the keyboard must fully work without it
- [ ] Do not request Full Access during normal setup
- [ ] Do not scare users with the Full Access prompt unless there is a
      clear, privacy-safe feature behind it
- [ ] Clearly explain what enabling it does and does not do
- [ ] Provide a way to turn it off
- [ ] Provide a way to delete/reset any learned data
- [ ] Any future network-based improvement must avoid full sentences and
      sensitive data (aggregated word statistics at most)
- [ ] Research Apple privacy / App Store Review requirements (privacy
      nutrition labels, data collection disclosure) before implementation
