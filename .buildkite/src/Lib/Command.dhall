-- Commands are the individual command steps that CI runs

let Prelude = ../External/Prelude.dhall
let Map = Prelude.Map

let Docker = ./Docker.dhall
let Size = ./Size.dhall

let Shared =
    { Type =
        { command : List Text
        , label : Text
        , key : Text
        }
    , default = {=}
    }

-- The result type wraps our containers in optionals so that they are omitted
-- from the rendered yaml if they are empty.
let Result =
  { Type = Shared.Type //\\
    { agents : Optional (Map.Type Text Text)
    , depends_on : Optional (List Text)
    , plugins : Map.Type Text Docker.Type
    }
  , default = Shared.default /\ {
      depends_on = None (List Text)
    }
  }

-- Everything here is taken directly from the buildkite Command documentation
-- https://buildkite.com/docs/pipelines/command-step#command-step-attributes
-- except "target" replaces "agents"
--
-- Target is our explicit union of large or small instances. As we build more
-- complicated targeting rules we can replace this abstraction with something
-- more powerful.
let Config =
    let Typ = Shared.Type //\\
        { target : Size
        , depends_on : List Result.Type
        , docker : Docker.Config.Type
        }
    let upcast : Typ -> Shared.Type =
      \(c : Typ) -> Shared::{
        command = c.command,
        label = c.label,
        key = c.key
      }
    in
    { Type = Typ
    , default = Shared.default /\ {
        depends_on = [] : List Result.Type
      }
    , upcast = upcast
    }

in

let targetToAgent = \(target : Size) ->
  merge { Large = toMap { size = "large" },
          Small = toMap { size = "small" }
        }
        target

let build : Config.Type -> Result.Type = \(c : Config.Type) ->
  Config.upcast c // {
    depends_on =
      let depends_on_key =
        Prelude.List.map
          Result.Type
          Text
          (\(r : Result.Type) -> r.key)
          c.depends_on
      in
      if Prelude.List.null Text depends_on_key then None (List Text) else Some depends_on_key,
    agents =
      let agents = targetToAgent c.target in
      if Prelude.List.null (Map.Entry Text Text) agents then None (Map.Type Text Text) else Some agents,
    plugins =
      toMap { `docker#v3.5.0` = Docker.build c.docker }
  }

in {Config = Config, build = build} /\ Result

