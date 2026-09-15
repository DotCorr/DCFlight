# Navigation observation ownership

Static native navigation wrappers pass the shared model reference to their leaf views without subscribing to every model edit. Routes and native stacks still observe their own navigation state; input/text/conditional/collection nodes retain model observation. Root media presentation retains observation of nativePhotoRequest.

This avoids invalidating the native navigation/hosting hierarchy for unrelated text edits. Model replacement still changes the passed view input normally. It does not remove shared logic, create local copies of business state, or add a runtime layer.

The candidate requires fresh rapid-input A/B and navigation/media regression evidence before promotion. Previous generated navigation fixtures intermittently lost initial burst characters while later focused suffix bursts passed. A hand-written SwiftUI control passed the sampled input. This change is a hypothesis-driven ownership correction, not yet a proven resolution.
