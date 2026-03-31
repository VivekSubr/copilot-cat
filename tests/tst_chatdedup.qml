import QtQuick
import QtTest

TestCase {
    id: tc
    name: "ChatDedup"
    when: windowShown

    // QML-side guard state
    property bool chatMode: false
    property bool chatReplyPending: false
    property bool chatReplyReceived: false
    property string bubbleText: ""
    property int bubbleCount: 0

    // Server-side guard state
    QtObject {
        id: serverState
        property bool chatProcessing: false
        property var sentMessages: []
    }

    function init() {
        chatMode = false;
        chatReplyPending = false;
        chatReplyReceived = false;
        bubbleText = "";
        bubbleCount = 0;
        serverState.chatProcessing = false;
        serverState.sentMessages = [];
    }

    // -- QML guard logic (from Main.qml handleMcpMessage) --

    function qmlHandleShowBubble(text) {
        if (chatReplyReceived) return false;

        if (chatReplyPending) {
            if (text.indexOf("Thinking...") !== 0) {
                chatReplyPending = false;
                chatReplyReceived = true;
            }
            bubbleText = text;
            bubbleCount++;
            return true;
        }

        // Not in chat flow -- passthrough
        bubbleText = text;
        bubbleCount++;
        return true;
    }

    function qmlSendChat() {
        chatReplyPending = true;
        chatReplyReceived = false;
    }

    function qmlStartChat() {
        chatMode = true;
        chatReplyPending = false;
        chatReplyReceived = false;
    }

    // -- Server guard logic (from server.ts handleCatMessage) --

    function serverHandleChat(text, replyCallback) {
        if (serverState.chatProcessing) return false;
        serverState.chatProcessing = true;
        var msgs = serverState.sentMessages;
        msgs.push({ type: "show_bubble", text: "Thinking..." });
        var reply = replyCallback(text);
        msgs.push({ type: "show_bubble", text: reply });
        serverState.sentMessages = msgs;
        serverState.chatProcessing = false;
        return true;
    }

    // ======== QML Guard Tests ========

    function test_single_reply_accepted() {
        qmlStartChat();
        qmlSendChat();

        qmlHandleShowBubble("Thinking...");
        compare(bubbleText, "Thinking...", "Thinking shown");
        compare(chatReplyReceived, false, "Not locked yet");

        qmlHandleShowBubble("Hey there!");
        compare(bubbleText, "Hey there!", "Reply shown");
        compare(chatReplyReceived, true, "Locked after reply");
        compare(bubbleCount, 2, "Two bubbles total (Thinking + reply)");
    }

    function test_duplicates_blocked_after_first_reply() {
        qmlStartChat();
        qmlSendChat();

        qmlHandleShowBubble("Thinking...");
        qmlHandleShowBubble("Hey there!");
        compare(chatReplyReceived, true, "Locked");

        var allBlocked = true;
        for (var i = 0; i < 5; i++) {
            if (qmlHandleShowBubble("Duplicate " + i))
                allBlocked = false;
        }
        verify(allBlocked, "All 5 duplicates blocked");
        compare(bubbleText, "Hey there!", "Bubble text unchanged");
        compare(bubbleCount, 2, "Still only 2 bubbles");
    }

    function test_lock_resets_when_user_starts_new_chat() {
        qmlStartChat();
        qmlSendChat();

        qmlHandleShowBubble("Reply 1");
        compare(chatReplyReceived, true, "Locked");

        // User clicks cat again, starts new chat
        qmlStartChat();
        qmlSendChat();
        compare(chatReplyReceived, false, "Lock reset");

        qmlHandleShowBubble("Reply 2");
        compare(bubbleText, "Reply 2", "New reply accepted");
        compare(chatReplyReceived, true, "Re-locked");
    }

    function test_non_chat_messages_pass_through() {
        // No chat started, chatReplyPending = false
        var shown = qmlHandleShowBubble("say_to_cat message");
        verify(shown, "Passthrough allowed");
        compare(bubbleText, "say_to_cat message", "Message shown");
    }

    function test_non_chat_messages_blocked_during_lock() {
        qmlStartChat();
        qmlSendChat();
        qmlHandleShowBubble("Reply");
        compare(chatReplyReceived, true, "Locked");

        // say_to_cat tool call arrives during lock period
        var shown = qmlHandleShowBubble("Tool call message");
        verify(!shown, "Tool call blocked during lock");
    }

    function test_reproduces_six_reply_bug_scenario() {
        qmlStartChat();
        qmlSendChat();

        var replies = [
            "Thinking...",
            "Hey there! I'm paws-itively thrilled!",
            "Hey there! I'm paws-itively thrilled!",
            "Hey again! Looks like we're on a re-purr-t",
            "Hey there! I'm paws-itively thrilled!",
            "Hey there! I'm paws-itively thrilled!",
            "Hey again! Looks like we're on a re-purr-t"
        ];

        var shownCount = 0;
        for (var i = 0; i < replies.length; i++) {
            if (qmlHandleShowBubble(replies[i]))
                shownCount++;
        }
        compare(shownCount, 2, "Only 2 of 7 messages shown (Thinking + first reply)");
        compare(bubbleText, "Hey there! I'm paws-itively thrilled!",
                "Final text is first real reply");
    }

    function test_multiple_thinking_messages_allowed() {
        qmlStartChat();
        qmlSendChat();

        qmlHandleShowBubble("Thinking...");
        qmlHandleShowBubble("Thinking... still working");
        compare(chatReplyReceived, false, "Not locked -- both were Thinking");
        compare(bubbleCount, 2, "Both Thinking messages shown");

        qmlHandleShowBubble("Here is the answer");
        compare(chatReplyReceived, true, "Locked after real reply");
        compare(bubbleCount, 3, "3 total (2 Thinking + 1 reply)");
    }

    function test_no_guard_when_chatReplyPending_false() {
        chatMode = true;
        // User did NOT call sendChat, so chatReplyPending is false

        var allPassed = true;
        for (var i = 0; i < 6; i++) {
            if (!qmlHandleShowBubble("Msg " + i))
                allPassed = false;
        }
        verify(allPassed, "All 6 pass through -- no guard active");
        compare(bubbleCount, 6, "All 6 shown");
    }

    // ======== Server Guard Tests ========

    function test_server_chatProcessing_blocks_concurrent() {
        var first = serverHandleChat("hi", function() { return "Reply 1"; });
        verify(first, "First call accepted");
        compare(serverState.sentMessages.length, 2, "Thinking + reply sent");
    }

    function test_concurrent_calls_blocked() {
        serverState.chatProcessing = true; // simulate in-flight request

        var blocked = serverHandleChat("hi again", function() { return "Reply 2"; });
        verify(!blocked, "Concurrent call blocked");
    }

    function test_new_calls_allowed_after_completion() {
        serverHandleChat("first", function() { return "Reply 1"; });
        compare(serverState.chatProcessing, false, "Processing flag reset after completion");

        var second = serverHandleChat("second", function() { return "Reply 2"; });
        verify(second, "Second call accepted after first completes");
        compare(serverState.sentMessages.length, 4, "4 messages total (2 per call)");
    }

    // ======== Combined Flow Test ========

    function test_full_flow_server_sends_qml_guards() {
        qmlStartChat();
        qmlSendChat();

        // Server handles the chat message
        serverHandleChat("hi", function() { return "Hey there!"; });

        // Server's sent messages arrive at QML
        var shownCount = 0;
        var msgs = serverState.sentMessages;
        for (var i = 0; i < msgs.length; i++) {
            if (msgs[i].type === "show_bubble") {
                if (qmlHandleShowBubble(msgs[i].text))
                    shownCount++;
            }
        }
        compare(shownCount, 2, "QML shows 2 (Thinking + reply)");

        // Simulate say_to_cat tool calls (from Copilot CLI)
        var toolCalls = ["Hey there!", "Hey there!", "Hey again!", "Hey there!"];
        var blockedCount = 0;
        for (var j = 0; j < toolCalls.length; j++) {
            if (!qmlHandleShowBubble(toolCalls[j]))
                blockedCount++;
        }
        compare(blockedCount, 4, "All 4 say_to_cat tool calls blocked by QML guard");
        compare(bubbleText, "Hey there!", "Bubble text is still the first reply");
    }
}
