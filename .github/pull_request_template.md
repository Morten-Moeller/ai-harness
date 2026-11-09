<!-- Titel: <type>(<scope>): <Zusammenfassung> (<Spec-Nr>).
     Wird beim Squash-Merge zur Commit-Zeile. -->

## Spec

docs/specs/NNNN-<slug>.md

## Risiko

<!-- Block aus /risk: Stufe, Dateien, Gates, ADR, Begründung. -->

## ADR

<!-- docs/adr/NNNN-<slug>.md oder: keines nötig, weil <Bedingung aus harness/policies/adr.md
     trifft nicht zu>. -->

## Plan

<!-- Bei medium/high: der freigegebene Plan (G1). Bei low: die Schritte in drei Zeilen. -->

## Akzeptanzkriterien

| Kriterium | Nachweis |
|---|---|
| A1 | Test `<pfad>` / `/verify` im Browser |

## Gate-Änderung

<!-- Nur wenn der PR eine Prüfung abschaltet oder eine Gate-Datei ändert, eine Zeile
     "Gate-Änderung: <Grund>" am Zeilenanfang. Sonst den Abschnitt löschen. -->

## Checks

- [ ] `make check` grün
- [ ] Contracts regeneriert, nicht von Hand geändert
- [ ] Keine Prüfung, kein Test, kein Gate aufgeweicht
