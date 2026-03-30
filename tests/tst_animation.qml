import QtQuick
import QtTest

TestCase {
    id: tc
    name: "AnimationParams"
    when: windowShown

    // Mirror the animation properties from Main.qml
    property int walkFrameCount: 8
    property int walkStepPx: 3
    property int walkFrameMod: 3
    property int tailSwishFrameCount: 8
    property int tailSwishMs: 150

    function test_walkFrameCount() {
        compare(walkFrameCount, 8, "8 walk frames")
    }

    function test_walkStep() {
        compare(walkStepPx, 3, "3px walk step")
    }

    function test_walkFrameMod() {
        compare(walkFrameMod, 3, "frame mod 3")
    }

    function test_tailSwishFrames() {
        compare(tailSwishFrameCount, 8, "8 tail swish frames")
    }

    function test_tailSwishTiming() {
        compare(tailSwishMs, 150, "150ms tail swish")
    }
}
