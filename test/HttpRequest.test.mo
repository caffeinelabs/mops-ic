import Blob "mo:core/Blob";
import Nat32 "mo:core/Nat32";
import Prim "mo:prim";
import { suite; test; expect } "mo:test/async";

import IC "../src/Types";
import Call "../src/Call";

// Runs on PocketIC, which implements `ic0.cost_http_request_v2` as specified but makes no outcalls, so this only prices them.
actor {
  public shared func runTests() : async () {
    await test(
      "httpRequest selects pricing version 2",
      func() : async () {
        let args = Call.httpRequestFromArgs({ request with pricing_version = ?1 }).args();
        expect.option(args.pricing_version, Nat32.toText, Nat32.equal).equal(?2);
        expect.option(Call.httpRequest(request.url).args().pricing_version, Nat32.toText, Nat32.equal).equal(?2);
      },
    );

    await test(
      "httpRequest builder sets the arguments",
      func() : async () {
        let args = Call.httpRequest(request.url)
          .withMethod(#post)
          .withHeader("x-a", "1")
          .withHeader("x-b", "2")
          .withBody("body")
          .withMaxResponseBytes(1_000)
          .nonReplicated()
          .args();
        expect.bool(args.method == #post).isTrue();
        expect.nat(args.headers.size()).equal(2);
        expect.bool(args.body == ?"body").isTrue();
        expect.bool(args.max_response_bytes == ?1_000).isTrue();
        expect.bool(args.is_replicated == ?false).isTrue();
      },
    );

    await suite(
      "http_request cost",
      func() : async () {
        await test(
          "is positive",
          func() : async () {
            expect.nat(Call.httpRequestFromArgs(request).getCost()).greater(0);
          },
        );
        await test(
          "grows with the request size",
          func() : async () {
            let base = Call.httpRequestFromArgs(request).getCost();
            expect.nat(Call.httpRequestFromArgs({ request with headers; body }).getCost()).greater(base);
          },
        );
        await test(
          "narrows with max_response_bytes",
          func() : async () {
            let base = Call.httpRequestFromArgs(request).getCost();
            expect.nat(Call.httpRequestFromArgs({ request with max_response_bytes }).getCost()).less(base);
          },
        );
        await test(
          "narrows with expected usage",
          func() : async () {
            let builder = Call.httpRequestFromArgs(request);
            let narrowed = builder
              .withExpectedRoundtripTimeMs(300)
              .withExpectedRawResponseBytes(100)
              .withExpectedTransformedResponseBytes(100)
              .getCost();
            expect.nat(narrowed).less(builder.getCost());
          },
        );
        await test(
          "reserves transform instructions only with a transform",
          func() : async () {
            let base = Call.httpRequestFromArgs(request).getCost();
            let withTransform = Call.httpRequestFromArgs({ request with transform });
            expect.nat(withTransform.getCost()).greater(base);
            expect.nat(withTransform.withExpectedTransformInstructions(1_000).getCost()).less(withTransform.getCost());
          },
        );
        await test(
          "is lower for a non-replicated outcall",
          func() : async () {
            let builder = Call.httpRequestFromArgs(request);
            expect.nat(builder.nonReplicated().getCost()).less(builder.getCost());
          },
        );
        await test(
          "matches Cost.httpRequest",
          func() : async () {
            let builder = Call.httpRequestFromArgs(request).withExpectedRoundtripTimeMs(300);
            expect.nat(builder.getCost()).equal(Call.Cost.httpRequest(builder.args(), { Call.Cost.worstCase with roundtripTimeMs = ?300 }));
          },
        );
      },
    );

    await suite(
      "cost matches the system API on the specified parameters",
      func() : async () {
        await test(
          "default reservation",
          func() : async () {
            expect.nat(Call.httpRequestFromArgs(request).getCost()).equal(systemCost(worstCaseParams(15, null)));
          },
        );
        await test(
          "expected usage, field by field",
          func() : async () {
            let cost = Call.httpRequest(request.url)
              .withExpectedRoundtripTimeMs(300)
              .withExpectedRawResponseBytes(1_000)
              .withExpectedTransformedResponseBytes(2_000)
              .withExpectedTransformInstructions(7_000_000)
              .getCost();
            let params = {
              request_bytes : Nat64 = 15;
              http_roundtrip_time_ms : Nat64 = 300;
              raw_response_bytes : Nat64 = 1_000;
              transformed_response_bytes : Nat64 = 2_000;
              transform_instructions : Nat64 = 7_000_000;
              outcall_type = null;
            };
            expect.nat(cost).equal(systemCost(params));
          },
        );
        await test(
          "non-replicated",
          func() : async () {
            let cost = Call.httpRequestFromArgs(request).nonReplicated().getCost();
            expect.nat(cost).equal(systemCost(worstCaseParams(15, ?(#non_replicated(null)))));
          },
        );
        await test(
          "request bytes in UTF-8",
          func() : async () {
            // 17 characters, 18 bytes.
            let cost = Call.httpRequest("https://ic0.app/ü").getCost();
            expect.nat(cost).equal(systemCost(worstCaseParams(18, null)));
          },
        );
        await test(
          "flexible, with transformed bytes capped by min_responses",
          func() : async () {
            let counts = { min_responses : Nat32 = 2; max_responses : Nat32 = 3; total_requests : Nat32 = 3 };
            let cost = Call.flexibleHttpRequest(request.url).withReplication(counts).getCost();
            let params = { worstCaseParams(15, ?(#flexible_(?counts))) with transformed_response_bytes : Nat64 = 1_048_576 };
            expect.nat(cost).equal(systemCost(params));
          },
        );
        await test(
          "flexible, with the endpoint's default replication",
          func() : async () {
            let cost = Call.flexibleHttpRequest(request.url).getCost();
            expect.nat(cost).equal(systemCost(worstCaseParams(15, ?(#flexible_(null)))));
          },
        );
      },
    );

    await suite(
      "flexible_http_request cost",
      func() : async () {
        await test(
          "is positive with the endpoint's default replication",
          func() : async () {
            expect.nat(Call.flexibleHttpRequest(request.url).getCost()).greater(0);
          },
        );
        await test(
          "grows with the number of requests",
          func() : async () {
            let builder = Call.flexibleHttpRequestFromArgs(flexibleRequest);
            let more = builder.withReplication({ min_responses = 2; max_responses = 5; total_requests = 5 });
            expect.nat(more.getCost()).greater(builder.getCost());
          },
        );
        await test(
          "narrows with expected usage",
          func() : async () {
            let builder = Call.flexibleHttpRequestFromArgs(flexibleRequest);
            expect.nat(builder.withExpectedRoundtripTimeMs(300).getCost()).less(builder.getCost());
          },
        );
        await test(
          "caps transformed bytes by min_responses",
          func() : async () {
            let builder = Call.flexibleHttpRequestFromArgs(flexibleRequest);
            let uncapped = builder.withExpectedTransformedResponseBytes(2_000_000 + 1_024).getCost();
            expect.nat(builder.getCost()).less(uncapped);
          },
        );
        await test(
          "is positive for a fire-and-forget outcall",
          func() : async () {
            let builder = Call.flexibleHttpRequestFromArgs(flexibleRequest).withReplication({ min_responses = 0; max_responses = 0; total_requests = 3 });
            expect.nat(builder.getCost()).greater(0);
          },
        );
      },
    );
  };

  // The argument of `ic0.cost_http_request_v2`, as the interface specification defines it.
  type CostParams = {
    request_bytes : Nat64;
    http_roundtrip_time_ms : Nat64;
    raw_response_bytes : Nat64;
    transformed_response_bytes : Nat64;
    transform_instructions : Nat64;
    outcall_type : ?{
      #fully_replicated : Any;
      #non_replicated : Any;
      #flexible_ : ?Call.ReplicationCounts;
    };
  };

  func systemCost(params : CostParams) : Nat = Prim.costHttpRequestV2(to_candid (params));

  // The specified maxima for a request without `max_response_bytes` or a transform.
  func worstCaseParams(requestBytes : Nat64, outcallType : ?{ #fully_replicated : Any; #non_replicated : Any; #flexible_ : ?Call.ReplicationCounts }) : CostParams = {
    request_bytes = requestBytes;
    http_roundtrip_time_ms = 60_000;
    raw_response_bytes = 2_000_000;
    transformed_response_bytes = 2_001_024;
    transform_instructions = 0;
    outcall_type = outcallType;
  };

  public shared query func transformFunction({
    context : Blob;
    response : IC.HttpRequestResult;
  }) : async IC.HttpRequestResult {
    ignore context;
    { response with headers = []; status = 200 };
  };

  let request : IC.HttpRequestArgs = {
    url = "https://ic0.app";
    method = #get;
    headers = [];
    body = null;
    max_response_bytes = null;
    transform = null;
    is_replicated = null;
    pricing_version = null;
  };
  let flexibleRequest : IC.FlexibleHttpRequestArgs = {
    url = "https://ic0.app";
    method = #get;
    headers = [];
    body = null;
    max_response_bytes = null;
    transform = null;
    replication = ?{ min_responses = 2; max_responses = 3; total_requests = 3 };
  };
  let headers = [{ name = "x-test"; value = "test" }];
  let body = ?to_candid ([1, 2, 3]);
  let max_response_bytes : ?Nat64 = ?1_000;
  let transform = ?{
    function = transformFunction;
    context = Blob.fromArray([23, 41, 13, 6, 17]);
  };
};
