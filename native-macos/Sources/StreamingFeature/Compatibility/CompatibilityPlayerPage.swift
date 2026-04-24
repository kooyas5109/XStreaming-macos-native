import Foundation
import SharedDomain

public struct CompatibilityPlayerConfiguration: Equatable, Sendable {
    public let turnServer: TurnServerConfiguration
    public let videoFormat: String
    public let gamepadKernel: String
    public let gamepadMix: Bool
    public let gamepadIndex: Int
    public let deadZone: Double
    public let vibration: Bool
    public let vibrationMode: String
    public let forceTriggerRumble: String
    public let enableNativeMouseKeyboard: Bool
    public let inputMouseKeyboardMapping: InputMouseKeyboardMapping

    public init(
        turnServer: TurnServerConfiguration = TurnServerConfiguration(),
        videoFormat: String = "",
        gamepadKernel: String = "Web",
        gamepadMix: Bool = false,
        gamepadIndex: Int = -1,
        deadZone: Double = 0.1,
        vibration: Bool = true,
        vibrationMode: String = "Webview",
        forceTriggerRumble: String = "",
        enableNativeMouseKeyboard: Bool = false,
        inputMouseKeyboardMapping: InputMouseKeyboardMapping = InputMouseKeyboardMapping(mapping: [:])
    ) {
        self.turnServer = turnServer
        self.videoFormat = videoFormat
        self.gamepadKernel = gamepadKernel
        self.gamepadMix = gamepadMix
        self.gamepadIndex = gamepadIndex
        self.deadZone = deadZone
        self.vibration = vibration
        self.vibrationMode = vibrationMode
        self.forceTriggerRumble = forceTriggerRumble
        self.enableNativeMouseKeyboard = enableNativeMouseKeyboard
        self.inputMouseKeyboardMapping = inputMouseKeyboardMapping
    }

