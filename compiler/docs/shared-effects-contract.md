# Shared event/effect emission contract

Extends routed authoring version 2 with `flowActions` and optional `transport`.
Product choices live in shared authoring and DC Dart. Backends only emit native execution.

Canonical types in dcflight/flow_ir.py (root-owned):
- FlowAction(id, function: Optional[str], arguments: tuple[Expression | Projection], cases: tuple[FlowCase])
- Projection(operation, value: Reference): operations `length` (Unicode scalar count), `utf8Length`.
- FlowCase(code: int, effects: tuple[Effect])
- SetEffect(target: str, value: Expression)
- NavigateEffect(action: str): declared navigation action id
- RequestEffect(id: str, method: str, path: str, body: tuple[(str, Expression)], bearer: Optional[Reference], outputs: tuple[ResponseOutput], success: str, failure: str, status_target: Optional[str])
- ResponseOutput(target: str, path: tuple[str,...]) projects a required scalar JSON field; type derives from target state. All outputs validate before any is assigned.
- SecureEffect(operation: str, key: str, target: str, failure: str) operation read/write/delete; target string state; native secure store. Failure stops the sequence and invokes the authored failure action; missing secure keys read as an empty string. Stores are scoped to app identity and transport origin. Secrets are not serialized into UI state restoration bundles.
- InvokeEffect(action): terminal direct call to a declared flow; synchronous cycles fail validation.
- CancelEffect(): explicit cancellation and invalidation of pending responses.
- Optional initialAction dispatches once for the root model lifetime.
- Transport(base_url: str, development: bool)

Flow actions without function have exactly one case code 0 (unconditional shared sequence). With function, call declared DC Dart ABI int32/uint32/bool with typed args/projections and switch returned code. Unknown code throws internal failure; no invented user copy. Request effects must be last in case, completion dispatches declared flow action. Distinct requests serial per model: generation counter invalidates stale completions; invoking a new request supersedes earlier. UI closures dispatch `model.f_ID(navigate)` where navigate accepts navigation action id and handles current host. Completion stays on main thread. All local effects emitted directly, not runtime graph interpreter. Requests async via URLSession / executor+HttpURLConnection; no redirect following; 25s timeout; max 8MiB response; JSON scalars only. Error text always shared authoring. Bind status code to status_target (0 transport/decode failure), then dispatch failure. Success status 200..299; missing/wrong response fields failure before state mutation.

JSON:
flowActions: [{id, function?, arguments?: [literal/ref/{length:{ref:'x'}}/{utf8Length:{ref:'x'}}], cases:[{code:0,effects:[{op:'set',target:'busy',value:true},{op:'request',id:'login',method:'POST',path:'/v1/auth/login',body:{username:{ref:'username'}},outputs:{token:['token']},success:'authenticated',failure:'failed',statusTarget:'status'}]}]}]
Effects navigate: {op:'navigate',action:'home'}; secure: {op:'secure',operation:'write',key:'session',target:'token',failure:'storageFailed'}.
transport: {baseUrl:'http://localhost:8765',development:true} (HTTP only loopback explicit development; Android emulator translates localhost to10.0.2.2).
Native UI secureField primitive and enabledWhen bool binding will be added by root. Native agents implement hooks accordingly.

This does not define arbitrary collections, media streams or async DC Dart suspension. Those must be added explicitly before Snap feature migration can be complete.
