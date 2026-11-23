## 1. Specification

- [x] 1.1 Distill every ADR and BEP in force into requirements of the capabilities this change adds; verify with `openspec validate adopt-openspec --strict`
- [x] 1.2 Keep one or two lines of reason per record in design.md; verify every record id appears there or in the list of records that contributed nothing

## 2. Readers of the records

- [x] 2.1 Retire the record ids from the id links of the site and the PDFs; verify with `bun test scripts` and the suites of `packages/www`
- [x] 2.2 Drop the tests and CI steps that read records; verify `rg 'records/(adr|bep)'` finds no reader outside openspec/
- [x] 2.3 Point code, tests, pages and agent instructions at requirements; verify `rg '(ADR|BEP)-[0-9]{4}'` finds only the journal, this change and the files of the reviewed-interface guard
- [x] 2.4 Delete `records/adr/` and `records/bep/`; verify `check` and `check-all` pass

## Workflow follow-up

- Archive this change so its requirements land in `openspec/specs/`.
