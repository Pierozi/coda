[%%import
"/src/config.mlh"]

open Core_kernel
open Coda_base

[%%ifdef
consensus_mechanism]

open Snark_params.Tick

[%%endif]

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('state_hash, 'body) t =
        {previous_state_hash: 'state_hash; body: 'body}
      [@@deriving eq, ord, hash, sexp, to_yojson]
    end
  end]

  type ('state_hash, 'body) t = ('state_hash, 'body) Stable.Latest.t
  [@@deriving sexp]
end

let hash_abstract ~hash_body
    ({previous_state_hash; body} : (State_hash.t, _) Poly.t) =
  let body : State_body_hash.t = hash_body body in
  Random_oracle.hash ~init:Hash_prefix.protocol_state
    [|(previous_state_hash :> Field.t); (body :> Field.t)|]
  |> State_hash.of_hash

module Body = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t =
          { genesis_state_hash: 'state_hash
          ; blockchain_state: 'blockchain_state
          ; consensus_state: 'consensus_state
          ; constants: 'constants }
        [@@deriving bin_io, sexp, eq, compare, to_yojson, hash, version]
      end
    end]

    type ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t =
          ( 'state_hash
          , 'blockchain_state
          , 'consensus_state
          , 'constants )
          Stable.Latest.t =
      { genesis_state_hash: 'state_hash
      ; blockchain_state: 'blockchain_state
      ; consensus_state: 'consensus_state
      ; constants: 'constants }
    [@@deriving sexp]
  end

  module Value = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( State_hash.Stable.V1.t
          , Blockchain_state.Value.Stable.V1.t
          , Consensus.Data.Consensus_state.Value.Stable.V1.t
          , Protocol_constants_checked.Value.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving eq, ord, bin_io, hash, sexp, to_yojson, version]

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t [@@deriving sexp, to_yojson]
  end

  type ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t =
    ('state_hash, 'blockchain_state, 'consensus_state, 'constants) Poly.t

  type value = Value.t [@@deriving sexp, to_yojson]

  [%%ifdef
  consensus_mechanism]

  type var =
    ( State_hash.var
    , Blockchain_state.var
    , Consensus.Data.Consensus_state.var
    , Protocol_constants_checked.var )
    Poly.t

  let to_hlist
      {Poly.genesis_state_hash; blockchain_state; consensus_state; constants} =
    H_list.[genesis_state_hash; blockchain_state; consensus_state; constants]

  let of_hlist :
         (unit, 'sh -> 'bs -> 'cs -> 'cc -> unit) H_list.t
      -> ('sh, 'bs, 'cs, 'cc) Poly.t =
   fun H_list.
         [genesis_state_hash; blockchain_state; consensus_state; constants] ->
    {genesis_state_hash; blockchain_state; consensus_state; constants}

  let data_spec ~constraint_constants =
    Data_spec.
      [ State_hash.typ
      ; Blockchain_state.typ
      ; Consensus.Data.Consensus_state.typ ~constraint_constants
      ; Protocol_constants_checked.typ ]

  let typ ~constraint_constants =
    Typ.of_hlistable
      (data_spec ~constraint_constants)
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  let to_input
      { Poly.genesis_state_hash: State_hash.t
      ; blockchain_state
      ; consensus_state
      ; constants } =
    Random_oracle.Input.(
      append
        (Blockchain_state.to_input blockchain_state)
        (Consensus.Data.Consensus_state.to_input consensus_state)
      |> append (field (genesis_state_hash :> Field.t))
      |> append (Protocol_constants_checked.to_input constants))

  let var_to_input
      {Poly.genesis_state_hash; blockchain_state; consensus_state; constants} =
    let blockchain_state = Blockchain_state.var_to_input blockchain_state in
    let%bind constants = Protocol_constants_checked.var_to_input constants in
    let%map consensus_state =
      Consensus.Data.Consensus_state.var_to_input consensus_state
    in
    Random_oracle.Input.(
      append blockchain_state consensus_state
      |> append (field (State_hash.var_to_hash_packed genesis_state_hash))
      |> append constants)

  let hash_checked (t : var) =
    let%bind input = var_to_input t in
    make_checked (fun () ->
        Random_oracle.Checked.(
          hash ~init:Hash_prefix.protocol_state_body (pack_input input)
          |> State_body_hash.var_of_hash_packed) )

  [%%endif]

  let hash s =
    Random_oracle.hash ~init:Hash_prefix.protocol_state_body
      (Random_oracle.pack_input (to_input s))
    |> State_body_hash.of_hash
end

module Value = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        (State_hash.Stable.V1.t, Body.Value.Stable.V1.t) Poly.Stable.V1.t
      [@@deriving sexp, hash, compare, eq, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, hash, compare, eq, to_yojson]

  include Hashable.Make (Stable.Latest)
end

type value = Value.t [@@deriving sexp, to_yojson]

[%%ifdef
consensus_mechanism]

type var = (State_hash.var, Body.var) Poly.t

[%%endif]

module Proof = Proof
module Hash = State_hash

let create ~previous_state_hash ~body =
  {Poly.Stable.Latest.previous_state_hash; body}

let create' ~previous_state_hash ~genesis_state_hash ~blockchain_state
    ~consensus_state ~constants =
  { Poly.Stable.Latest.previous_state_hash
  ; body=
      { Body.Poly.genesis_state_hash
      ; blockchain_state
      ; consensus_state
      ; constants } }

let create_value = create'

let body {Poly.Stable.Latest.body; _} = body

let previous_state_hash {Poly.Stable.Latest.previous_state_hash; _} =
  previous_state_hash

let blockchain_state
    {Poly.Stable.Latest.body= {Body.Poly.blockchain_state; _}; _} =
  blockchain_state

let consensus_state {Poly.Stable.Latest.body= {Body.Poly.consensus_state; _}; _}
    =
  consensus_state

let constants {Poly.Stable.Latest.body= {Body.Poly.constants; _}; _} =
  constants

[%%ifdef
consensus_mechanism]

let create_var = create'

let to_hlist {Poly.Stable.Latest.previous_state_hash; body} =
  H_list.[previous_state_hash; body]

let of_hlist : (unit, 'psh -> 'body -> unit) H_list.t -> ('psh, 'body) Poly.t =
 fun H_list.[previous_state_hash; body] -> {previous_state_hash; body}

let data_spec ~constraint_constants =
  Data_spec.[State_hash.typ; Body.typ ~constraint_constants]

let typ ~constraint_constants =
  Typ.of_hlistable
    (data_spec ~constraint_constants)
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist

let hash_checked ({previous_state_hash; body} : var) =
  let%bind body = Body.hash_checked body in
  let%map hash =
    make_checked (fun () ->
        Random_oracle.Checked.hash ~init:Hash_prefix.protocol_state
          [| Hash.var_to_hash_packed previous_state_hash
           ; State_body_hash.var_to_hash_packed body |]
        |> State_hash.var_of_hash_packed )
  in
  (hash, body)

let genesis_state_hash_checked ~state_hash state =
  let%bind is_genesis =
    (*if state is in global_slot = 0 then this is the genesis state*)
    Consensus.Data.Consensus_state.is_genesis_state_var (consensus_state state)
  in
  (*get the genesis state hash from this state unless the state itself is the
    genesis state*)
  State_hash.if_ is_genesis ~then_:state_hash
    ~else_:state.body.genesis_state_hash

[%%endif]

let hash = hash_abstract ~hash_body:Body.hash

let genesis_state_hash ?(state_hash = None) state =
  (*If this is the genesis state then simply return its hash
    otherwise return its the genesis_state_hash*)
  if Consensus.Data.Consensus_state.is_genesis_state (consensus_state state)
  then match state_hash with None -> hash state | Some hash -> hash
  else state.body.genesis_state_hash

[%%if
call_logger]

let hash s =
  Coda_debug.Call_logger.record_call "Protocol_state.hash" ;
  hash s

[%%endif]

let negative_one ~genesis_ledger ~constraint_constants ~protocol_constants =
  { Poly.Stable.Latest.previous_state_hash=
      State_hash.of_hash Snark_params.Tick.Pedersen.zero_hash
  ; body=
      { Body.Poly.blockchain_state=
          Blockchain_state.negative_one
            ~genesis_ledger_hash:
              (Coda_base.Ledger.merkle_root (Lazy.force genesis_ledger))
      ; genesis_state_hash=
          State_hash.of_hash Snark_params.Tick.Pedersen.zero_hash
      ; consensus_state=
          Consensus.Data.Consensus_state.negative_one ~genesis_ledger
            ~constraint_constants ~protocol_constants
      ; constants= Protocol_constants_checked.value_of_t protocol_constants }
  }
