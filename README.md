# Zig JSON Schema Validator

A Zig implementation of the JSON schema validator.

## Supported Specs

- [ ] Draft 3
- [ ] Draft 4
- [ ] Draft 5
- [ ] Draft 6
- [ ] Draft 7
- [ ] Draft 2019-09
- [ ] Draft 2020-012

## Supported Validations (Draft 7)

- [x] additionalProperties
- [x] allOf
- [x] anyOf
- [x] boolean_schema
- [ ] const
- [ ] contains
- [ ] default
- [ ] definitions
- [ ] dependencies
- [ ] enum
- [ ] exclusiveMaximum
- [ ] exclusiveMinimum
- [ ] format
- [ ] id
- [ ] if-then-else
- [ ] infinite-loop-detection
- [ ] items
- [x] maximum
- [x] maxItems
- [ ] maxLength
- [ ] maxProperties
- [x] minimum
- [x] minItems
- [ ] minLength
- [ ] minProperties
- [x] multipleOf
- [ ] not
- [x] oneOf
- [ ] opt
- [ ] pattern
- [x] patternProperties
- [x] properties
- [ ] propertyNames
- [ ] ref
- [ ] refRemote
- [x] required
- [x] type
- [ ] uniqueItems
- [ ] unknownKeyword

## Pre-Commit

```shell
pip install pre-commit
pre-commit install
```