    public init(settings: AppSettings, turnServer: TurnServerConfiguration? = nil) {
        self.init(
            turnServer: turnServer ?? settings.turnServer,
            videoFormat: settings.videoFormat,
            gamepadKernel: "Web",
            gamepadMix: settings.gamepadMix,
            gamepadIndex: settings.gamepadIndex,
            deadZone: settings.deadZone,
            vibration: settings.vibration,
            vibrationMode: "Webview",
            forceTriggerRumble: settings.forceTriggerRumble,
            enableNativeMouseKeyboard: settings.enableNativeMouseKeyboard,
            inputMouseKeyboardMapping: settings.inputMouseKeyboardMapping
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
              display: none;
            }
          </style>
        </head>
        <body tabindex="-1">
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
          var videoPlaying = false;
          let remoteCandidatesApplied = 0;
          let localCandidateSummary = "none";
          let remoteCandidateSummary = "none";
          let localCandidateDetail = "none";
          let remoteCandidateDetail = "none";
          let localCandidateMidSummary = "none";
          let remoteCandidateMidSummary = "none";
          let remoteCandidateApplySummary = "none";
          let lastWebRTCStats = "none";
          var streamStartWatchdog = null;
          var mediaStartWatchdog = null;
          const publishedLocalCandidates = new Set();
          const appliedRemoteCandidates = new Set();

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
              localCandidateDetail,
              remoteCandidateDetail,
              localCandidateMidSummary,
              remoteCandidateMidSummary,
              remoteCandidateApplySummary,
              webRTCStats: lastWebRTCStats,
              videoCount: videos.length,
              videos
            });
          }

          function clearStreamWatchdogs() {
            if (streamStartWatchdog) {
              window.clearTimeout(streamStartWatchdog);
              streamStartWatchdog = null;
            }
            if (mediaStartWatchdog) {
              window.clearTimeout(mediaStartWatchdog);
              mediaStartWatchdog = null;
            }
          }

          function armStreamStartWatchdog() {
            if (streamStartWatchdog) {
              window.clearTimeout(streamStartWatchdog);
            }
            streamStartWatchdog = window.setTimeout(function () {
              if (connected || videoPlaying) {
                return;
              }
              setStatus("WebRTC startup timed out.");
              post("error", { sessionID, message: "WebRTC startup timed out before connection." });
              emitDiagnostic("startup timeout");
              emitWebRTCStats("startup timeout stats");
            }, 45000);
          }

          function armMediaStartWatchdog() {
            if (mediaStartWatchdog) {
              window.clearTimeout(mediaStartWatchdog);
            }
            mediaStartWatchdog = window.setTimeout(function () {
              if (videoPlaying) {
                return;
              }
              setStatus("Video startup timed out.");
              post("error", { sessionID, message: "Video startup timed out after WebRTC connected." });
              emitDiagnostic("video startup timeout");
              emitWebRTCStats("video startup timeout stats");
            }, 25000);
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

          function candidateDetail(candidates) {
            const counts = {};
            candidates.forEach(function (candidate) {
              const value = String(candidate && candidate.candidate ? candidate.candidate : candidate || "");
              if (!value || value === "a=end-of-candidates") {
                return;
              }
              const parts = value.replace(/^a=/, "").split(/\\s+/);
              const protocol = String(parts[2] || "unknown").toLowerCase();
              const typeIndex = parts.indexOf("typ");
              const type = typeIndex >= 0 ? String(parts[typeIndex + 1] || "unknown").toLowerCase() : "unknown";
              const foundation = String(parts[0] || "candidate:?").replace("candidate:", "f");
              const port = String(parts[5] || "?");
              const key = type + "/" + protocol + "/" + foundation + "/p" + port;
              counts[key] = (counts[key] || 0) + 1;
            });
            return Object.keys(counts)
              .sort()
              .slice(0, 16)
              .map(function (key) { return key + "x" + counts[key]; })
              .join(",") || "none";
          }

          function candidateMidSummary(candidates) {
            const counts = {};
            candidates.forEach(function (candidate) {
              const mid = String(candidate && candidate.sdpMid != null ? candidate.sdpMid : "nil");
              const index = String(candidate && candidate.sdpMLineIndex != null ? candidate.sdpMLineIndex : "nil");
              const key = "mid=" + mid + "/m=" + index;
              counts[key] = (counts[key] || 0) + 1;
            });
            return Object.keys(counts)
              .sort()
              .map(function (key) { return key + "x" + counts[key]; })
              .join(",") || "none";
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

          function peerConnection() {
            return player && player._webrtcClient ? player._webrtcClient : null;
          }

          async function applyRemoteDescription(sdp) {
            const pc = peerConnection();
            if (!pc || !pc.setRemoteDescription) {
              throw new Error("RTCPeerConnection is unavailable.");
            }
            await pc.setRemoteDescription({ type: "answer", sdp });
            if (player.getEventBus) {
              player.getEventBus().emit("connectionstate", { state: "connecting" });
            }
          }

          async function addRemoteIceCandidate(pc, candidate) {
            const primary = {
              candidate: candidate.candidate,
              sdpMid: candidate.sdpMid || "0",
              sdpMLineIndex: normalizeMLineIndex(candidate.sdpMLineIndex)
            };
            try {
              await pc.addIceCandidate(primary);
              return { applied: true, fallback: false };
            } catch (primaryError) {
              try {
                await pc.addIceCandidate({
                  candidate: primary.candidate,
                  sdpMLineIndex: primary.sdpMLineIndex
                });
                return { applied: true, fallback: true };
              } catch (_) {
                return { applied: false, fallback: false, error: String(primaryError) };
              }
            }
          }

          function collectLocalIceCandidates() {
            const rawCandidates = player && player.getIceCandidates ? player.getIceCandidates() : [];
            const seen = new Set();
            return rawCandidates
              .map(normalizeIceCandidate)
              .filter(function (candidate) {
                if (candidate.candidate.length === 0) {
                  return false;
                }
                const key = candidateKey(candidate);
                if (seen.has(key)) {
                  return false;
                }
                seen.add(key);
                return true;
              });
          }

          function publishLocalIceCandidates(candidates, label) {
            const unpublished = candidates.filter(function (candidate) {
              return !publishedLocalCandidates.has(candidateKey(candidate));
            });
            if (unpublished.length === 0) {
              emitDiagnostic(label + " no new candidates");
              return;
            }

            unpublished.forEach(function (candidate) {
              publishedLocalCandidates.add(candidateKey(candidate));
            });
            setStatus("Sending " + unpublished.length + " local ICE candidates...");
            post("ice-candidates", { sessionID, candidates: unpublished });
            emitDiagnostic(label);
          }

          function wait(milliseconds) {
            return new Promise(function (resolve) {
              window.setTimeout(resolve, milliseconds);
            });
          }

          const nativeKeyboardPressed = new Map();
          const nativeKeyboardOrder = [];
          const nativeKeyboardMap = {
            ArrowLeft: "DPadLeft",
            ArrowUp: "DPadUp",
            ArrowRight: "DPadRight",
            ArrowDown: "DPadDown",
            Enter: "A",
            Backspace: "B",
            k: "A",
            l: "B",
            j: "X",
            i: "Y",
            "2": "LeftShoulder",
            "3": "RightShoulder",
            "1": "LeftTrigger",
            "4": "RightTrigger",
            "5": "LeftThumb",
            "6": "RightThumb",
            a: "LeftThumbXAxisMinus",
            d: "LeftThumbXAxisPlus",
            w: "LeftThumbYAxisPlus",
            s: "LeftThumbYAxisMinus",
            f: "RightThumbXAxisMinus",
            h: "RightThumbXAxisPlus",
            t: "RightThumbYAxisPlus",
            g: "RightThumbYAxisMinus",
            v: "View",
            m: "Menu",
            n: "Nexus"
          };

          function keyIdentifier(event) {
            if (event.key === "ArrowLeft" || event.key === "ArrowRight" || event.key === "ArrowUp" || event.key === "ArrowDown") {
              return event.key;
            }
            if (event.key === "Enter" || event.key === "Backspace") {
              return event.key;
            }
            if (event.key && event.key.length === 1) {
              return event.key.toLowerCase();
            }
            return "";
          }

          function shouldIgnoreKeyboardEvent(event) {
            if (event.metaKey || event.ctrlKey || event.altKey) {
              return true;
            }
            const target = event.target;
            const tagName = target && target.tagName ? String(target.tagName).toLowerCase() : "";
            return tagName === "input" || tagName === "textarea" || tagName === "select" || !!(target && target.isContentEditable);
          }

          function keyboardAxisValue(negative, positive) {
            for (let index = nativeKeyboardOrder.length - 1; index >= 0; index -= 1) {
              const action = nativeKeyboardPressed.get(nativeKeyboardOrder[index]);
              if (action === positive) return 1;
              if (action === negative) return -1;
            }
            return 0;
          }

          function nativeKeyboardGamepadState() {
            const state = {
              GamepadIndex: 0,
              A: 0,
              B: 0,
              X: 0,
              Y: 0,
              LeftShoulder: 0,
              RightShoulder: 0,
              LeftTrigger: 0,
              RightTrigger: 0,
              View: 0,
              Menu: 0,
              LeftThumb: 0,
              RightThumb: 0,
              DPadUp: 0,
              DPadDown: 0,
              DPadLeft: 0,
              DPadRight: 0,
              Nexus: 0,
              LeftThumbXAxis: 0,
              LeftThumbYAxis: 0,
              RightThumbXAxis: 0,
              RightThumbYAxis: 0,
              PhysicalPhysicality: 0,
              VirtualPhysicality: 0,
              Dirty: true,
              Virtual: true
            };
            nativeKeyboardPressed.forEach(function (action) {
              if (action.indexOf("XAxis") >= 0 || action.indexOf("YAxis") >= 0) {
                return;
              }
              state[action] = 1;
            });
            state.LeftThumbXAxis = keyboardAxisValue("LeftThumbXAxisMinus", "LeftThumbXAxisPlus");
            state.LeftThumbYAxis = keyboardAxisValue("LeftThumbYAxisMinus", "LeftThumbYAxisPlus");
            state.RightThumbXAxis = keyboardAxisValue("RightThumbXAxisMinus", "RightThumbXAxisPlus");
            state.RightThumbYAxis = keyboardAxisValue("RightThumbYAxisMinus", "RightThumbYAxisPlus");
            return state;
          }

          function updateNativeKeyboardGamepad(event, pressed) {
            if (shouldIgnoreKeyboardEvent(event)) {
              return;
            }
            const key = keyIdentifier(event);
            const action = nativeKeyboardMap[key];
            if (!action) {
              return;
            }
            event.preventDefault();
            event.stopPropagation();
            if (pressed) {
              if (nativeKeyboardPressed.has(key)) {
                return;
              }
              nativeKeyboardPressed.set(key, action);
              nativeKeyboardOrder.push(key);
            } else if (nativeKeyboardPressed.has(key)) {
              nativeKeyboardPressed.delete(key);
              const existingIndex = nativeKeyboardOrder.indexOf(key);
              if (existingIndex >= 0) {
                nativeKeyboardOrder.splice(existingIndex, 1);
              }
            } else {
              return;
            }
            emitDiagnostic("native keyboard state changed key=" + key + " pressed=" + (pressed ? "1" : "0"));
            window.xstreamingNativePlayer?.setGamepadState?.(nativeKeyboardGamepadState());
          }

          function installNativeKeyboardGamepad() {
            document.body && document.body.focus && document.body.focus({ preventScroll: true });
            document.addEventListener("pointerdown", function () {
              document.body && document.body.focus && document.body.focus({ preventScroll: true });
            }, true);
            document.addEventListener("keydown", function (event) {
              updateNativeKeyboardGamepad(event, true);
            }, true);
            document.addEventListener("keyup", function (event) {
              updateNativeKeyboardGamepad(event, false);
            }, true);
            window.addEventListener("blur", function () {
              if (nativeKeyboardPressed.size === 0) {
                return;
              }
              nativeKeyboardPressed.clear();
              nativeKeyboardOrder.splice(0, nativeKeyboardOrder.length);
              window.xstreamingNativePlayer?.setGamepadState?.(nativeKeyboardGamepadState());
            });
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
              videoPlaying = true;
              clearStreamWatchdogs();
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

          async function exchangeLocalIceCandidates() {
            if (!player || !remoteOfferApplied) {
              return;
            }
            setStatus("Collecting local ICE candidates...");

            let candidates = [];
            let previousCount = -1;
            const delays = [0, 500, 1000, 1500, 2500, 3500];
            for (const delay of delays) {
              if (delay > 0) {
                await wait(delay);
              }
              candidates = collectLocalIceCandidates();
              localCandidateSummary = candidateSummary(candidates);
              localCandidateDetail = candidateDetail(candidates);
              localCandidateMidSummary = candidateMidSummary(candidates);
              emitDiagnostic("local ICE collection");
              publishLocalIceCandidates(candidates, "local ICE publish update");

              const hasRelay = localCandidateSummary.indexOf("relay=0") === -1;
              if (candidates.length > 0 && candidates.length === previousCount && hasRelay) {
                break;
              }
              previousCount = candidates.length;
            }

            localCandidateSummary = candidateSummary(candidates);
            localCandidateDetail = candidateDetail(candidates);
            localCandidateMidSummary = candidateMidSummary(candidates);
            if (publishedLocalCandidates.size === 0) {
              setStatus("No local ICE candidates were gathered.");
            }
            emitDiagnostic("local ICE publish complete");
          }

          window.xstreamingNativePlayer = {
            async start() {
              if (player) {
                return;
              }
              try {
                armStreamStartWatchdog();
                emitDiagnostic("player start requested");
                setStatus("Creating peer connection...");
                const Player = playerConstructor();
                if (!Player) {
                  throw new Error("xStreamingPlayer constructor is unavailable.");
                }
                player = new Player("videoHolder", {
                  input_touch: false,
                  ui_touchenabled: false,
                  input_mousekeyboard: !!nativePlayerConfiguration.enableNativeMouseKeyboard,
                  input_legacykeyboard: true,
                  input_mousekeyboard_config: nativePlayerConfiguration.inputMouseKeyboardMapping || {}
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
                      armMediaStartWatchdog();
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
                if (player.setGamepadKernal) {
                  player.setGamepadKernal(nativePlayerConfiguration.gamepadKernel || "Web");
                }
                if (player.setGamepadMix) {
                  player.setGamepadMix(!!nativePlayerConfiguration.gamepadMix);
                }
                if (player.setGamepadIndex) {
                  const gamepadIndex = Number(nativePlayerConfiguration.gamepadIndex);
                  player.setGamepadIndex(Number.isFinite(gamepadIndex) ? gamepadIndex : -1);
                }
                if (player.setVibration) {
                  player.setVibration(!!nativePlayerConfiguration.vibration);
                }
                if (player.setVibrationMode) {
                  player.setVibrationMode(nativePlayerConfiguration.vibrationMode || "Webview");
                }
                if (player.setGamepadDeadZone) {
                  const deadZone = Number(nativePlayerConfiguration.deadZone);
                  player.setGamepadDeadZone(Number.isFinite(deadZone) ? deadZone : 0.1);
                }
                if (nativePlayerConfiguration.forceTriggerRumble && player.setForceTriggerRumble) {
                  player.setForceTriggerRumble(nativePlayerConfiguration.forceTriggerRumble);
                }
                emitDiagnostic("gamepad configuration applied");
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
              try {
                await applyRemoteDescription(sdp);
                remoteOfferApplied = true;
                setStatus("Negotiating network path...");
                emitDiagnostic("remote answer applied");
                exchangeLocalIceCandidates();
              } catch (error) {
                setStatus("Failed to apply remote answer.");
                post("error", { sessionID, message: "Failed to apply remote answer: " + String(error) });
                emitDiagnostic("remote answer apply failed");
              }
            },
            async setIceCandidates(candidates) {
              if (player && candidates && candidates.length) {
                const pc = peerConnection();
                if (!pc || !pc.addIceCandidate) {
                  post("error", { sessionID, message: "RTCPeerConnection is unavailable." });
                  return;
                }
                const normalizedCandidates = candidates.map(normalizeIceCandidate);
                remoteCandidateSummary = candidateSummary(normalizedCandidates);
                remoteCandidateDetail = candidateDetail(normalizedCandidates);
                remoteCandidateMidSummary = candidateMidSummary(normalizedCandidates);

                let applied = 0;
                let failed = 0;
                let fallback = 0;
                let ended = 0;
                let skipped = 0;
                let firstError = "";
                for (const candidate of normalizedCandidates) {
                  if (candidate.candidate === "a=end-of-candidates") {
                    ended += 1;
                    continue;
                  }
                  const key = candidateKey(candidate);
                  if (appliedRemoteCandidates.has(key)) {
                    skipped += 1;
                    continue;
                  }
                  if (candidate.candidate.includes("UDP") && candidate.candidate.includes("tcptype")) {
                    failed += 1;
                    continue;
                  }
                  const result = await addRemoteIceCandidate(pc, candidate);
                  if (result.applied) {
                    applied += 1;
                    appliedRemoteCandidates.add(key);
                    if (result.fallback) {
                      fallback += 1;
                    }
                  } else {
                    failed += 1;
                    if (!firstError && result.error) {
                      firstError = result.error;
                    }
                  }
                }
                remoteCandidatesApplied += normalizedCandidates.length;
                remoteCandidateApplySummary = "applied=" + applied + " fallback=" + fallback + " failed=" + failed + " skipped=" + skipped + " end=" + ended;
                setStatus("Remote ICE applied. Waiting for media...");
                emitDiagnostic("remote ICE applied");
                await emitWebRTCStats("remote ICE stats");
                if (failed > 0) {
                  post("error", { sessionID, message: "Remote ICE candidate failures: " + remoteCandidateApplySummary + (firstError ? " first=" + firstError : "") });
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
            setGamepadState(state) {
              if (!player || !state) {
                return;
              }
              const input = player.getChannelProcessor && player.getChannelProcessor("input");
              if (input) {
                const gamepadState = Object.assign({
                  GamepadIndex: 0,
                  A: 0,
                  B: 0,
                  X: 0,
                  Y: 0,
                  LeftShoulder: 0,
                  RightShoulder: 0,
                  LeftTrigger: 0,
                  RightTrigger: 0,
                  View: 0,
                  Menu: 0,
                  LeftThumb: 0,
                  RightThumb: 0,
                  DPadUp: 0,
                  DPadDown: 0,
                  DPadLeft: 0,
                  DPadRight: 0,
                  Nexus: 0,
                  LeftThumbXAxis: 0,
                  LeftThumbYAxis: 0,
                  RightThumbXAxis: 0,
                  RightThumbYAxis: 0,
                  PhysicalPhysicality: 0,
                  VirtualPhysicality: 0,
                  Dirty: true,
                  Virtual: true
                }, state);
                const usedDirectGamepadInput = !!input.sendGamepadInput;
                const usedSetGamepadState = !!input.setGamepadState;
                const usedQueueGamepadState = !!input.queueGamepadState;
                if (usedDirectGamepadInput) {
                  input.sendGamepadInput(performance.now(), [gamepadState]);
                }
                if (usedSetGamepadState) {
                  input.setGamepadState(gamepadState);
                }
                if (usedQueueGamepadState) {
                  input.queueGamepadState(gamepadState);
                }
                if (usedDirectGamepadInput || usedSetGamepadState || usedQueueGamepadState) {
                  emitDiagnostic("native gamepad state sent direct=" + (usedDirectGamepadInput ? "1" : "0") + " set=" + (usedSetGamepadState ? "1" : "0") + " queue=" + (usedQueueGamepadState ? "1" : "0"));
                } else {
                  emitDiagnostic("native gamepad state ignored no input method");
                }
              } else {
                emitDiagnostic("native gamepad state ignored input unavailable");
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
              clearStreamWatchdogs();
              if (player && player.close) {
                player.close();
              }
              player = null;
              remoteOfferApplied = false;
              connected = false;
              videoPlaying = false;
              remoteCandidatesApplied = 0;
              localCandidateSummary = "none";
              remoteCandidateSummary = "none";
              localCandidateDetail = "none";
              remoteCandidateDetail = "none";
              localCandidateMidSummary = "none";
              remoteCandidateMidSummary = "none";
              remoteCandidateApplySummary = "none";
              lastWebRTCStats = "none";
              publishedLocalCandidates.clear();
              appliedRemoteCandidates.clear();
              setStatus("Stopped.");
            }
          };

          document.addEventListener("native-streaming-bridge-ready", function () {
            window.xstreamingNativePlayer.start();
          });
          if (window.nativeStreamingBridge) {
            window.xstreamingNativePlayer.start();
          }
          installNativeKeyboardGamepad();
        })();
        """
    }

    private static func javascriptString(_ value: String) -> String {
        let data = try? JSONEncoder().encode(value)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }

    private static func javascriptJSON(_ configuration: CompatibilityPlayerConfiguration) -> String {
        var object: [String: Any] = [
            "deadZone": configuration.deadZone,
            "enableNativeMouseKeyboard": configuration.enableNativeMouseKeyboard,
            "forceTriggerRumble": configuration.forceTriggerRumble,
            "gamepadIndex": configuration.gamepadIndex,
            "gamepadKernel": configuration.gamepadKernel,
            "gamepadMix": configuration.gamepadMix,
            "inputMouseKeyboardMapping": configuration.inputMouseKeyboardMapping.mapping,
            "vibration": configuration.vibration,
            "vibrationMode": configuration.vibrationMode,
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
