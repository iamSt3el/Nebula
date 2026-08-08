import QtQuick
import Quickshell

ShellRoot {
	LockContext {
		id: lockContext
		// Preview harness has no WlSessionLock, so drive `active` directly
		active: true
		onUnlocked: Qt.quit();
	}

	FloatingWindow {
		LockSurface {
			anchors.fill: parent
			context: lockContext
		}
	}

	// exit the example if the window closes
	Connections {
		target: Quickshell

		function onLastWindowClosed() {
			Qt.quit();
		}
	}
}
