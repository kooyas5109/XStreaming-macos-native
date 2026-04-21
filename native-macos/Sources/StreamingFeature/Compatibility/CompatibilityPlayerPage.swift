import Foundation
import SharedDomain

public struct CompatibilityPlayerPage: Sendable {
    let playerScript: String

    public init(playerScript: String) {
        self.playerScript = playerScript
    }

    public func html(for session: StreamingSession) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            html, body, #videoHolder {
              background: #050607;
              height: 100%;
              margin: 0;
              overflow: hidden;
              width: 100%;
            }
            video, canvas {
              height: 100% !important;
              object-fit: contain;
              width: 100% !important;
            }
            .status {
              color: rgba(255, 255, 255, 0.82);
              font: 14px -apple-system, BlinkMacSystemFont, sans-serif;
              left: 18px;
              position: fixed;
              top: 18px;
              z-index: 4;
            }
          </style>
        </head>
        <body>
          <div id="videoHolder"></div>
          <div class="status" id="status">Starting stream...</div>
          <script>
        \(escapedScript(playerScript))
          </script>
          <script>
        \(playerBootstrapScript(sessionID: session.id))
          </script>
        </body>
        </html>
        """
    }

    private func escapedScript(_ script: String) -> String {
        script.replacingOccurrences(of: "</script", with: "<\\/script")
    }

    private func playerBootstrapScript(sessionID: String) -> String {
        let encodedSessionID = Self.javascriptString(sessionID)
        return """
        (function () {
          const sessionID = \(encodedSessionID);
          const status = document.getElementById("status");
          let player = null;
          let remoteOfferApplied = false;
          let localIcePublished = false;

          function post(type, payload) {
            const bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamingBridge;
            if (bridge) {
              bridge.postMessage({ type, payload });
            }
          }

          function setStatus(message) {
            if (status) {
              status.textContent = message;
            }
            post("status", { sessionID, message });
          }

          function normalizeIceCandidate(candidate) {
            return {
              messageType: "iceCandidate",
              candidate: candidate.candidate || "",
              sdpMid: candidate.sdpMid || "0",
              sdpMLineIndex: String(candidate.sdpMLineIndex ?? 0)
            };
          }

          function playerConstructor() {
            return window.xStreamingPlayer || window.xstreamingPlayer;
          }

          async function publishLocalIceCandidates() {
            if (!player || !remoteOfferApplied || localIcePublished) {
              return;
            }
            const rawCandidates = player.getIceCandidates ? player.getIceCandidates() : [];
            const candidates = rawCandidates.map(normalizeIceCandidate).filter(candidate => candidate.candidate.length > 0);
            if (candidates.length > 0) {
              localIcePublished = true;
              setStatus("Sending local ICE candidates...");
              post("ice-candidates", { sessionID, candidates });
            } else {
              setStatus("Waiting for local ICE candidates...");
            }
          }

          window.xstreamingNativePlayer = {
            async start() {
              if (player) {
                return;
              }
              try {
                setStatus("Creating peer connection...");
                const Player = playerConstructor();
                if (!Player) {
                  throw new Error("xStreamingPlayer constructor is unavailable.");
                }
                player = new Player("videoHolder", {
                  input_touch: false,
                  ui_touchenabled: false,
                  input_mousekeyboard: false,
                  input_legacykeyboard: true
                });
                player.bind({});
                const offer = await player.createOffer();
                post("sdp-offer", { sessionID, sdp: offer.sdp || "" });
                setStatus("Waiting for console answer...");
              } catch (error) {
                setStatus("Failed to create stream offer.");
                post("error", { sessionID, message: String(error) });
              }
            },
            async setRemoteOffer(sdp) {
              if (!player) {
                post("error", { sessionID, message: "Player has not started." });
                return;
              }
              player.setRemoteOffer(sdp);
              remoteOfferApplied = true;
              setStatus("Negotiating network path...");
              window.setTimeout(publishLocalIceCandidates, 2000);
              window.setTimeout(function () {
                if (!localIcePublished) {
                  publishLocalIceCandidates();
                }
              }, 5000);
            },
            setIceCandidates(candidates) {
              if (player && candidates && candidates.length) {
                player.setIceCandidates(candidates);
                setStatus("Streaming.");
              }
            },
            setButton(button, phase) {
              if (!player) {
                return;
              }
              const input = player.getChannelProcessor && player.getChannelProcessor("input");
              if (input && input.pressButtonStart && input.pressButtonEnd) {
                if (phase === "ended") {
                  input.pressButtonEnd(button);
                } else {
                  input.pressButtonStart(button);
                }
              }
            },
            setMicrophone(active) {
              if (!player) {
                return;
              }
              const chat = player.getChannelProcessor && player.getChannelProcessor("chat");
              if (chat && chat.startMic && chat.stopMic) {
                if (active) {
                  chat.startMic();
                  setStatus("Microphone opened.");
                } else {
                  chat.stopMic();
                  setStatus("Microphone closed.");
                }
              }
            },
            stop() {
              if (player && player.close) {
                player.close();
              }
              player = null;
              remoteOfferApplied = false;
              localIcePublished = false;
              setStatus("Stopped.");
            }
          };

          document.addEventListener("native-streaming-bridge-ready", function () {
            window.xstreamingNativePlayer.start();
          });
          if (window.nativeStreamingBridge) {
            window.xstreamingNativePlayer.start();
          }
        })();
        """
    }

    private static func javascriptString(_ value: String) -> String {
        let data = try? JSONEncoder().encode(value)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }
}

enum CompatibilityPlayerAssetLoader {
    static func loadPlayerScript(bundle: Bundle = .module) throws -> String {
        guard let url = bundle.url(forResource: "XStreamingPlayer.min", withExtension: "js") else {
            throw WebViewStreamingEngineError.playerScriptUnavailable
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
