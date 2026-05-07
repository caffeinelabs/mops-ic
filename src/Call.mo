import Result "mo:core/Result";
import Runtime "mo:core/Runtime";
import Prim "mo:prim";

import { ic } "lib";
import IC "Types";

/// Provides wrapper functions for calls to the IC management canister that
/// calculate cycles needed for the call and automatically add them to the call.
/// Only minimal amount of cycles are added to the call. This helps the canister to make more calls in parallel without running out of cycles.
///
/// Cost calculation functions are in the `Cost` submodule.
module {
  /// Invokes the `create_canister` method of the IC management canister and automatically adds the necessary cycles to the call.
  public func createCanister(args : IC.CreateCanisterArgs) : async IC.CreateCanisterResult {
    await (with cycles = Cost.createCanister()) ic.create_canister(args);
  };

  /// Invokes the `http_request` method of the IC management canister and automatically adds the necessary cycles to the call.
  public func httpRequest(args : IC.HttpRequestArgs) : async IC.HttpRequestResult {
    await (with cycles = Cost.httpRequest(args)) ic.http_request(args);
  };

  /// Invokes the `sign_with_ecdsa` method of the IC management canister and automatically adds the necessary cycles to the call.
  ///
  /// Returns an error if the arguments are invalid and the cost cannot be determined.
  public func trySignWithEcdsa(args : IC.SignWithEcdsaArgs) : async Result<IC.SignWithEcdsaResult, SignError> {
    let { name; curve } = args.key_id;
    switch (Cost.signWithEcdsa(name, curve)) {
      case (#ok(cycles)) #ok(await (with cycles) ic.sign_with_ecdsa(args));
      case (#err(error)) #err(error);
    };
  };

  /// Invokes the `sign_with_ecdsa` method of the IC management canister and automatically adds the necessary cycles to the call.
  ///
  /// Traps if the arguments are invalid and the cost cannot be determined.
  public func signWithEcdsa(args : IC.SignWithEcdsaArgs) : async IC.SignWithEcdsaResult {
    let { name; curve } = args.key_id;
    switch (Cost.signWithEcdsa(name, curve)) {
      case (#ok(cycles)) await (with cycles) ic.sign_with_ecdsa(args);
      case (#err(error)) Runtime.trap("Cannot determine cost of sign_with_ecdsa: " # debug_show (error));
    };
  };

  /// Invokes the `sign_with_schnorr` method of the IC management canister and automatically adds the necessary cycles to the call.
  ///
  /// Returns an error if the arguments are invalid and the cost cannot be determined.
  public func trySignWithSchnorr(args : IC.SignWithSchnorrArgs) : async Result<IC.SignWithSchnorrResult, SignError> {
    let { name; algorithm } = args.key_id;
    switch (Cost.signWithSchnorr(name, algorithm)) {
      case (#ok(cycles)) #ok(await (with cycles) ic.sign_with_schnorr(args));
      case (#err(error)) #err(error);
    };
  };

  /// Invokes the `sign_with_schnorr` method of the IC management canister and automatically adds the necessary cycles to the call.
  ///
  /// Traps if the arguments are invalid and the cost cannot be determined.
  public func signWithSchnorr(args : IC.SignWithSchnorrArgs) : async IC.SignWithSchnorrResult {
    let { name; algorithm } = args.key_id;
    switch (Cost.signWithSchnorr(name, algorithm)) {
      case (#ok(cycles)) await (with cycles) ic.sign_with_schnorr(args);
      case (#err(error)) Runtime.trap("Cannot determine cost of sign_with_schnorr: " # debug_show (error));
    };
  };

  /// Cycle cost calculation functions.
  /// Refer to the [IC Interface Specification: section Cycle cost calculation](https://internetcomputer.org/docs/references/ic-interface-spec#system-api-cycle-cost) for more information.
  public module Cost {
    // Future work: How this is meant to be used? Improve the API depending on the usecase, Nat64 arguments are not ideal
    public func call(methodNameSize : Nat64, payloadSize : Nat64) : Nat = Prim.costCall(methodNameSize, payloadSize);

    public func createCanister() : Nat = Prim.costCreateCanister();

    public func httpRequest(args : IC.HttpRequestArgs) : Nat {
      let requestSize = calculateRequestSize(args);
      let maxResponseBytes : Nat64 = switch (args.max_response_bytes) {
        // As stated here: https://internetcomputer.org/docs/references/ic-interface-spec#ic-http_request:
        // "The upper limit on the maximal size for the response is 2MB (2,000,000B) and this value also applies if no maximal size value is specified."
        case null 2_000_000;
        case (?bytes) bytes;
      };
      Prim.costHttpRequest(requestSize, maxResponseBytes);
    };

    public func signWithEcdsa(keyName : Text, curve : IC.EcdsaCurve) : Result<Nat, SignError> {
      let curveEncoding : Nat32 = switch (curve) {
        case (#secp256k1) 0;
      };
      let (code, cyclesOrArbitrary) = Prim.costSignWithEcdsa(keyName, curveEncoding);
      switch (code) {
        case 0 #ok(cyclesOrArbitrary);
        case 1 Runtime.trap("Unreachable: Invalid ecdsa curve encoding.");
        case 2 #err(#invalidKeyName);
        case _ Runtime.trap("Invalid error code returned from Prim.costSignWithEcdsa");
      };
    };

    public func signWithSchnorr(keyName : Text, algorithm : IC.SchnorrAlgorithm) : Result<Nat, SignError> {
      let algorithmEncoding : Nat32 = switch (algorithm) {
        case (#bip340secp256k1) 0;
        case (#ed25519) 1;
      };
      let (code, cyclesOrArbitrary) = Prim.costSignWithSchnorr(keyName, algorithmEncoding);
      switch (code) {
        case 0 #ok(cyclesOrArbitrary);
        case 1 Runtime.trap("Unreachable: Invalid schnorr algorithm encoding.");
        case 2 #err(#invalidKeyName);
        case _ Runtime.trap("Invalid error code returned from Prim.costSignWithSchnorr");
      };
    };

    func calculateRequestSize(request : IC.HttpRequestArgs) : Nat64 {
      var size : Nat64 = 0;

      // Add URL byte length
      size += Prim.natToNat64(request.url.size());

      // Add headers byte length (sum of all names and values)
      for (header in request.headers.vals()) {
        size += Prim.natToNat64(header.name.size());
        size += Prim.natToNat64(header.value.size());
      };

      // Add body length if present
      switch (request.body) {
        case (?body) { size += Prim.natToNat64(body.size()) };
        case null {};
      };

      // Add transform context length if present
      switch (request.transform) {
        case (?transform) {
          size += Prim.natToNat64(transform.context.size());
          // Future work: How to get the method name length otherwise?
          // This gets us both the method name and the actor.
          // It results in a few extra cycles (cannot be exact now) but it's a good approximation.
          let blob = to_candid (transform.function);
          size += Prim.natToNat64(blob.size());
        };
        case null {};
      };

      size;
    };
  };

  public type SignError = {
    #invalidKeyName;
  };

  type Result<Ok, Err> = Result.Result<Ok, Err>;
};
