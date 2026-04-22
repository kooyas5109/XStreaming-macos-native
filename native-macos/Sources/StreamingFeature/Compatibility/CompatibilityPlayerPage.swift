import Foundation
import SharedDomain

public struct CompatibilityPlayerConfiguration: Equatable, Sendable {
    public let turnServer: TurnServerConfiguration
    public let videoFormat: String

    public init(
        turnServer: TurnServerConfiguration = TurnServerConfiguration(),
        videoFormat: String = ""
    ) {
        self.turnServer = turnServer
        self.videoFormat = videoFormat
    }

    public init(settings: AppSettings) {
        self.init(
            turnServer: settings.turnServer,
            videoFormat: settings.videoFormat
        )
    }
}

public struct CompatibilityPlayerPage: Sendable {
    let playerScript: String

    public init(playerScript: String) {
        self.playerScript = playerScript
    }

    public func html(
        for session: StreamingSession,
        configuration: CompatibilityPlayerConfiguration = CompatibilityPlayerConfiguration()
    ) -> String {
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
        \(playerBootstrapScript(sessionID: session.id, configuration: configuration))
          </script>
        </body>
        </html>
        """
    }

    private func escapedScript(_ script: String) -> String {
        script.replacingOccurrences(of: "</script", with: "<\\/script")
    }

    private func playerBootstrapScript(
        sessionID: String,
        configuration: CompatibilityPlayerConfiguration
    ) -> String {
        let encodedSessionID = Self.javascriptString(sessionID)
        let encodedPlayerConfiguration = Self.javascriptJSON(configuration)
        return """
        (function () {
          const sessionID = \(encodedSessionID);
          const nativePlayerConfiguration = \(encodedPlayerConfiguration);
          const status = document.getElementById("status");
          let player = null;
          let remoteOfferApplied = false;
          let connected = false;
          let remoteCandidatesApplied = 0;
          let localCandidateSummary = "none";
          let remoteCandidateSummary = "none";
          let lastWebRTCStats = "none";
          const publishedLocalCandidates = new Set();
          const publishedLocalCandidateValues = [];

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
              remoteCandidatesApplied,
              localCandidateSummary,
              remoteCandidateSummary,
              webRTCStats: lastWebRTCStats,
              videoCount: videos.length,
              videos
            });
          }

          function candidateSummary(candidates) {
            const summary = {
              total: 0,
              host: 0,
              srflx: 0,
              relay: 0,
              prflx: 0,
              udp: 0,
              tcp: 0,
              end: 0
            };
            candidates.forEach(function (candidate) {
              const value = String(candidate && candidate.candidate ? candidate.candidate : candidate || "");
              if (!value) {
                return;
              }
              if (value === "a=end-of-candidates") {
                summary.end += 1;
                return;
              }
              summary.total += 1;
              const parts = value.replace(/^a=/, "").split(/\\s+/);
              const protocol = String(parts[2] || "").toLowerCase();
              if (protocol === "udp") {
                summary.udp += 1;
              } else if (protocol === "tcp") {
                summary.tcp += 1;
              }
              const typeIndex = parts.indexOf("typ");
              const type = typeIndex >= 0 ? String(parts[typeIndex + 1] || "").toLowerCase() : "unknown";
              if (Object.prototype.hasOwnProperty.call(summary, type)) {
                summary[type] += 1;
              }
            });
            return "total=" + summary.total
              + " host=" + summary.host
              + " srflx=" + summary.srflx
              + " relay=" + summary.relay
              + " prflx=" + summary.prflx
              + " udp=" + summary.udp
              + " tcp=" + summary.tcp
              + " end=" + summary.end;
          }

