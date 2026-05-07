# Regenerating `src/Types.mo`

How to update `src/Types.mo` when `did/ic.did` changes upstream.

Assumes `didc` supports `--target mo` with `Float32` (≥ 0.6.x).

## TL;DR

```bash
curl -fsSL -o did/ic.did \
  https://raw.githubusercontent.com/dfinity/portal/master/docs/references/_attachments/ic.did
didc bind --target mo did/ic.did > src/Types.mo
mops test                                    # builds + runs tests
git diff src/Types.mo                        # classify the change (see step 4)
```

Then decide the semver bump (below), update `mops.toml` + `CHANGELOG.md`, commit, PR.

## Steps

### 1. Refresh `did/ic.did`

```bash
curl -fsSL -o did/ic.did \
  https://raw.githubusercontent.com/dfinity/portal/master/docs/references/_attachments/ic.did
git diff did/ic.did
```

If the diff is empty, you're done.

### 2. Regenerate `src/Types.mo`

```bash
didc bind --target mo did/ic.did > src/Types.mo
```

### 3. Type-check + tests

```bash
mops install
mops test
```

If type-check fails, the upstream `.did` likely uses a Candid feature `moc` can't translate (service constructors → `M0153`/`M0162`). File an upstream issue and revert.

### 4. Decide the semver bump

`Types.mo` is the public surface — diff it against the previous version and classify the change:

```bash
git diff src/Types.mo
```

| Change | Bump |
|---|---|
| Removed methods, removed/renamed fields, narrowed input variants, broadened output variants | major |
| New methods, new fields (output records), new input variant cases, new types | minor |
| No `Types.mo` diff (e.g. `did/ic.did` comments only) | patch (or skip) |

> TODO: automate the breaking-change classification. `didc check` on the `.did` is too lax (misses Motoko-only breakages); a Motoko-aware diff on `Types.mo` is what we actually want.

### 5. Update `mops.toml` and `CHANGELOG.md`

Bump `[package].version`. Add a `## X.Y.Z` section listing changes (mirror the breaking-vs-additive split from `CHANGELOG.md`'s 4.0.0 entry).

### 6. Commit and open a PR

Standard flow. CI runs `mops test`.

### 7. Publish

After merge:

```bash
mops publish
```

## Notes

- `Types.mo` carries a `// This is a generated Motoko binding.` header — leave it. Don't hand-edit `Types.mo`; if you need to add helpers, put them in `src/lib.mo` or a new sibling module.
- The `import { ic } "mo:ic"; import IC "mo:ic/Types";` consumer pattern is stable across regenerations — don't change it casually.
