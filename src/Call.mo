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

  /// The HTTP method of an outcall. `didc` inlines this in `Types.mo`, so it is named here.
  public type HttpMethod = { #get; #put; #head; #post; #delete; #patch };

  /// A `transform` function together with its context.
  public type Transform = {
    function : shared query { context : Blob; response : IC.HttpRequestResult } -> async IC.HttpRequestResult;
    context : Blob;
  };

  /// A builder for an HTTPS outcall via `http_request`.
  ///
  /// The outcall is always made with pricing version `2` ("pay-as-you-go"), which charges for the
  /// resources the call actually consumes rather than for `max_response_bytes`.
  ///
  /// Because the cycles attached to a version `2` outcall are also the budget each node may spend
  /// on it, the amount to attach depends on how much the call is expected to consume. Every
  /// `withExpected*` method narrows that estimate; whatever is left unset falls back to the most
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
    /// The arguments as they stand, with `pricing_version` already set to `2`.
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

  /// Starts building an outcall from existing arguments, so a call site can migrate without
  /// rewriting how it builds them. `pricing_version` is overwritten with `2`.
  public func httpRequestFromArgs(args : IC.HttpRequestArgs) : HttpRequest =
    buildHttpRequest({ args with pricing_version = ?2 }, Cost.worstCase);

  func buildHttpRequest(a : IC.HttpRequestArgs, e : Cost.ExpectedUsage) : HttpRequest = object {
    public func withMethod(m : HttpMethod) : HttpRequest = buildHttpRequest({ a with method = m }, e);
    public func withHeaders(h : [IC.HttpHeader]) : HttpRequest = buildHttpRequest({ a with headers = h }, e);
    public func withHeader(name : Text, value : Text) : HttpRequest =
      buildHttpRequest({ a with headers = a.headers.concat([{ name; value }]) }, e);
    public func withBody(b : Blob) : HttpRequest = buildHttpRequest({ a with body = ?b }, e);
    public func withMaxResponseBytes(n : Nat64) : HttpRequest = buildHttpRequest({ a with max_response_bytes = ?n }, e);
    public func withTransform(t : Transform) : HttpRequest = buildHttpRequest({ a with transform = ?t }, e);
    public func nonReplicated() : HttpRequest = buildHttpRequest({ a with is_replicated = ?false }, e);
    public func withExpectedRoundtripTimeMs(v : Nat64) : HttpRequest = buildHttpRequest(a, { e with roundtripTimeMs = ?v });
    public func withExpectedRawResponseBytes(v : Nat64) : HttpRequest = buildHttpRequest(a, { e with rawResponseBytes = ?v });
    public func withExpectedTransformedResponseBytes(v : Nat64) : HttpRequest = buildHttpRequest(a, { e with transformedResponseBytes = ?v });
    public func withExpectedTransformInstructions(v : Nat64) : HttpRequest = buildHttpRequest(a, { e with transformInstructions = ?v });
    public func args() : IC.HttpRequestArgs = a;
    public func getCost() : Nat = Cost.httpRequestV2(a, e);
    public func send() : async IC.HttpRequestResult = async { await (with cycles = getCost()) ic.http_request(a) };
  };

  /// A builder for a flexible HTTPS outcall via `flexible_http_request`.
  ///
  /// A committee of nodes make the request and the canister receives their individual responses
  /// rather than one the subnet agreed on. Flexible outcalls are always priced with version `2`.
  public type FlexibleHttpRequest = {
    withMethod : HttpMethod -> FlexibleHttpRequest;
    withHeaders : [IC.HttpHeader] -> FlexibleHttpRequest;
    withHeader : (Text, Text) -> FlexibleHttpRequest;
    withBody : Blob -> FlexibleHttpRequest;
    withMaxResponseBytes : Nat64 -> FlexibleHttpRequest;
    withTransform : Transform -> FlexibleHttpRequest;
    /// Sets how many nodes issue the request and how many responses to require and accept.
    withReplication : { min_responses : Nat32; max_responses : Nat32; total_requests : Nat32 } -> FlexibleHttpRequest;
    withExpectedRoundtripTimeMs : Nat64 -> FlexibleHttpRequest;
    withExpectedRawResponseBytes : Nat64 -> FlexibleHttpRequest;
    withExpectedTransformedResponseBytes : Nat64 -> FlexibleHttpRequest;
    withExpectedTransformInstructions : Nat64 -> FlexibleHttpRequest;
    args : () -> IC.FlexibleHttpRequestArgs;
    getCost : () -> Nat;
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
  public func flexibleHttpRequestFromArgs(args : IC.FlexibleHttpRequestArgs) : FlexibleHttpRequest =
    buildFlexibleHttpRequest(args, Cost.worstCase);

  func buildFlexibleHttpRequest(a : IC.FlexibleHttpRequestArgs, e : Cost.ExpectedUsage) : FlexibleHttpRequest = object {
    public func withMethod(m : HttpMethod) : FlexibleHttpRequest = buildFlexibleHttpRequest({ a with method = m }, e);
    public func withHeaders(h : [IC.HttpHeader]) : FlexibleHttpRequest = buildFlexibleHttpRequest({ a with headers = h }, e);
    public func withHeader(name : Text, value : Text) : FlexibleHttpRequest =
      buildFlexibleHttpRequest({ a with headers = a.headers.concat([{ name; value }]) }, e);
    public func withBody(b : Blob) : FlexibleHttpRequest = buildFlexibleHttpRequest({ a with body = ?b }, e);
    public func withMaxResponseBytes(n : Nat64) : FlexibleHttpRequest = buildFlexibleHttpRequest({ a with max_response_bytes = ?n }, e);
    public func withTransform(t : Transform) : FlexibleHttpRequest = buildFlexibleHttpRequest({ a with transform = ?t }, e);
    public func withReplication(c : { min_responses : Nat32; max_responses : Nat32; total_requests : Nat32 }) : FlexibleHttpRequest =
      buildFlexibleHttpRequest({ a with replication = ?c }, e);
    public func withExpectedRoundtripTimeMs(v : Nat64) : FlexibleHttpRequest = buildFlexibleHttpRequest(a, { e with roundtripTimeMs = ?v });
    public func withExpectedRawResponseBytes(v : Nat64) : FlexibleHttpRequest = buildFlexibleHttpRequest(a, { e with rawResponseBytes = ?v });
    public func withExpectedTransformedResponseBytes(v : Nat64) : FlexibleHttpRequest = buildFlexibleHttpRequest(a, { e with transformedResponseBytes = ?v });
    public func withExpectedTransformInstructions(v : Nat64) : FlexibleHttpRequest = buildFlexibleHttpRequest(a, { e with transformInstructions = ?v });
    public func args() : IC.FlexibleHttpRequestArgs = a;
    public func getCost() : Nat = Cost.flexibleHttpRequest(a, e);
    public func send() : async IC.FlexibleHttpRequestResult = async { await (with cycles = getCost()) ic.flexible_http_request(a) };
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

    /// The resource consumption a caller expects an outcall to have.
    ///
    /// Under pricing version `2` the attached cycles are also the budget each node may spend, so
    /// narrowing these narrows the reservation. A field left `null` falls back to the most that
    /// parameter could reach, which yields a reservation the outcall cannot exhaust but which
    /// holds far more cycles for the duration of the call.
    public type ExpectedUsage = {
      roundtripTimeMs : ?Nat64;
      rawResponseBytes : ?Nat64;
      transformedResponseBytes : ?Nat64;
      transformInstructions : ?Nat64;
    };

    /// Expect the most an outcall could consume. Reserves an amount it cannot run short of.
    public let worstCase : ExpectedUsage = {
      roundtripTimeMs = null;
      rawResponseBytes = null;
      transformedResponseBytes = null;
      transformInstructions = null;
    };

    // Protocol limits, mirroring the interface specification.
    let MAX_RESPONSE_BYTES : Nat64 = 2_000_000;
    let MAX_ROUNDTRIP_TIME_MS : Nat64 = 60_000;
    let MAX_TRANSFORM_INSTRUCTIONS : Nat64 = 5_000_000_000;
    let CANDID_OVERHEAD_RESERVE_BYTES : Nat64 = 1_024;
    // The block space one flexible outcall has for its responses.
    let MAX_FLEXIBLE_RESULT_BYTES : Nat64 = 2_097_152;

    // `flexible` is a reserved word in Motoko, so the variant tag cannot be written by name.
    // `_351978059_` is its Candid field hash, which is what goes on the wire either way.
    type CostParams = {
      request_bytes : Nat64;
      http_roundtrip_time_ms : Nat64;
      raw_response_bytes : Nat64;
      transformed_response_bytes : Nat64;
      transform_instructions : Nat64;
      outcall_type : ?{
        #fully_replicated : Any;
        #non_replicated : Any;
        #_351978059_ : ?{ min_responses : Nat32; max_responses : Nat32; total_requests : Nat32 };
      };
    };

    /// Resolves an expectation against `max_response_bytes`, filling unset fields with the most
    /// the outcall could consume. `transformedCap` bounds the fallback for the transformed size;
    /// `hasTransform` says whether a transform can run at all.
    func resolve(
      expected : ExpectedUsage,
      maxResponseBytes : ?Nat64,
      transformedCap : ?Nat64,
      hasTransform : Bool,
    ) : (Nat64, Nat64, Nat64, Nat64) {
      let cap : Nat64 = switch (maxResponseBytes) { case null MAX_RESPONSE_BYTES; case (?b) b };
      let roundtrip = switch (expected.roundtripTimeMs) { case null MAX_ROUNDTRIP_TIME_MS; case (?v) v };
      let raw = switch (expected.rawResponseBytes) { case null cap; case (?v) v };
      let transformed = switch (expected.transformedResponseBytes) {
        case (?v) v;
        case null {
          let worst = cap + CANDID_OVERHEAD_RESERVE_BYTES;
          switch (transformedCap) { case null worst; case (?c) if (c < worst) c else worst };
        };
      };
      let instructions = switch (expected.transformInstructions) {
        case (?v) v;
        // Without a transform the system never runs one, so nothing is reserved for it.
        case null if (hasTransform) MAX_TRANSFORM_INSTRUCTIONS else (0 : Nat64);
      };
      (roundtrip, raw, transformed, instructions);
    };

    /// The cycles an `http_request` priced with pricing version `2` should attach.
    public func httpRequestV2(args : IC.HttpRequestArgs, expected : ExpectedUsage) : Nat {
      let hasTransform = switch (args.transform) { case null false; case (?_) true };
      let (roundtrip, raw, transformed, instructions) = resolve(expected, args.max_response_bytes, null, hasTransform);
      let outcallType = switch (args.is_replicated) {
        case (?false) ?(#non_replicated(null));
        // Absent means fully replicated, which is what an absent `outcall_type` prices.
        case _ null;
      };
      let params : CostParams = {
        request_bytes = calculateRequestSize(args.url, args.headers, args.body, args.transform);
        http_roundtrip_time_ms = roundtrip;
        raw_response_bytes = raw;
        transformed_response_bytes = transformed;
        transform_instructions = instructions;
        outcall_type = outcallType;
      };
      Prim.costHttpRequestV2(to_candid (params));
    };

    /// The cycles a `flexible_http_request` should attach.
    ///
    /// The expected transformed size defaults to the block budget divided by `min_responses`,
    /// rounded up: responses larger than that average cannot be delivered together, so reserving
    /// for them only withholds cycles for the duration of the call.
    public func flexibleHttpRequest(args : IC.FlexibleHttpRequestArgs, expected : ExpectedUsage) : Nat {
      let counts = switch (args.replication) {
        case (?c) c;
        case null {
          // The endpoint's own defaults when `replication` is unset.
          let n = Prim.subnetSelfNodeCount();
          { min_responses = 2 * n / 3 + 1; max_responses = n; total_requests = n };
        };
      };
      let transformedCap : ?Nat64 =
        if (counts.max_responses == 0 or counts.min_responses == 0) null
        else {
          let m = Prim.natToNat64(Prim.nat32ToNat(counts.min_responses));
          ?((MAX_FLEXIBLE_RESULT_BYTES + m - 1) / m);
        };
      let hasTransform = switch (args.transform) { case null false; case (?_) true };
      let (roundtrip, raw, transformed, instructions) = resolve(expected, args.max_response_bytes, transformedCap, hasTransform);
      let params : CostParams = {
        request_bytes = calculateRequestSize(args.url, args.headers, args.body, args.transform);
        http_roundtrip_time_ms = roundtrip;
        raw_response_bytes = raw;
        transformed_response_bytes = transformed;
        transform_instructions = instructions;
        outcall_type = ?(#_351978059_(?counts));
      };
      Prim.costHttpRequestV2(to_candid (params));
    };

    /// The `request_bytes` an outcall is charged for: the URL, every header name and value, the
    /// body, and the transform method name and context. Taken as components so that both
    /// `HttpRequestArgs` and `FlexibleHttpRequestArgs` can be measured.
    func calculateRequestSize(
      url : Text,
      headers : [IC.HttpHeader],
      body : ?Blob,
      transform : ?{ function : shared query { context : Blob; response : IC.HttpRequestResult } -> async IC.HttpRequestResult; context : Blob },
    ) : Nat64 {
      var size : Nat64 = 0;
      size += Prim.natToNat64(url.size());
      for (header in headers.vals()) {
        size += Prim.natToNat64(header.name.size());
        size += Prim.natToNat64(header.value.size());
      };
      switch (body) {
        case (?b) { size += Prim.natToNat64(b.size()) };
        case null {};
      };
      switch (transform) {
        case (?t) {
          size += Prim.natToNat64(t.context.size());
          // Future work: How to get the method name length otherwise?
          // This gets us both the method name and the actor.
          // It results in a few extra cycles (cannot be exact now) but it's a good approximation.
          let blob = to_candid (t.function);
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