          async function emitWebRTCStats(label) {
            const pc = player && player._webrtcClient;
            if (!pc || !pc.getStats) {
              lastWebRTCStats = "unavailable";
              emitDiagnostic(label);
              return;
            }
            try {
              const report = await pc.getStats();
              const counts = {
                localHost: 0,
                localSrflx: 0,
                localRelay: 0,
                remoteHost: 0,
                remoteSrflx: 0,
                remoteRelay: 0,
                pairs: 0,
                nominated: 0,
                selected: 0
              };
              report.forEach(function (stat) {
                if (stat.type === "local-candidate") {
                  if (stat.candidateType === "host") counts.localHost += 1;
                  if (stat.candidateType === "srflx") counts.localSrflx += 1;
                  if (stat.candidateType === "relay") counts.localRelay += 1;
                } else if (stat.type === "remote-candidate") {
                  if (stat.candidateType === "host") counts.remoteHost += 1;
                  if (stat.candidateType === "srflx") counts.remoteSrflx += 1;
                  if (stat.candidateType === "relay") counts.remoteRelay += 1;
                } else if (stat.type === "candidate-pair") {
                  counts.pairs += 1;
                  if (stat.nominated) counts.nominated += 1;
                  if (stat.selected || stat.state === "succeeded") counts.selected += 1;
                }
              });
              lastWebRTCStats = "local(host=" + counts.localHost
                + ",srflx=" + counts.localSrflx
                + ",relay=" + counts.localRelay
                + ") remote(host=" + counts.remoteHost
                + ",srflx=" + counts.remoteSrflx
                + ",relay=" + counts.remoteRelay
                + ") pairs=" + counts.pairs
                + " nominated=" + counts.nominated
                + " selected=" + counts.selected;
            } catch (error) {
              lastWebRTCStats = "failed:" + String(error);
            }
            emitDiagnostic(label);
          }

          function normalizeMLineIndex(value) {
            const parsed = Number(value ?? 0);
            return Number.isFinite(parsed) ? parsed : 0;
          }

          function normalizeIceCandidate(candidate) {
            return {
              messageType: "iceCandidate",
              candidate: candidate.candidate || "",
              sdpMid: candidate.sdpMid || "0",
              sdpMLineIndex: normalizeMLineIndex(candidate.sdpMLineIndex)
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
                publishedLocalCandidateValues.push(candidate);
                return true;
              });
            localCandidateSummary = candidateSummary(publishedLocalCandidateValues);
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
                    emitWebRTCStats("connection failed stats");
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
                if (nativePlayerConfiguration.turnServer) {
                  player.bind({ turnServer: nativePlayerConfiguration.turnServer });
                  emitDiagnostic("player bound with TURN server");
                } else {
                  player.bind({});
                  emitDiagnostic("player bound without TURN server");
                }
                if (nativePlayerConfiguration.videoFormat && player.setVideoFormat) {
                  player.setVideoFormat(nativePlayerConfiguration.videoFormat);
                }
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
                try {
                  const normalizedCandidates = candidates.map(normalizeIceCandidate);
                  player.setIceCandidates(normalizedCandidates);
                  remoteCandidatesApplied += normalizedCandidates.length;
                  remoteCandidateSummary = candidateSummary(normalizedCandidates);
                  setStatus("Remote ICE applied. Waiting for media...");
                  emitDiagnostic("remote ICE applied");
                  emitWebRTCStats("remote ICE stats");
                } catch (error) {
                  setStatus("Failed to apply remote ICE.");
                  post("error", { sessionID, message: "Failed to apply remote ICE: " + String(error) });
                  emitDiagnostic("remote ICE apply failed");
                }
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
              remoteCandidatesApplied = 0;
              localCandidateSummary = "none";
              remoteCandidateSummary = "none";
              lastWebRTCStats = "none";
              publishedLocalCandidates.clear();
              publishedLocalCandidateValues.length = 0;
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

    private static func javascriptJSON(_ configuration: CompatibilityPlayerConfiguration) -> String {
        var object: [String: Any] = [
            "videoFormat": configuration.videoFormat
        ]

        if configuration.turnServer.isComplete {
            object["turnServer"] = [
                "url": configuration.turnServer.url,
                "username": configuration.turnServer.username,
                "credential": configuration.turnServer.credential
            ]
        } else {
            object["turnServer"] = NSNull()
        }

        let data = try? JSONSerialization.data(withJSONObject: object)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
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
