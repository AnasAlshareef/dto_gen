# dto_gen

Generate `dart_mappable` DTO classes from a JSON API sample, in our conventions
(`@MappableClass()` + `with …Mappable`, `part`, const ctor, `@MappableField(key:)`
only when the JSON key isn't already camelCase, nested objects → their own classes).

No dependencies — pure Dart.

## Install as a global `dto_gen` command

```sh
dart compile exe bin/dto_gen.dart -o ~/.pub-cache/bin/dto_gen
```

`~/.pub-cache/bin` is already on PATH. It's a compiled binary, so after
editing `bin/dto_gen.dart` re-run that line to pick up the change.
(Don't use `dart pub global activate` here — a path package re-resolves on
every run and prints "Resolving dependencies" to stdout, which corrupts a
redirected `.dart` file.)

## Use

```sh
# from a file, print to stdout
dart run bin/dto_gen.dart sample.json SavedPlace

# write the file (then run build_runner for the .mapper.dart)
dart run bin/dto_gen.dart sample.json SavedPlace lib/.../saved_place.dart

# pipe a response in
curl -s https://api/.../addresses | jq '.data' | dart run bin/dto_gen.dart - SavedPlace

# self-check
dart run bin/dto_gen.dart --selftest
```

Pass a JSON array and it generates from the first element.

## What it does / doesn't

- int vs double from the sample value (`5` → `int`, `5.0` → `double`).
- A **null** value → nullable field. A **present** value → `required`, non-null.
  A single sample can't show which fields the API omits, so relax to nullable
  by hand where needed.
- Empty list → `List<dynamic>`; relax the element type once you have a sample row.
- Naive de-pluralize for nested class names (`items` → `Item`); fix `categories`
  / `boxes` style plurals by hand.
- It writes the annotated class only. Run `build_runner` to get `.mapper.dart`.

## Figma → code

See `FIGMA_RECIPE.md` — a thin flow over the Figma MCP, not a converter.
