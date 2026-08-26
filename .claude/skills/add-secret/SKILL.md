---
name: add-secret
description: Add configuration key/value pairs to Secrets.xcconfig, surface them in each app target's Info.plist, and expose them through the shared AppEnvironment util so any layer can read them. Use for "/add-secret KEY=value" or "the app needs an analytics host URL". Refuses to write a live credential — those you paste in by hand.
model: inherit
---

# /add-secret `[--app <A>] [KEY=value ...]`

Adds environment configuration the way §8.3 requires it: never a literal in
Swift, never committed, and readable from one typed place instead of a
`Bundle.main` call scattered through a feature.

## Precondition

Check for `ios-skeleton.config.json` first. Missing → refuse: *"This project
hasn't been initialized yet — run `/start` first."*

No tier refusal: this works at T1, T2 and T3 — only the destination of the
`AppEnvironment` file changes.

## Never send a real credential through this Skill

**You are an AI agent. A value the developer types into a prompt is in the
transcript, in the model's context and in every log along the way, and stays
there long after the key is rotated.** So:

- If a value looks like a live credential — a vendor-prefixed token (`sk-`,
  `ghp_`, `AKIA`, `eyJ`, `-----BEGIN`, …), a long high-entropy blob, a 32+ digit
  hex string, or anything whose **key name** contains `KEY`, `SECRET`, `TOKEN`, `PASSWORD`, `PASSWD`, `CREDENTIAL(S)`, `PRIVATE`, `CERT`, `SIGNING`, `DSN`, `AUTH`, `APIKEY` or `PAT` and whose value isn't
  an obvious placeholder — **do not write the value**. `Scripts/add_secret.sh`
  enforces this independently of your judgement, and will hold it back even if
  you pass it. Do all the wiring, leave the key commented out in both files, and
  tell the developer to open the gitignored `Secrets.xcconfig` and paste it in.
- **The name rule catches some non-secrets, and that is the intended trade.**
  `AUTH_BASE_URL=https:/$()/auth.example.com` is held back even though a base
  URL isn't a credential — because a webhook URL under the same name would be.
  When that happens, say plainly that the hold-back was triggered by the key's
  *name*, and let the developer either rename the key or uncomment the line
  themselves. Don't work around the script by editing the files by hand.
- Never echo a held-back value back to the developer, into `TODO.md`, or into a
  commit message.
- Non-secret configuration — hosts, feature-flag endpoints, bundle-visible IDs,
  timeouts — is exactly what this Skill is for. The refusal is about live
  credentials, not about configuration in general.

## Steps

1. **Collect the pairs.** With no arguments, ask for them as `KEY=value` lines
   and batch-confirm before writing anything (the `/new-feature` pattern):
   the key names in SCREAMING_SNAKE_CASE, the value for each, the Swift type
   each should be exposed as (`String`/`URL`/`Bool`/`Int`), and — with more than
   one app — which apps get it. State what you're about to write and get one
   confirmation, rather than discovering an objection after four files changed.
2. **Write the two config files:**
   ```
   Scripts/add_secret.sh KEY=value [KEY=value ...]      # or --no-value KEY
   ```
   The script owns this half: the real value into `Secrets.xcconfig`, a
   placeholder into the committed `Secrets.xcconfig.example`, the `$()` comment
   escape applied to any value containing `//`, duplicate keys refused, and the
   credential hold-back above. Never hand-edit those two files instead — the
   script is what keeps them in the parity `Scripts/check_secrets.sh` enforces
   on every commit.
3. **Surface each key in every relevant app target's `Info.plist`** as
   `<PlistKey> = $(KEY)` — `API_BASE_URL` → `APIBaseURL` is the shipped
   precedent for the naming. **Without this the key is invisible to Swift**: an
   xcconfig assignment is a build setting, not a runtime value. Configuration
   files and `Info.plist`s are per target (§4.5), so at T3 this repeats for each
   app that needs the key. A shared module can't declare one — if the reading
   code lives in a shared module, every app that ships it needs the entry, and
   say so rather than picking one app silently.
4. **Render `AppEnvironment` only if it doesn't exist yet.** On a networked
   project `/start` §1.7c already rendered it — find that file and append to it;
   don't create a second one. It's missing only on a project that started with no
   keys at all (`networking: none`), and then you render it from
   `Scripts/templates/config/AppEnvironment.swift.template`, substituting
   `__APP_NAME__` and dropping the `__IF_NETWORKING__` block (there is no
   `API_BASE_URL` on such a project). Destination is Core, at the tier-correct
   path — the same table `/start` §1.7a/§1.7c use:

   | Tier | Destination |
   |---|---|
   | T1 | `<app.path>/Core/Configuration/AppEnvironment.swift` |
   | T2 | `Packages/Core/Sources/Core/Configuration/AppEnvironment.swift` |
   | T3 | the `role: "core"` module's `Sources/<Name>/Configuration/`, or `sharedModuleName`'s `Sources/Core/Configuration/` if no core module is declared |

   It goes in the shared module, not the app, precisely so a feature in any
   module can read configuration without the app injecting it — `Bundle.main`
   resolves to the app bundle even from inside a package or framework.
5. **Add one typed accessor per key** at the
   `// MARK: add-secret-insertion-point` marker — leave the marker in place, it
   is this Skill's, the way `new-feature-model-insertion-point` is
   `new_feature.sh`'s. Use the reader matching the confirmed type:
   ```swift
   /// `ANALYTICS_HOST` — Secrets.xcconfig → Info.plist `AnalyticsHost`.
   public var analyticsHost: URL { url("AnalyticsHost", xcconfig: "ANALYTICS_HOST") }
   ```
   Both key names are passed on purpose: the readers trap with messages that
   name the plist key *and* the build setting behind it, which is what makes a
   launch failure point at one file instead of two.
   For a held-back credential, still write the accessor: the wiring should be
   complete and the app should fail loudly at launch until the value is pasted
   in — that is the designed behaviour, not a gap.
6. **Regenerate and verify.** `xcodegen generate` (or `tuist generate`) for each
   spec you touched, plus `Scripts/generate_workspace.sh` at T3. Then run
   `Scripts/check_secrets.sh` and report its result, and build.
7. **Record it.** Append a line to `docs/PROJECT_MAP.md` under configuration:
   the key, what reads it, and which apps carry the plist entry. If a value was
   held back, add a `TODO.md` entry naming the key — never the value.

## What NOT to do

- **Never pass a real API key, token, password, certificate or connection
  string through this Skill**, and never talk a developer into pasting one into
  the chat "just to save a step". The mechanism above exists because the polite
  version of this warning gets ignored.
- Don't add a key to `Secrets.xcconfig` alone. A key with no `Info.plist` entry
  and no accessor is invisible to the app and drifts out of the example on the
  next commit — `check_secrets.sh` will fail it.
- Don't put the real value in `Secrets.xcconfig.example`. That file is committed
  and records only which keys exist.
- Don't read `Bundle.main.object(forInfoDictionaryKey:)` anywhere else once
  `AppEnvironment` exists — one reader, one failure message.
- Don't move `API_BASE_URL` into `AppEnvironment` as a side effect. It keeps its
  composition-root path into `RequestBuilder` (§3.7); consolidating the two is a
  deliberate, separate change.
- Don't treat a value as safe because it's "only staging". Staging credentials
  are credentials.
