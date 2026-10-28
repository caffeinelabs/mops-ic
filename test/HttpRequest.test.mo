import Blob "mo:core/Blob";
import Nat32 "mo:core/Nat32";
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
