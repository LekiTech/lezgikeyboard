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

### Immediate send (mostly covered)

If the user types a word and immediately taps the app's own **Send** button
(no space, punctuation, or return after the word), extensions get no "will
send" hook — but messengers clear the field after sending, and that
host-driven clear is observable: `textDidChange` fires with a completely
empty document while the locally tracked composed word is still non-empty,
which commits the word (see CODEBASE_OVERVIEW.md, "Immediate send").
Return-key sends were always covered. Remaining gap: hosts that do not
clear the field on send (e.g. a closing mail composer) still give no
signal, and no fragile workaround is attempted for them.

## Stage 2 — Cleanup / limits

- [x] Prune old and rare learned words when caps are exceeded
- [x] Decay counters over time (e.g., halve all counts when the total event
      counter passes a threshold) so stale habits fade out
- [x] Enforce size limits for `learned.sqlite` (target: a few MB at most,
      hard cap on row counts)
- [x] Do not learn emails, URLs, tokens with digits, or very short tokens
      (fewer than 2 characters)

## Stage 3 — Local bigrams

- [x] Store previous word + current word pairs with counts
      (`prev`, `word`, `count`, `last_used`)
- [x] Use bigrams to rank suggestions by the word before the cursor
      (taken from `documentContextBeforeInput`, which iOS already truncates
      to roughly the current sentence)
- [x] Use bigrams only locally — same container, same deletion rules
- [x] No full sentences stored — a bigram is two words and a counter,
      nothing more

## Stage 4 — Next-word suggestions

- [x] When the prefix is empty right after a space, suggest likely next
      words instead of showing nothing
- [x] Rank by bigrams for the previous word first; when there is no last
      word or no confident pairs (a pair must be seen at least twice), the
      bar keeps the random dictionary fallback

## Stage 5 — Reset learned data

- [x] Add a way to reset learned suggestions from inside the keyboard
      (learned data lives in the keyboard's sandbox, so the reset control
      must be in the keyboard itself — the containing app cannot reach it
      without Full Access). Implemented as a gear icon on the idle
      suggestion bar (visible only when random fallback words are shown)
      that opens a two-step inline Lezgi confirmation: the first «Чӏурун»
      only advances to a stronger "are you sure" step with mirrored button
      order (a hasty double-tap lands on cancel), and only the explicit
      «Эхь» wipes learned words and bigrams and refreshes the bar
      immediately
- [x] Document the privacy behavior clearly in the app and README: what is
      stored, where it lives, that deleting the app deletes it, and how to
      reset it manually (README keyboard section, the app's privacy feature
      card, and docs/CODEBASE_OVERVIEW.md)

## Stage 6 — Optional future local improvements

- [ ] `UILexicon` integration — **postponed, research-only.** Although it
      is available without Full Access, it is likely a poor default fit for
      a Lezgi Cyrillic keyboard: contact names and text replacements are
      often English/Russian/other languages and would pollute Lezgi
      suggestions. If ever revisited, it needs separate research and must
      be optional (off by default), not a default behavior
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
