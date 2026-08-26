# tool/

`generate_crop_catalog.py` writes `assets/content/crops_sr.json` and
`crops_en.json` from a single source, so the two languages cannot drift
structurally — same crops, same threats, same rules, only the text differs.

```
python3 tool/generate_crop_catalog.py
```

The generated files are committed and can be hand-edited; the tests in
`test/features/crops/crop_catalog_content_test.dart` enforce parity either way,
so an edit to one language that is not mirrored in the other fails the build.
Regenerating overwrites hand edits, so prefer editing the generator.
