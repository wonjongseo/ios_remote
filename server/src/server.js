import bodyParser from "body-parser";
import apn from "apn";
import http from "http";
import { Server } from "socket.io";
import express from "express";
import path from "path";

const __dirname = path.resolve();
let deviceTokens = ["7556d973b43db183e43e5e9fa028994c5970bfaf1b3c2182b180df1cda1f2ce9"];

const app = express();

app.use(bodyParser.json());

app.set("view engine", "pug");
app.set("views", __dirname + "/views");

app.use("/public", express.static(__dirname + "/public"));
app.get("/", (_, res) => res.render("home"));
// app.get("/*", (req, res) => res.redirect("/"));

const apnProvider = new apn.Provider({
  token: {
    key: "./AuthKey_5L3Q4XW42K.p8", // 1장에서 받은 .p8 경로
    keyId: "5L3Q4XW42K", // Key ID
    teamId: "6B7JBM5DS9", // Team ID
  },
  production: false, // 개발용: false, 배포용: true
});

// -- 디바이스 토큰 저장용 (예: 메모리) --

// 1) 디바이스 토큰 등록 엔드포인트
//806eeabd77a7c368228e6f51a4d7081c93d1c2a820e96db615e683039a4913d27e4686b3b5cc497bdb49269d615d37d11629c820a1f195def3c4196a4f67c35964eead7967c5b0116e888521817a6071
app.post("/api/register-device", (req, res) => {
  const { token } = req.body;
  console.log("token: ", token);
  if (typeof token !== "string") {
    return res.status(400).json({ error: "token 문자열이 필요합니다." });
  }
  if (!deviceTokens.includes(token)) {
    deviceTokens.push(token);
  }
  console.log("현재 등록된 토큰:", deviceTokens);
  res.json({ success: true });
});

// 2) 푸시 전송 엔드포인트 (관리자 또는 자동 스케줄용)
app.post("/api/send-push", async (req, res) => {
  const { title, body, payload } = req.body;

  // APNs Notification 생성
  let notification = new apn.Notification({
    alert: { title, body },
    payload: payload || {},
    topic: "com.wonjongseo.remotecontroler", // 여러분의 앱 번들 ID
    pushType: "alert",
  });

  try {
    let result = await apnProvider.send(notification, deviceTokens);
    console.log("전송 성공:", result.sent);
    console.log("전송 실패:", result.failed);
    res.json({
      sent: result.sent.map((r) => r.device),
      failed: result.failed.map((r) => ({ device: r.device, reason: r.response?.reason })),
    });
  } catch (err) {
    console.error("푸시 전송 중 오류:", err);
    res.status(500).json({ error: err.message });
  }
});

const handleListen = () => console.log(`Listening on http://localhost:3000`);
// app.listen(3000, handleListen);
const httpServer = http.createServer(app);
const wsServer = new Server(httpServer, {});

wsServer.on("connection", (socket) => {
  console.log("connection");

  socket.on("join_room", (roomName) => {
    console.log("JOIN ");
    console.log("roomName: ", roomName);
    socket.join(roomName);
    socket.to(roomName).emit("welcome");
  });

  socket.on("offer", (data) => {
    socket.to("1212").emit("offer", data);
  });
  socket.on("answer", (data, roomName) => {
    socket.to("1212").emit("answer", data);
  });
  socket.on("ice", (data) => {
    socket.to("1212").emit("ice", data);
  });
});
httpServer.listen(3000, handleListen);
