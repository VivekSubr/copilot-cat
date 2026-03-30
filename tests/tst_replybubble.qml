import QtQuick
import QtTest

TestCase {
    id: tc
    name: "ReplyBubble"
    when: windowShown

    Component {
        id: bubbleComp
        Item {
            id: root
            property string message: ""
            width: 300; height: 200

            Loader {
                id: loader
                source: "file:///" + qmlPath + "/ReplyBubble.qml"
                onLoaded: {
                    item.parent = root
                    item.message = "Test selectable text"
                    item.show("Test selectable text")
                }
            }
        }
    }

    function test_textEditExists() {
        var wrapper = createTemporaryObject(bubbleComp, tc)
        verify(wrapper, "Wrapper created")
        wait(200)

        var bubble = wrapper.children[0].item
        verify(bubble, "ReplyBubble loaded")

        // Find TextEdit by traversing children
        var textEdit = findTextEdit(bubble)
        verify(textEdit, "TextEdit element found in ReplyBubble")
    }

    function test_textIsReadOnly() {
        var wrapper = createTemporaryObject(bubbleComp, tc)
        wait(200)
        var bubble = wrapper.children[0].item
        var textEdit = findTextEdit(bubble)
        verify(textEdit, "TextEdit found")
        compare(textEdit.readOnly, true, "TextEdit is readOnly")
    }

    function test_textIsSelectableByMouse() {
        var wrapper = createTemporaryObject(bubbleComp, tc)
        wait(200)
        var bubble = wrapper.children[0].item
        var textEdit = findTextEdit(bubble)
        verify(textEdit, "TextEdit found")
        compare(textEdit.selectByMouse, true, "TextEdit has selectByMouse")
    }

    function test_selectionColorsSet() {
        var wrapper = createTemporaryObject(bubbleComp, tc)
        wait(200)
        var bubble = wrapper.children[0].item
        var textEdit = findTextEdit(bubble)
        verify(textEdit, "TextEdit found")
        verify(textEdit.selectedTextColor !== undefined, "selectedTextColor is set")
        verify(textEdit.selectionColor !== undefined, "selectionColor is set")
    }

    // Helper: recursively find first TextEdit child
    function findTextEdit(item) {
        if (!item) return null
        // Check if this item is a TextEdit (has readOnly and selectByMouse properties)
        if (item.hasOwnProperty("readOnly") && item.hasOwnProperty("selectByMouse"))
            return item
        for (var i = 0; i < item.children.length; i++) {
            var result = findTextEdit(item.children[i])
            if (result) return result
        }
        return null
    }
}
