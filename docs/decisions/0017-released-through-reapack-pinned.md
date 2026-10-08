# 0017 - Released through ReaPack, pinned to commits

As in the sister repos: `index.xml` lists the six files as one package, each
pinned to the commit that was tested, so an installed version can never
change underneath anyone. A release is a commit of the code, then a new
`<version>` block pointing at it; an existing block is never edited.

Two things to keep: the package is keyed by the name `DAW Battle Pass.lua`,
so the script is never renamed; and a release's pull request is merged, not
squashed, so the pinned commit is on `main`.
