[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick

[%%else]

open Snark_params_nonconsensus
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

module T = Coda_numbers.Length

(*constants actually required for blockchain snark*)
(* k
  ,c
  ,slots_per_epoch
  ,slots_per_sub_window
  ,sub_windows_per_window
  ,checkpoint_window_size_in_slots
  ,block_window_duration_ms*)

module Poly = Genesis_constants.Protocol.Poly

module Value = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( T.Stable.V1.t
        , T.Stable.V1.t
        , Block_time.Stable.V1.t
        , T.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving eq, ord, hash, sexp, to_yojson, compare]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving to_yojson, eq, sexp, compare]

  let gen : t Quickcheck.Generator.t =
    let open Quickcheck.Let_syntax in
    let%bind k = Int.gen_incl 1 5000 in
    let%bind delta = Int.gen_incl 0 5000 in
    let%bind block_window_duration_ms =
      Quickcheck.Generator.of_list [2000; 3000; 4000; 6000; 9000]
    in
    let%bind ms = Int64.(gen_log_uniform_incl 0L 9999999999999L) in
    let end_time = Block_time.of_int64 999999999999999L in
    let rec create_genesis_state_timestamp attempts =
      let%bind genesis_state_timestamp =
        Block_time.(gen_incl (of_int64 ms) end_time)
      in
      if
        attempts > 0
        && not
             Block_time.(
               genesis_state_timestamp |> to_time |> of_time
               |> equal genesis_state_timestamp)
      then
        (* Block_time.(to_time x |> of_time) != x for certain values.
           Generate a new one.
        *)
        create_genesis_state_timestamp (attempts - 1)
      else
        (* Found a workable value, or ran out of attempts. *)
        return genesis_state_timestamp
    in
    let%map genesis_state_timestamp = create_genesis_state_timestamp 5 in
    { Poly.k= T.of_int k
    ; delta= T.of_int delta
    ; genesis_state_timestamp
    ; block_window_duration_ms= T.of_int block_window_duration_ms }
end

type value = Value.t

let value_of_t (t : Genesis_constants.Protocol.t) : value =
  { k= T.of_int t.k
  ; delta= T.of_int t.delta
  ; genesis_state_timestamp= Block_time.of_time t.genesis_state_timestamp
  ; block_window_duration_ms= T.of_int t.block_window_duration_ms }

let t_of_value (v : value) : Genesis_constants.Protocol.t =
  { k= T.to_int v.k
  ; delta= T.to_int v.delta
  ; genesis_state_timestamp= Block_time.to_time v.genesis_state_timestamp
  ; block_window_duration_ms= T.to_int v.block_window_duration_ms }

let to_input (t : value) =
  Random_oracle.Input.bitstrings
    [| T.to_bits t.k
     ; T.to_bits t.delta
     ; Block_time.Bits.to_bits t.genesis_state_timestamp
     ; T.to_bits t.block_window_duration_ms |]

[%%if
defined consensus_mechanism]

type var =
  (T.Checked.t, T.Checked.t, Block_time.Unpacked.var, T.Checked.t) Poly.t

let to_hlist
    ({k; delta; genesis_state_timestamp; block_window_duration_ms} : _ Poly.t)
    =
  H_list.[k; delta; genesis_state_timestamp; block_window_duration_ms]

let of_hlist : (unit, _) H_list.t -> _ Poly.t =
 fun H_list.[k; delta; genesis_state_timestamp; block_window_duration_ms] ->
  {k; delta; genesis_state_timestamp; block_window_duration_ms}

let data_spec =
  Data_spec.
    [T.Checked.typ; T.Checked.typ; Block_time.Unpacked.typ; T.Checked.typ]

let typ =
  Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let var_to_input (var : var) =
  let s = Bitstring_lib.Bitstring.Lsb_first.to_list in
  let%map k = T.Checked.to_bits var.k
  and delta = T.Checked.to_bits var.delta
  and block_window_duration_ms =
    T.Checked.to_bits var.block_window_duration_ms
  in
  let genesis_state_timestamp =
    Block_time.Unpacked.var_to_bits var.genesis_state_timestamp
  in
  Random_oracle.Input.bitstrings
    (Array.map ~f:s
       [|k; delta; genesis_state_timestamp; block_window_duration_ms|])

let%test_unit "value = var" =
  let compiled = Genesis_constants.compiled.protocol in
  let test protocol_constants =
    let open Snarky in
    let p_var =
      let%map p = exists typ ~compute:(As_prover.return protocol_constants) in
      As_prover.read typ p
    in
    let _, res = Or_error.ok_exn (run_and_check p_var ()) in
    [%test_eq: Value.t] res protocol_constants ;
    [%test_eq: Value.t] protocol_constants
      (t_of_value protocol_constants |> value_of_t)
  in
  Quickcheck.test ~trials:100 Value.gen ~examples:[value_of_t compiled] ~f:test

[%%endif]
