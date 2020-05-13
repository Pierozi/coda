let JobSpec = ../../Lib/JobSpec.dhall

in
JobSpec::{
  dirtyWhen = "^\\.buildkite/src/Jobs/ReformatOCaml|^src/app/reformat",
  name = "ReformatOCaml"
}
