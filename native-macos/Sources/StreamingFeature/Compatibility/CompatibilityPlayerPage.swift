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
          let connected = false;
          const publishedLocalCandidates = new Set();

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

          function emitDiagnostic(label) {
            const pc = player && player._webrtcClient;
            const videos = Array.from(document.querySelectorAll("video")).map(function (video) {
              return {
                readyState: video.readyState,
                paused: video.paused,
                muted: video.muted,
                width: video.videoWidth,
                height: video.videoHeight
              };
            });
            post("diagnostic", {
              sessionID,
              message: label,
              connectionState: pc ? pc.connectionState : "unavailable",
              iceConnectionState: pc ? pc.iceConnectionState : "unavailable",
              iceGatheringState: pc ? pc.iceGatheringState : "unavailable",
              localCandidatesSent: publishedLocalCandidates.size,
              videoCount: videos.length,
              videos
            });
          }

          function normalizeIceCandidate(candidate) {
            return {
              messageType: "iceCandidate",
              candidate: candidate.candidate || "",
              sdpMid: candidate.sdpMid || "0",
              sdpMLineIndex: String(candidate.sdpMLineIndex ?? 0)
            };
          }

          function candidateKey(candidate) {
            return [
              candidate.candidate || "",
              candidate.sdpMid || "0",
              String(candidate.sdpMLineIndex ?? 0)
            ].join("|");
          }

          function observeVideoElement(video) {
            if (!video || video.dataset.nativeObserved === "true") {
              return;
            }
            video.dataset.nativeObserved = "true";
            video.autoplay = true;
            video.playsInline = true;
            video.addEventListener("loadedmetadata", function () {
              emitDiagnostic("video loadedmetadata");
            });
            video.addEventListener("playing", function () {
              setStatus("Streaming.");
              emitDiagnostic("video playing");
            });
            video.addEventListener("resize", function () {
              emitDiagnostic("video resize");
            });
            video.addEventListener("waiting", function () {
              emitDiagnostic("video waiting");
            });
            video.addEventListener("stalled", function () {
              emitDiagnostic("video stalled");
            });
            video.addEventListener("error", function () {
              emitDiagnostic("video error");
            });
            const playResult = video.play && video.play();
            if (playResult && playResult.catch) {
              playResult.catch(function (error) {
                post("error", { sessionID, message: "Video autoplay failed: " + String(error) });
              });
            }
          }

          function observeVideoHolder() {
            const holder = document.getElementById("videoHolder");
            if (!holder) {
              return;
            }
            Array.from(holder.querySelectorAll("video")).forEach(observeVideoElement);
            const observer = new MutationObserver(function () {
              Array.from(holder.querySelectorAll("video")).forEach(observeVideoElement);
              emitDiagnostic("video holder changed");
            });
            observer.observe(holder, { childList: true, subtree: true });
          }

          function playerConstructor() {
            const exported = window.xStreamingPlayer || window.xstreamingPlayer;
            if (typeof exported === "function") {
              return exported;
            }
            if (exported && typeof exported.default === "function") {
              return exported.default;
            }
            return null;
          }

          async function publishLocalIceCandidates() {
            if (!player || !remoteOfferApplied || connected) {
              return;
            }
            const rawCandidates = player.getIceCandidates ? player.getIceCandidates() : [];
            const candidates = rawCandidates
              .map(normalizeIceCandidate)
              .filter(function (candidate) {
                if (candidate.candidate.length === 0) {
                  return false;
                }
                const key = candidateKey(candidate);
                if (publishedLocalCandidates.has(key)) {
                  return false;
                }
                publishedLocalCandidates.add(key);
                return true;
              });
            if (candidates.length > 0) {
              setStatus("Sending " + candidates.length + " local ICE candidates...");
              post("ice-candidates", { sessionID, candidates });
            } else {
              setStatus("Waiting for local ICE candidates...");
            }
            emitDiagnostic("local ICE publish attempt");
          }

          function scheduleIcePublishing() {
            [0, 500, 1000, 2000, 4000, 7000, 10000].forEach(function (delay) {
              window.setTimeout(publishLocalIceCandidates, delay);
            });
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
                observeVideoHolder();
                if (player.setConnectFailHandler) {
                  player.setConnectFailHandler(function () {
                    setStatus("WebRTC connection failed.");
                    post("error", { sessionID, message: "WebRTC connection failed before media started." });
                    emitDiagnostic("connection failed");
                  });
                }
                if (player.getEventBus) {
                  player.getEventBus().on("connectionstate", function (event) {
                    const state = event && event.state ? event.state : "unknown";
                    if (state === "connected") {
                      connected = true;
                      setStatus("Connected. Waiting for video...");
                    } else {
                      setStatus("WebRTC " + state + "...");
                    }
                    emitDiagnostic("connectionstate " + state);
                  });
                }
                player.bind({});
                const offer = await player.createOffer();
                post("sdp-offer", { sessionID, sdp: offer.sdp || "" });
                setStatus("Waiting for console answer...");
                emitDiagnostic("local offer created");
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
              emitDiagnostic("remote answer applied");
              scheduleIcePublishing();
            },
            setIceCandidates(candidates) {
              if (player && candidates && candidates.length) {
                player.setIceCandidates(candidates);
                setStatus("Remote ICE applied. Waiting for media...");
                emitDiagnostic("remote ICE applied");
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
              connected = false;
              publishedLocalCandidates.clear();
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
