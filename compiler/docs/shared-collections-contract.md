# Typed collections for shared Snap screens

Next extension to routed authoring; retain the scalar event/effect path.

Canonical in collection_ir.py:
- CollectionField(name:str,type:ScalarType,default:Optional[Literal]=None)
- Collection(name:str,key:str,fields:tuple[CollectionField,...]); initially empty native list, unique key required per decoded response.
- FieldReference(collection:str,field:str,type:ScalarType) expression within that collection's repeated row only.
RoutedApplication.collections:tuple[Collection,...].
JSON `collections:[{name:'people',key:'id',fields:{id:{type:'string'},display_name:{type:'string',default:''}}}]`.
New node `repeat`: props `{collection:'people',selection:{ref:'selectedPerson'}}`, optional action references flow action, one authored child row. `selection` and action either both present or neither. Selection state must match key field type; collection key is string/int. A selectable row emits a native button, sets selection then invokes authored flow action. Row data uses `{field:{collection:'people',name:'display_name'}}`; no implicit state/field capture. Nested repeat initially rejected. All row layout/copy remain shared nodes. Collection key + explicit template node ID supplies stable repeated identity.

RequestEffect.outputs may target scalar states OR collections. Native emitters decode arrays to native typed records, apply declared defaults only to missing/null fields, reject wrong scalar types, missing required fields and duplicate keys, validate all outputs before any assignment.

RequestEffect.path supports a string OR PathTemplate(parts:tuple[Expression,...]); JSON list of strings and state refs. First part must be literal beginning / (not //); literal segments cannot contain #/control/backslash, refs percent-encoded as one path/query value using UTF8 RFC3986 unreserved only. Shared RequestEffect Dart path Object accepts List<Object>. Projection states only; no runtime IR evaluation.

Dart Collection(name:,key:,fields:{'id':CollectionField(type:'string'),...}); FieldRef<T>(collection:,name:); Repeat(id:,collection:,child:,Ref? selection, String? action). Existing Text.bind should accept FieldRef<String> as well as Ref<String>; use a common typed authoring Reference<T> interface if needed. No complete Snap migration claim until native emitters and app flows use this extension.

The Dart API serializes `CollectionField(defaultValue: ...)` to canonical `default` (Dart reserves `default`). `Text.bind` accepts the common `Reference<String>` interface implemented by `Ref<String>` and `FieldRef<String>`. Writable controls continue to require ordinary state `Ref`; collection fields are immutable response data. `Repeat(selection:, action:)` requires a declared flow action, and both arguments must be supplied together. The selector receives the key through explicitly named scalar state.

Lowering preserves `FieldReference` in canonical node properties/visibility and does not add hidden application state. Rows cannot reference another collection or nest repeats. Collection names cannot collide with scalar state; field/key/default types are validated before generation. Native emitters remain responsible for validating response contents before assigning decoded arrays. Tests of authoring/IR alone do not establish network or native execution.

`RequestEffect(path: ['/v1/people/', const Ref<String>(name: 'selected')])` generates a `PathTemplate`; references are explicitly state reads, not arbitrary Dart interpolation evaluated at app runtime. Collection output paths currently require a nonempty JSON object projection such as `outputs: {'people': ['users']}`; a bare root-array response is unsupported. No automatic pagination, record mutation effect, or complete Snap feature migration is implied by collection support.

Append and session lifecycle are now explicit typed effects:

- `ResponseCollection(path: ['messages'], mode: 'append')` is allowed only for collection outputs. The canonical `ResponseOutput.mode` defaults to `replace` for legacy path lists. Native adapters validate the complete incoming page and reject collisions with already stored keys before assigning any output.
- `ClearCollectionEffect(target: 'messages')` empties a named list. Auth transitions explicitly clear private collections and selected scalar identifiers in the shared app source.
- `NavigationAction.resetRoot('login', id: 'showLogin')` exits the entire authenticated navigation shell. It requires one root `NavigationStack`; top-level independent tabs cannot claim root-reset behavior.

The shared Snap example now uses these facilities for real friend requests, friend lists and bidirectional text conversation flows. Message reads append explicit cursor pages; there is no automatic polling or push notification claim. `tools/verify_snap_shared_flow.py` executes the generated native model and shared DC Dart object against an isolated real service using two accounts, then deletes both accounts. This is native model/network evidence, separate from mobile UI execution. Camera/photo capture, stories and map remain outside this migrated shared example at this checkpoint.
