import QtQuick
import QtTest

TestCase {
    id: tc
    name: "SvgAssets"
    when: windowShown

    property string base: assetPath + "/"

    // --- Variant A walk SVGs ---

    function test_walkA_right_frames_exist() {
        for (var i = 1; i <= 4; i++) {
            var img = Qt.createQmlObject(
                'import QtQuick; Image { source: "file:///' + base + 'cat_walk' + i + '.svg" }', tc)
            verify(img.status !== Image.Error, "cat_walk" + i + ".svg loads")
            img.destroy()
        }
    }

    function test_walkA_left_frames_exist() {
        for (var i = 1; i <= 4; i++) {
            var img = Qt.createQmlObject(
                'import QtQuick; Image { source: "file:///' + base + 'cat_walk' + i + '_left.svg" }', tc)
            verify(img.status !== Image.Error, "cat_walk" + i + "_left.svg loads")
            img.destroy()
        }
    }

    // --- Variant A tail swish SVGs ---

    function test_tailSwishA_frames_exist() {
        for (var i = 1; i <= 4; i++) {
            var img = Qt.createQmlObject(
                'import QtQuick; Image { source: "file:///' + base + 'cat_tail_swish' + i + '.svg" }', tc)
            verify(img.status !== Image.Error, "cat_tail_swish" + i + ".svg loads")
            img.destroy()
        }
    }

    // --- Variant B walk SVGs ---

    function test_walkB_right_frames_exist() {
        for (var i = 1; i <= 8; i++) {
            var img = Qt.createQmlObject(
                'import QtQuick; Image { source: "file:///' + base + 'cat_walk_b' + i + '.svg" }', tc)
            verify(img.status !== Image.Error, "cat_walk_b" + i + ".svg loads")
            img.destroy()
        }
    }

    function test_walkB_left_frames_exist() {
        for (var i = 1; i <= 8; i++) {
            var img = Qt.createQmlObject(
                'import QtQuick; Image { source: "file:///' + base + 'cat_walk_b' + i + '_left.svg" }', tc)
            verify(img.status !== Image.Error, "cat_walk_b" + i + "_left.svg loads")
            img.destroy()
        }
    }

    // --- Variant B tail swish SVGs ---

    function test_tailSwishB_frames_exist() {
        for (var i = 1; i <= 8; i++) {
            var img = Qt.createQmlObject(
                'import QtQuick; Image { source: "file:///' + base + 'cat_tail_swish_b' + i + '.svg" }', tc)
            verify(img.status !== Image.Error, "cat_tail_swish_b" + i + ".svg loads")
            img.destroy()
        }
    }

    // --- Static pose SVGs ---

    function test_static_poses_exist() {
        var poses = ["cat_idle", "cat_sit", "cat_stretch", "cat_jump", "cat_pounce", "cat_land"]
        for (var p = 0; p < poses.length; p++) {
            var img = Qt.createQmlObject(
                'import QtQuick; Image { source: "file:///' + base + poses[p] + '.svg" }', tc)
            verify(img.status !== Image.Error, poses[p] + ".svg loads")
            img.destroy()
        }
    }
}
