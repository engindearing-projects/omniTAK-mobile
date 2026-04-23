package soy.engindearing.omnitak.mobile.domain

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import soy.engindearing.omnitak.mobile.data.Drawing

/**
 * In-memory roster of shapes the operator has drawn on the map. Kept
 * application-scoped so screens observe reactively; persistence to
 * DataStore is a follow-up once the format stabilizes.
 */
class DrawingStore {
    private val _drawings = MutableStateFlow<List<Drawing>>(emptyList())
    val drawings: StateFlow<List<Drawing>> = _drawings.asStateFlow()

    fun add(drawing: Drawing) {
        _drawings.value = _drawings.value + drawing
    }

    fun remove(id: String) {
        _drawings.value = _drawings.value.filterNot { it.id == id }
    }

    fun clear() {
        _drawings.value = emptyList()
    }
}
