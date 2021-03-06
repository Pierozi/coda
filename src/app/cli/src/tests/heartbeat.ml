open Core
open Async

module Make () = struct
  let heartbeat_flag = ref true

  let print_heartbeat logger =
    let rec loop () =
      if !heartbeat_flag then (
        Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
          "Heartbeat for CI" ;
        let%bind () = after (Time.Span.of_min 1.) in
        loop () )
      else return ()
    in
    loop ()
end
