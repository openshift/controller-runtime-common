## controller-runtime-common

A common place for controller-runtime utils, packages and shared code.
Anything introduced here must have concrete use-cases in at least two separate openshift repos and be of some reasonable complexity. Let's keep the bar high.

This repo MUST:
- avoid circular dependencies above all.
This repo SHOULD:
- have as few external dependencies as possible aside, especially avoid ones that migth end up conflicting with controller-runtime dependencies.
