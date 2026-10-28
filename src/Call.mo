import Array "mo:core/Array";
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

  /// The HTTP method of an outcall.
  public type HttpMethod = { #get; #head; #post; #put; #delete; #patch };

  /// A `transform` function together with its context.
  public type Transform = {
    function : shared query { context : Blob; response : IC.HttpRequestResult } -> async IC.HttpRequestResult;
    context : Blob;
  };

  /// How many nodes issue a flexible outcall, and how many of their responses to require and accept.
  public type ReplicationCounts = {
    min_responses : Nat32;
    max_responses : Nat32;
    total_requests : Nat32;
  };

  /// A builder for an HTTPS outcall via `http_request`.
  ///
  /// The outcall is always made with pricing version `2` ("pay-as-you-go"), which charges for the
  /// resources the call actually consumes rather than for `max_response_bytes`.
  ///
  /// Under version `2` the attached cycles are also the budget each node may spend on the outcall.
  /// Every `withExpected*` method narrows that budget; anything left unset falls back to the most
  /// the outcall could consume.
  ///
  /// ```motoko no-repl
  /// let response = await Call.httpRequest("https://example.com/api")
  ///   .withMethod(#post)
  ///   .withMaxResponseBytes(4_000)
  ///   .withExpectedRoundtripTimeMs(300)
  ///   .send();
  /// ```
  public type HttpRequest = {
    withMethod : HttpMethod -> HttpRequest;
    withHeaders : [IC.HttpHeader] -> HttpRequest;
    withHeader : (Text, Text) -> HttpRequest;
    withBody : Blob -> HttpRequest;
    withMaxResponseBytes : Nat64 -> HttpRequest;
    withTransform : Transform -> HttpRequest;
    /// Makes the outcall non-replicated: one node performs it and its answer is delivered.
    nonReplicated : () -> HttpRequest;
    withExpectedRoundtripTimeMs : Nat64 -> HttpRequest;
    withExpectedRawResponseBytes : Nat64 -> HttpRequest;
    withExpectedTransformedResponseBytes : Nat64 -> HttpRequest;
    withExpectedTransformInstructions : Nat64 -> HttpRequest;
    /// The arguments `send` will use, with `pricing_version` set to `2`.
    args : () -> IC.HttpRequestArgs;
    /// The cycles `send` will attach.
    getCost : () -> Nat;
    /// Makes the outcall, attaching `getCost()` cycles.
    send : () -> async IC.HttpRequestResult;
  };

  /// Starts building an outcall to `url`.
  public func httpRequest(url : Text) : HttpRequest = httpRequestFromArgs({
    url;
    method = #get;
    headers = [];
    body = null;
    max_response_bytes = null;
    transform = null;
    is_replicated = null;
    pricing_version = ?2;
  });

  /// Starts building an outcall from existing arguments. `pricing_version` is overwritten with `2`.
  public func httpRequestFromArgs(args : IC.HttpRequestArgs) : HttpRequest = buildHttpRequest({ args with pricing_version = ?2 }, Cost.worstCase);

  func buildHttpRequest(a : IC.HttpRequestArgs, e : Cost.ExpectedUsage) : HttpRequest = object {
    public func withMethod(method : HttpMethod) : HttpRequest = buildHttpRequest({ a with method }, e);
    public func withHeaders(headers : [IC.HttpHeader]) : HttpRequest = buildHttpRequest({ a with headers }, e);
    public func withHeader(name : Text, value : Text) : HttpRequest = buildHttpRequest({ a with headers = a.headers.concat([{ name; value }]) }, e);
    public func withBody(body : Blob) : HttpRequest = buildHttpRequest({ a with body = ?body }, e);
    public func withMaxResponseBytes(n : Nat64) : HttpRequest = buildHttpRequest({ a with max_response_bytes = ?n }, e);
    public func withTransform(t : Transform) : HttpRequest = buildHttpRequest({ a with transform = ?t }, e);
    public func nonReplicated() : HttpRequest = buildHttpRequest({ a with is_replicated = ?false }, e);
    public func withExpectedRoundtripTimeMs(v : Nat64) : HttpRequest = buildHttpRequest(a, { e with roundtripTimeMs = ?v });
    public func withExpectedRawResponseBytes(v : Nat64) : HttpRequest = buildHttpRequest(a, { e with rawResponseBytes = ?v });
    public func withExpectedTransformedResponseBytes(v : Nat64) : HttpRequest = buildHttpRequest(a, { e with transformedResponseBytes = ?v });
    public func withExpectedTransformInstructions(v : Nat64) : HttpRequest = buildHttpRequest(a, { e with transformInstructions = ?v });
    public func args() : IC.HttpRequestArgs = a;
    public func getCost() : Nat = Cost.httpRequest(a, e);
    public func send() : async IC.HttpRequestResult {
      await (with cycles = getCost()) ic.http_request(a);
    };
  };

  /// A builder for a flexible HTTPS outcall via `flexible_http_request`.
  ///
  /// A committee of nodes make the request and the canister receives their individual responses
  /// rather than one the subnet agreed on. Flexible outcalls are always priced with version `2`.
  ///
  /// ```motoko no-repl
  /// let result = await Call.flexibleHttpRequest("https://example.com/api")
  ///   .withReplication({ min_responses = 2; max_responses = 3; total_requests = 3 })
  ///   .withMaxResponseBytes(4_000)
  ///   .send();
  /// ```
  public type FlexibleHttpRequest = {
    withMethod : HttpMethod -> FlexibleHttpRequest;
    withHeaders : [IC.HttpHeader] -> FlexibleHttpRequest;
    withHeader : (Text, Text) -> FlexibleHttpRequest;
    withBody : Blob -> FlexibleHttpRequest;
    withMaxResponseBytes : Nat64 -> FlexibleHttpRequest;
    withTransform : Transform -> FlexibleHttpRequest;
    /// Defaults to the endpoint's own counts, which depend on the size of the subnet.
    /// Setting it also lowers the default reservation, which can then account for `min_responses`.
    withReplication : ReplicationCounts -> FlexibleHttpRequest;
    withExpectedRoundtripTimeMs : Nat64 -> FlexibleHttpRequest;
    withExpectedRawResponseBytes : Nat64 -> FlexibleHttpRequest;
    withExpectedTransformedResponseBytes : Nat64 -> FlexibleHttpRequest;
    withExpectedTransformInstructions : Nat64 -> FlexibleHttpRequest;
    /// The arguments `send` will use.
    args : () -> IC.FlexibleHttpRequestArgs;
    /// The cycles `send` will attach.
    getCost : () -> Nat;
    /// Makes the outcall, attaching `getCost()` cycles.
    send : () -> async IC.FlexibleHttpRequestResult;
  };

  /// Starts building a flexible outcall to `url`.
  public func flexibleHttpRequest(url : Text) : FlexibleHttpRequest = flexibleHttpRequestFromArgs({
    url;
    method = #get;
    headers = [];
    body = null;
    max_response_bytes = null;
    transform = null;
    replication = null;
  });

  /// Starts building a flexible outcall from existing arguments.
  public func flexibleHttpRequestFromArgs(args : IC.FlexibleHttpRequestArgs) : FlexibleHttpRequest = buildFlexibleHttpRequest(args, Cost.worstCase);

  func buildFlexibleHttpRequest(a : IC.FlexibleHttpRequestArgs, e : Cost.ExpectedUsage) : FlexibleHttpRequest = object {
    public func withMethod(method : HttpMethod) : FlexibleHttpRequest = buildFlexibleHttpRequest({ a with method }, e);
    public func withHeaders(headers : [IC.HttpHeader]) : FlexibleHttpRequest = buildFlexibleHttpRequest({ a with headers }, e);
    public func withHeader(name : Text, value : Text) : FlexibleHttpRequest = buildFlexibleHttpRequest({ a with headers = a.headers.concat([{ name; value }]) }, e);
    public func withBody(body : Blob) : FlexibleHttpRequest = buildFlexibleHttpRequest({ a with body = ?body }, e);
    public func withMaxResponseBytes(n : Nat64) : FlexibleHttpRequest = buildFlexibleHttpRequest({ a with max_response_bytes = ?n }, e);
    public func withTransform(t : Transform) : FlexibleHttpRequest = buildFlexibleHttpRequest({ a with transform = ?t }, e);
    public func withReplication(counts : ReplicationCounts) : FlexibleHttpRequest = buildFlexibleHttpRequest({ a with replication = ?counts }, e);
    public func withExpectedRoundtripTimeMs(v : Nat64) : FlexibleHttpRequest = buildFlexibleHttpRequest(a, { e with roundtripTimeMs = ?v });
    public func withExpectedRawResponseBytes(v : Nat64) : FlexibleHttpRequest = buildFlexibleHttpRequest(a, { e with rawResponseBytes = ?v });
    public func withExpectedTransformedResponseBytes(v : Nat64) : FlexibleHttpRequest = buildFlexibleHttpRequest(a, { e with transformedResponseBytes = ?v });
    public func withExpectedTransformInstructions(v : Nat64) : FlexibleHttpRequest = buildFlexibleHttpRequest(a, { e with transformInstructions = ?v });
    public func args() : IC.FlexibleHttpRequestArgs = a;
    public func getCost() : Nat = Cost.flexibleHttpRequest(a, e);
    public func send() : async IC.FlexibleHttpRequestResult {
      await (with cycles = getCost()) ic.flexible_http_request(a);
    };
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

    /// The resources a caller expects an outcall to consume.
    ///
    /// A field left `null` falls back to the most that resource could reach. That reservation cannot
    /// run short, but it holds far more cycles while the outcall runs.
    public type ExpectedUsage = {
      roundtripTimeMs : ?Nat64;
      rawResponseBytes : ?Nat64;
      transformedResponseBytes : ?Nat64;
      transformInstructions : ?Nat64;
    };

    /// Expects the most an outcall could consume.
    public let worstCase : ExpectedUsage = {
      roundtripTimeMs = null;
      rawResponseBytes = null;
      transformedResponseBytes = null;
      transformInstructions = null;
    };

    /// The cycles to attach to an `http_request` with `pricing_version = ?2`.
    public func httpRequest(args : IC.HttpRequestArgs, expected : ExpectedUsage) : Nat {
      let (roundtrip, raw, transformed, instructions) = resolve(expected, args.max_response_bytes, null, isSome(args.transform));
      costHttpRequestV2({
        request_bytes = requestBytes(args.url, args.headers, args.body, args.transform);
        http_roundtrip_time_ms = roundtrip;
        raw_response_bytes = raw;
        transformed_response_bytes = transformed;
        transform_instructions = instructions;
        // `null` prices a fully replicated outcall.
        outcall_type = if (args.is_replicated == ?false) ?(#non_replicated(null)) else null;
      });
    };

    /// The cycles to attach to a `flexible_http_request`.
    ///
    /// Without an explicit `transformedResponseBytes`, the reservation assumes responses no larger
    /// than the result limit divided by `min_responses`, since larger ones cannot all be delivered.
    /// That cap needs `replication` to be set; without it, the reservation assumes full-size responses.
    public func flexibleHttpRequest(args : IC.FlexibleHttpRequestArgs, expected : ExpectedUsage) : Nat {
      let (roundtrip, raw, transformed, instructions) = resolve(
        expected,
        args.max_response_bytes,
        flexibleTransformedCap(args.replication),
        isSome(args.transform),
      );
      costHttpRequestV2({
        request_bytes = requestBytes(args.url, args.headers, args.body, args.transform);
        http_roundtrip_time_ms = roundtrip;
        raw_response_bytes = raw;
        transformed_response_bytes = transformed;
        transform_instructions = instructions;
        outcall_type = ?(#flexible_(args.replication));
      });
    };

    public func signWithEcdsa(keyName : Text, curve : IC.EcdsaCurve) : Result<Nat, SignError> {
      let curveEncoding : Nat32 = switch (curve) {
        case (#secp256k1) 0;
        case (#secp256r1) 1;
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

    // Limits from the interface specification of `ic0.cost_http_request_v2`.
    let MAX_RESPONSE_BYTES : Nat64 = 2_000_000;
    let MAX_ROUNDTRIP_TIME_MS : Nat64 = 60_000;
    let MAX_TRANSFORM_INSTRUCTIONS : Nat64 = 5_000_000_000;
    let CANDID_OVERHEAD_RESERVE_BYTES : Nat64 = 1_024;
    let MAX_FLEXIBLE_RESULT_BYTES : Nat64 = 2_097_152;

    // The argument of `ic0.cost_http_request_v2`, which takes it Candid-encoded.
    type CostParams = {
      request_bytes : Nat64;
      http_roundtrip_time_ms : Nat64;
      raw_response_bytes : Nat64;
      transformed_response_bytes : Nat64;
      transform_instructions : Nat64;
      outcall_type : ?{
        #fully_replicated : Any;
        #non_replicated : Any;
        // `flexible` is a Motoko keyword; Candid drops the trailing underscore.
        #flexible_ : ?ReplicationCounts;
      };
    };

    func costHttpRequestV2(params : CostParams) : Nat = Prim.costHttpRequestV2(to_candid (params));

    func resolve(expected : ExpectedUsage, maxResponseBytes : ?Nat64, transformedCap : ?Nat64, hasTransform : Bool) : (Nat64, Nat64, Nat64, Nat64) {
      let cap = switch (maxResponseBytes) { case null MAX_RESPONSE_BYTES; case (?bytes) bytes };
      let roundtrip = switch (expected.roundtripTimeMs) { case null MAX_ROUNDTRIP_TIME_MS; case (?v) v };
      let raw = switch (expected.rawResponseBytes) { case null cap; case (?v) v };
      let maxTransformed = cap + CANDID_OVERHEAD_RESERVE_BYTES;
      let transformed = switch (expected.transformedResponseBytes, transformedCap) {
        case (?v, _) v;
        case (null, ?c) if (c < maxTransformed) c else maxTransformed;
        case (null, null) maxTransformed;
      };
      let instructions : Nat64 = switch (expected.transformInstructions) {
        case (?v) v;
        // The system never runs a transform the request doesn't set.
        case null if (hasTransform) MAX_TRANSFORM_INSTRUCTIONS else 0;
      };
      (roundtrip, raw, transformed, instructions);
    };

    func isSome<T>(option : ?T) : Bool = switch option { case null false; case (?_) true };

    func flexibleTransformedCap(replication : ?ReplicationCounts) : ?Nat64 {
      switch (replication) {
        // A fire-and-forget outcall delivers no responses, so nothing bounds their size.
        case (?{ max_responses = 0 }) null;
        case (?{ min_responses = 0 }) null;
        case (?{ min_responses }) {
          let m = Prim.nat32ToNat64(min_responses);
          ?((MAX_FLEXIBLE_RESULT_BYTES + m - 1) / m);
        };
        // The endpoint's default `min_responses` depends on the subnet size, which needs `ic0.subnet_self_node_count`.
        // Calling it would make every canister importing this module require a replica that has it.
        case null null;
      };
    };

    func requestBytes(url : Text, headers : [IC.HttpHeader], body : ?Blob, transform : ?Transform) : Nat64 {
      var size = Prim.natToNat64(url.size());
      for (header in headers.values()) {
        size += Prim.natToNat64(header.name.size() + header.value.size());
      };
      switch (body) {
        case (?body) { size += Prim.natToNat64(body.size()) };
        case null {};
      };
      switch (transform) {
        case (?transform) {
          size += Prim.natToNat64(transform.context.size());
          // Motoko can't read a shared function's method name, so this counts the encoded reference,
          // which adds the principal's bytes and slightly overestimates the cost.
          size += Prim.natToNat64((to_candid (transform.function)).size());
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
