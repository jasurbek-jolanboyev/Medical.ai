const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

/**
 * 1. Yangi foydalanuvchi ro'yxatdan o'tganda Firestore'da profil yaratish
 */
exports.createUserProfile = functions.auth.user().onCreate((user) => {
  const { uid, email, displayName, photoURL } = user;
  
  return admin.firestore().collection("users").doc(uid).set({
    uid: uid,
    username: displayName || email?.split("@")[0] || "User_" + uid.substring(0, 4),
    email: email || "",
    avatar: photoURL || "",
    bio: "SafeChat orqali muloqotda",
    online: true,
    lastActive: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    fcmToken: "", // Mobil ilovadan yangilanadi
  });
});

/**
 * 2. Yangi xabar kelganda qabul qiluvchiga Push-Notification yuborish
 */
exports.onMessageCreated = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const { chatId } = context.params;
    const { senderId, text, type } = message;

    // Chat ID formatidan (user1_user2) qabul qiluvchini aniqlash
    const userIds = chatId.split("_");
    const receiverId = userIds.find((id) => id !== senderId);

    if (!receiverId) return null;

    try {
      // 1. Qabul qiluvchi ma'lumotlarini olish
      const receiverDoc = await admin.firestore().collection("users").doc(receiverId).get();
      if (!receiverDoc.exists) return null;
      
      const receiverData = receiverDoc.data();
      const token = receiverData.fcmToken;

      // Agar foydalanuvchida token bo'lmasa yoki hozirgina o'sha chatda bo'lsa yubormaymiz
      if (!token) return null;

      // 2. Yuboruvchi ismini olish
      const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
      const senderName = senderDoc.data()?.username || "Kimdir";

      // 3. Bildirishnoma mazmuni
      let notificationBody = text;
      if (type === "image") notificationBody = "📷 Rasm yuborildi";
      
      const payload = {
        token: token,
        notification: {
          title: senderName,
          body: notificationBody.length > 60 ? notificationBody.substring(0, 60) + "..." : notificationBody,
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          chatId: chatId,
          senderId: senderId,
          type: "chat_message"
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channelId: "messages", // Android 8+ uchun
          }
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1
            }
          }
        }
      };

      // 4. Jo'natish
      return await admin.messaging().send(payload);
      
    } catch (error) {
      console.error("Notification Error:", error);
      return null;
    }
  });

/**
 * 3. Foydalanuvchi tizimdan chiqqanda online statusini o'chirish (ixtiyoriy)
 */
exports.onUserOffline = functions.https.onCall(async (data, context) => {
  if (!context.auth) return { status: "error" };
  
  await admin.firestore().collection("users").doc(context.auth.uid).update({
    online: false,
    lastActive: admin.firestore.FieldValue.serverTimestamp()
  });
  
  return { status: "success" };
});