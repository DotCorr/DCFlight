/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

/**
 * Pure Kotlin tag keys for View tags - NO XML resources needed!
 * Uses String hashCode for unique, stable tag IDs
 * 
 * This eliminates all XML resource dependencies while maintaining
 * the same functionality as R.id-based tags
 */
object DCFTags {
    // Tag key strings
    const val VIEW_ID = "dcf_view_id"
    const val EVENT_TYPES = "dcf_event_types"
    const val EVENT_CALLBACK = "dcf_event_callback"
    const val STORED_PROPS = "dcf_stored_props"
    const val COMPONENT_TYPE = "dcf_component_type"
    
    // Generate stable integer keys from strings (for View.setTag(int, Object))
    val VIEW_ID_KEY = VIEW_ID.hashCode()
    val EVENT_TYPES_KEY = EVENT_TYPES.hashCode()
    val EVENT_CALLBACK_KEY = EVENT_CALLBACK.hashCode()
    val STORED_PROPS_KEY = STORED_PROPS.hashCode()
    val COMPONENT_TYPE_KEY = COMPONENT_TYPE.hashCode()
}

