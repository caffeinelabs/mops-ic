/// Thin wrapper around the IC management canister principal (`aaaaa-aa`).
///
/// Recommended imports:
/// ```motoko
/// import { ic } "mo:ic";
/// import IC "mo:ic/Types";
/// ```
///
/// Use `ic` for calling methods and `IC` for request/response types:
/// ```motoko
/// let args : IC.CreateCanisterArgs = {
///   settings = null;
///   sender_canister_version = null;
/// };
/// let created = await ic.create_canister(args);
/// ```

import Types "Types";

module {
  public let ic = actor ("aaaaa-aa") : Types.Self;
};
