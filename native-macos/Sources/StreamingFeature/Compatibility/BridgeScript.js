(function () {
  if (window.nativeStreamingBridge) {
    return;
  }

  function post(message) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamingBridge) {
      window.webkit.messageHandlers.streamingBridge.postMessage(message);
    }
  }

  window.nativeStreamingBridge = {
    notifyNativeReady: function () {
      post({ type: "native-ready" });
    },
    emitIceCandidate: function (candidate) {
      post({ type: "ice-candidate", payload: candidate });
    },
    emitAnswer: function (answer) {
      post({ type: "answer", payload: answer });
    },
    emitInputEvent: function (payload) {
      post({ type: "input-event", payload: payload });
    },
    requestFullscreen: function () {
      post({ type: "request-fullscreen" });
    },
    updateOverlayState: function (payload) {
      post({ type: "overlay-state", payload: payload });
    }
  };

  document.dispatchEvent(new CustomEvent("native-streaming-bridge-ready"));
})();
