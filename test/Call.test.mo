import Blob "mo:core/Blob";
import Principal "mo:core/Principal";
import Result "mo:core/Result";
import Runtime "mo:core/Runtime";
import { suite; test; expect } "mo:test/async";
import ExpectResult "mo:test/expect/expect-result";

import { ic } "../src";
import IC "../src/Types";
import Call "../src/Call";

actor {
  public shared ({ caller }) func runTests() : async () {
    await test(
      "createCanister should succeed",
      func() : async () {
        ignore await Call.createCanister(createCanisterArgs);
      },
    );

    await test(
      "create_canister cost should be exact",
      func() : async () {
        let cycles = Call.Cost.createCanister();
        ignore await (with cycles) ic.create_canister(createCanisterArgs);
        await expect.call(
          func() : async () {
            ignore await (with cycles = cycles - 1) ic.create_canister(createCanisterArgs);
          }
        ).reject();
      },
    );

    await test(
      "httpRequest should succeed",
      func() : async () {
        ignore await Call.httpRequest(request);
        ignore await Call.httpRequest({ request with headers });
        ignore await Call.httpRequest({ request with body });
        ignore await Call.httpRequest({ request with max_response_bytes });
        ignore await Call.httpRequest({
          request with headers;
          body;
          max_response_bytes;
        });
        ignore await Call.httpRequest({ request with transform });
      },
    );

    await suite(
      "http_request cost should be exact",
      func() : async () {
        await test("default", httpRequestExactCost(request));
        await test("with headers", httpRequestExactCost({ request with headers }));
        await test("with body", httpRequestExactCost({ request with body }));
        await test("with max_response_bytes", httpRequestExactCost({ request with max_response_bytes }));
        await test("with all above", httpRequestExactCost({ request with headers; body; max_response_bytes }));

        // Future work: transform can't be exact yet
        // await test("with transform", httpRequestExactCost({ request with transform }));
      },
    );

    await test(
      "trySignWithEcdsa should succeed",
      func() : async () {
        ignore await Call.signWithEcdsa(ecdsaArgs(caller, #secp256k1, "dfx_test_key"));
        expectResult(await Call.trySignWithEcdsa(ecdsaArgs(caller, #secp256k1, "dfx_test_key"))).isOk();
        expectResult(await Call.trySignWithEcdsa(ecdsaArgs(caller, #secp256k1, "wrong key"))).equal(#err(#invalidKeyName));
      },
    );

    await test(
      "sign_with_ecdsa cost should be exact",
      func() : async () {
        let args = ecdsaArgs(caller, #secp256k1, "dfx_test_key");
        let (#ok cycles) = Call.Cost.signWithEcdsa(args.key_id.name, args.key_id.curve) else Runtime.trap("cost of sign_with_ecdsa should succeed");
        ignore await (with cycles) ic.sign_with_ecdsa(args);
        await expect.call(
          func() : async () {
            ignore await (with cycles = cycles - 1) ic.sign_with_ecdsa(args);
          }
        ).reject();
      },
    );

    await test(
      "trySignWithSchnorr should succeed",
      func() : async () {
        ignore await Call.signWithSchnorr(schnorrArgs(caller, #bip340secp256k1, "dfx_test_key"));
        ignore await Call.signWithSchnorr(schnorrArgs(caller, #ed25519, "dfx_test_key"));
        expectResult(await Call.trySignWithSchnorr(schnorrArgs(caller, #bip340secp256k1, "dfx_test_key"))).isOk();
        expectResult(await Call.trySignWithSchnorr(schnorrArgs(caller, #ed25519, "dfx_test_key"))).isOk();
        expectResult(await Call.trySignWithSchnorr(schnorrArgs(caller, #ed25519, "wrong key"))).equal(#err(#invalidKeyName));
      },
    );

    await test(
      "sign_with_schnorr cost should be exact",
      func() : async () {
        let args = schnorrArgs(caller, #ed25519, "dfx_test_key");
        let (#ok cycles) = Call.Cost.signWithSchnorr(args.key_id.name, args.key_id.algorithm) else Runtime.trap("cost of sign_with_schnorr should succeed");
        ignore await (with cycles) ic.sign_with_schnorr(args);
        await expect.call(
          func() : async () {
            ignore await (with cycles = cycles - 1) ic.sign_with_schnorr(args);
          }
        ).reject();
      },
    );
  };

  func httpRequestExactCost(request : IC.HttpRequestArgs) : () -> async () = func() : async () {
    let cycles = Call.Cost.httpRequest(request);
    ignore await (with cycles) ic.http_request(request);
    await expect.call(
      func() : async () {
        ignore await (with cycles = cycles - 1) ic.http_request(request);
      }
    ).reject();
  };

  func expectResult<Ok, Err>(result : Result.Result<Ok, Err>) : ExpectResult.ExpectResult<Ok, Err> = expect.result<Ok, Err>(
    result,
    func r = switch r {
      case (#ok _) "ok";
      case (#err _) "err";
    },
    func(a, b) = switch (a, b) {
      case (#ok _, #ok _) true;
      case (#err _, #err _) true;
      case _ false;
    },
  );

  public shared query func transformFunction({
    context : Blob;
    response : IC.HttpRequestResult;
  }) : async IC.HttpRequestResult {
    ignore context;
    { response with headers = []; status = 200 };
  };

  let createCanisterArgs : IC.CreateCanisterArgs = {
    settings = null;
    sender_canister_version = null;
  };

  let request : IC.HttpRequestArgs = {
    url = "https://ic0.app";
    method = #get;
    headers = [];
    body = null;
    max_response_bytes = null;
    transform = null;
    is_replicated = null;
  };
  let headers = [{ name = "x-test"; value = "test" }];
  let body = ?to_candid ([1, 2, 3]);
  let max_response_bytes : ?Nat64 = ?1_000;
  let transform = ?{
    function = transformFunction;
    context = Blob.fromArray([23, 41, 13, 6, 17]);
  };
  let fakeMessageHash = Blob.fromArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32]);

  func ecdsaArgs(caller : Principal, curve : IC.EcdsaCurve, keyName : Text) : IC.SignWithEcdsaArgs = {
    derivation_path = [caller.toBlob()];
    key_id = { curve; name = keyName };
    message_hash = fakeMessageHash;
  };

  func schnorrArgs(caller : Principal, algorithm : IC.SchnorrAlgorithm, keyName : Text) : IC.SignWithSchnorrArgs = {
    derivation_path = [caller.toBlob()];
    key_id = { algorithm; name = keyName };
    message = fakeMessageHash;
    aux = null;
  };
};
