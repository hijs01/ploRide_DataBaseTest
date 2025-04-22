/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require('firebase-functions/v2/https');
const {onValueCreated, onValueUpdated} = require('firebase-functions/v2/database');
const {onDocumentCreated, onDocumentUpdated} = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const functions = require('firebase-functions/v2');
const admin = require('firebase-admin');

admin.initializeApp();

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// Firestore 라이드 요청이 생성될 때 드라이버에게 알림 보내기
exports.sendFirestoreRideRequestNotification = onDocumentCreated('rideRequests/{rideId}', async (event) => {
  const rideData = event.data.data();
  const rideId = event.params.rideId;
  
  if (!rideData) {
    console.log('라이드 데이터가 없습니다');
    return null;
  }

  console.log('새로운 라이드 요청:', rideData);
  console.log('라이드 ID:', rideId);

  try {
    // 드라이버의 FCM 토큰 가져오기
    const driverDoc = await admin.firestore()
      .collection('drivers')
      .doc(rideData.driver_id)
      .get();
    
    const driverData = driverDoc.data();

    if (!driverData || !driverData.token) {
      console.log('드라이버 FCM 토큰을 찾을 수 없습니다');
      return null;
    }

    // 알림 메시지 구성
    const message = {
      notification: {
        title: '새로운 탑승 요청',
        body: `목적지: ${rideData.destination_address || '알 수 없음'}`,
      },
      data: {
        ride_id: rideId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        destination: rideData.destination_address || '',
        pickup: rideData.pickup_address || '',
        rider_name: rideData.rider_name || '',
        rider_phone: rideData.rider_phone || '',
      },
      token: driverData.token,
    };

    // FCM 메시지 전송
    const response = await admin.messaging().send(message);
    console.log('알림 전송 성공:', response);
    
    // 알림 전송 상태 업데이트
    await admin.firestore()
      .collection('rideRequests')
      .doc(rideId)
      .update({
        notification_sent: true,
        notification_sent_at: admin.firestore.FieldValue.serverTimestamp(),
      });

    return null;
  } catch (error) {
    console.error('알림 전송 실패:', error);
    return null;
  }
});

// Firestore 라이드 상태가 변경될 때 승객에게 알림 보내기
exports.sendFirestoreRideStatusNotification = onDocumentUpdated('rideRequests/{rideId}', async (event) => {
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();
  const rideId = event.params.rideId;

  // 상태 변경이 없으면 종료
  if (beforeData.status === afterData.status) {
    return null;
  }

  const newStatus = afterData.status;
  console.log(`라이드 ${rideId} 상태 변경: ${beforeData.status} -> ${newStatus}`);

  try {
    // 승객의 FCM 토큰 가져오기
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(afterData.user_id)
      .get();
    
    const userData = userDoc.data();
    if (!userData || !userData.fcm_token) {
      console.log('사용자 FCM 토큰을 찾을 수 없습니다');
      return null;
    }

    // 상태별 메시지 설정
    const title = '탑승 상태 업데이트';
    let body = '';
    
    switch (newStatus) {
    case 'accepted':
      body = '드라이버가 요청을 수락했습니다';
      break;
    case 'arrived':
      body = '드라이버가 픽업 장소에 도착했습니다';
      break;
    case 'ontrip':
      body = '운행이 시작되었습니다';
      break;
    case 'completed':
      body = '운행이 완료되었습니다';
      break;
    default:
      body = `탑승 상태가 ${newStatus}로 변경되었습니다`;
    }

    // 알림 메시지 구성
    const message = {
      notification: {
        title,
        body,
      },
      data: {
        ride_id: rideId,
        status: newStatus,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      token: userData.fcm_token,
    };

    // FCM 메시지 전송
    const response = await admin.messaging().send(message);
    console.log('상태 변경 알림 전송 성공:', response);

    // 알림 데이터를 사용자의 notifications 컬렉션에 저장
    await admin.firestore()
      .collection('users')
      .doc(afterData.user_id)
      .collection('notifications')
      .add({
        type: 'ride_status',
        title: title,
        body: body,
        ride_id: rideId,
        status: newStatus,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });

    return null;
  } catch (error) {
    console.error('상태 변경 알림 전송 실패:', error);
    return null;
  }
});

// HTTP 엔드포인트: 드라이버에게 푸시 알림 보내기
exports.sendPushToDriver = functions.https.onRequest(async (req, res) => {
  // CORS 헤더 설정
  res.set('Access-Control-Allow-Origin', '*');
  
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }
  
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    const { driverId, rideId, pickup_address, destination_address } = req.body;
    
    if (!driverId || !rideId) {
      res.status(400).send({ error: '드라이버 ID와 라이드 ID가 필요합니다' });
      return;
    }

    // Firestore에서 드라이버 FCM 토큰 가져오기
    const driverDoc = await admin.firestore()
      .collection('drivers')
      .doc(driverId)
      .get();
      
    if (!driverDoc.exists) {
      console.log('드라이버 문서가 존재하지 않음:', driverId);
      res.status(404).send({ error: '드라이버를 찾을 수 없습니다' });
      return;
    }
    
    const driverData = driverDoc.data();
    console.log('드라이버 데이터:', driverData);
    console.log('토큰 값:', driverData.token);
    
    if (!driverData.token) {
      console.log('토큰이 없음. 전체 데이터:', JSON.stringify(driverData));
      res.status(404).send({ error: '드라이버 FCM 토큰을 찾을 수 없습니다' });
      return;
    }

    // FCM 메시지 구성
    const message = {
      notification: {
        title: '새로운 탑승 요청',
        body: `목적지: ${destination_address || '알 수 없음'}`,
      },
      data: {
        ride_id: rideId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        destination: destination_address || '',
        pickup: pickup_address || '',
      },
      token: driverData.token,
    };

    // FCM 메시지 전송
    const response = await admin.messaging().send(message);
    console.log('HTTP 엔드포인트: 알림 전송 성공', response);
    
    res.status(200).send({ success: true, message: '알림이 성공적으로 전송되었습니다' });
  } catch (error) {
    console.error('HTTP 엔드포인트: 알림 전송 실패', error);
    res.status(500).send({ error: error.message });
  }
});

// HTTP 엔드포인트: 채팅 메시지 알림 보내기
exports.sendChatNotification = functions.https.onRequest(async (req, res) => {
  // CORS 헤더 설정
  res.set('Access-Control-Allow-Origin', '*');
  
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }
  
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    const { 
      chatRoomId, 
      chatRoomName, 
      messageText, 
      senderName, 
      senderId, 
      receiverIds 
    } = req.body;
    
    if (!chatRoomId || !messageText || !senderName || !senderId || !receiverIds || !Array.isArray(receiverIds)) {
      res.status(400).send({ error: '필수 정보가 누락되었습니다' });
      return;
    }

    console.log('채팅 알림 요청 정보:', {
      chatRoomId,
      chatRoomName,
      messageText: messageText.substring(0, 50) + (messageText.length > 50 ? '...' : ''),
      senderName,
      senderId,
      receiverCount: receiverIds.length
    });

    // 모든 수신자의 FCM 토큰 가져오기
    const userTokens = [];
    for (const userId of receiverIds) {
      try {
        const userDoc = await admin.firestore()
          .collection('users')
          .doc(userId)
          .get();
        
        if (userDoc.exists) {
          const userData = userDoc.data();
          // token 또는 fcm_token 필드 확인
          const token = userData.token || userData.fcm_token;
          
          if (token) {
            userTokens.push(token);
          } else {
            console.log(`사용자 ${userId}의 FCM 토큰이 없습니다`);
          }
        } else {
          console.log(`사용자 ${userId}를 찾을 수 없습니다`);
        }
      } catch (error) {
        console.error(`사용자 ${userId}의 토큰 조회 중 오류:`, error);
      }
    }

    if (userTokens.length === 0) {
      console.log('FCM 토큰을 가진 사용자가 없습니다');
      res.status(404).send({ error: '알림을 보낼 사용자가 없습니다' });
      return;
    }

    // 메시지를 한 번에 최대 500개까지만 전송
    const MAX_MULTICAST_SIZE = 500;
    const tokenBatches = [];
    
    for (let i = 0; i < userTokens.length; i += MAX_MULTICAST_SIZE) {
      tokenBatches.push(userTokens.slice(i, i + MAX_MULTICAST_SIZE));
    }

    const results = [];
    
    // 각 배치에 대해 멀티캐스트 메시지 전송
    for (const tokenBatch of tokenBatches) {
      // 알림 메시지 구성
      const message = {
        notification: {
          title: chatRoomName || '새 채팅 메시지',
          body: `${senderName}: ${messageText.length > 100 ? messageText.substring(0, 97) + '...' : messageText}`,
          sound: 'default',
        },
        data: {
          chatRoomId: chatRoomId,
          senderId: senderId,
          senderName: senderName,
          chatRoomName: chatRoomName || '',
          type: 'chat_message',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: 'default',
            },
          },
        },
        tokens: tokenBatch,
      };

      try {
        // FCM 멀티캐스트 메시지 전송
        const response = await admin.messaging().sendMulticast(message);
        console.log(`멀티캐스트 알림 전송 성공 (${tokenBatch.length}명): 성공 ${response.successCount}, 실패 ${response.failureCount}`);
        results.push({
          total: tokenBatch.length,
          success: response.successCount,
          failure: response.failureCount
        });
      } catch (error) {
        console.error('멀티캐스트 알림 전송 실패:', error);
        results.push({
          total: tokenBatch.length,
          success: 0,
          failure: tokenBatch.length,
          error: error.message
        });
      }
    }

    res.status(200).send({ 
      success: true, 
      message: '채팅 알림 처리가 완료되었습니다', 
      results 
    });
  } catch (error) {
    console.error('채팅 알림 처리 중 오류 발생:', error);
    res.status(500).send({ error: error.message });
  }
});

// 공통 알림 로직을 함수로 분리
async function handleMessageNotification(newData, previousData, documentPath) {
    // lastMessage가 변경되었을 때만 실행
    if (newData.lastMessage === previousData.lastMessage) {
        return null;
    }
    
    try {
        const driverId = newData.driver_id;
        const senderId = newData.last_message_sender_id;
        
        console.log(`[${documentPath}] 메시지 정보:`, {
            senderId,
            driverId,
            lastMessage: newData.lastMessage,
            senderName: newData.last_message_sender_name,
            members: newData.members
        });
        
        // 메시지 발신자가 드라이버인지 확인
        const isFromDriver = senderId === driverId;
        console.log(`[${documentPath}] 드라이버가 보낸 메시지인가:`, isFromDriver);
        
        // 수신자 정보 설정
        let receiverId, receiverCollection;
        if (isFromDriver) {
            // 드라이버가 보낸 경우 -> 사용자에게 전송
            receiverId = newData.members[0];
            receiverCollection = 'users';
        } else {
            // 사용자가 보낸 경우 -> 드라이버에게 전송
            receiverId = driverId;
            receiverCollection = 'drivers';
        }
        
        console.log(`[${documentPath}] 수신자 정보:`, {
            receiverId,
            receiverCollection,
            isFromDriver
        });
        
        // 수신자 문서 가져오기
        const receiverDoc = await admin.firestore().collection(receiverCollection).doc(receiverId).get();
        
        if (!receiverDoc.exists) {
            console.log(`[${documentPath}] 수신자 문서 없음:`, receiverCollection, receiverId);
            return null;
        }
        
        const receiverData = receiverDoc.data();
        console.log(`[${documentPath}] 수신자 데이터:`, receiverData);
        
        // 토큰 확인 (fcm_token 또는 token 필드 체크)
        const receiverToken = receiverData.fcm_token || receiverData.token;
        
        if (!receiverToken) {
            console.log(`[${documentPath}] 수신자 토큰 없음:`, receiverCollection, receiverId);
            return null;
        }
        
        console.log(`[${documentPath}] 사용할 토큰:`, receiverToken);
        
        const senderName = newData.last_message_sender_name || '알 수 없음';
        
        const message = {
            token: receiverToken,
            notification: {
                title: `${senderName}님의 메시지`,
                body: newData.lastMessage,
                badge: 1
            },
            apns: {
                headers: {
                    'apns-priority': '10',
                    'apns-push-type': 'alert',
                    'apns-topic': 'com.plo.cabrider',
                    'apns-expiration': '0'
                },
                payload: {
                    aps: {
                        alert: {
                            title: `${senderName}님의 메시지`,
                            body: newData.lastMessage,
                            'launch-image': 'default'
                        },
                        badge: 1,
                        sound: 'default',
                        'mutable-content': 1,
                        'content-available': 1,
                        'category': 'NEW_MESSAGE_CATEGORY'
                    },
                    messageData: {
                        type: 'chat_message',
                        senderId: senderId,
                        chatId: documentPath
                    }
                }
            }
        };

        console.log(`[${documentPath}] 전송할 메시지:`, JSON.stringify(message, null, 2));
        
        const response = await admin.messaging().send(message);
        console.log(`[${documentPath}] 알림 전송 완료:`, {
            isFromDriver,
            receiverType: isFromDriver ? '사용자' : '드라이버',
            response
        });
        
    } catch (error) {
        console.error(`[${documentPath}] 에러:`, error);
        console.error(`[${documentPath}] 에러 상세:`, {
            errorCode: error.code,
            errorMessage: error.message,
            errorDetails: error.details
        });
    }
}

// 모든 채팅 메시지에 대한 알림 처리
exports.sendChatMessageNotification = functions.firestore
    .onDocumentUpdated('{collection}/{documentId}', async (event) => {
        const collection = event.params.collection;
        const documentId = event.params.documentId;
        
        // 채팅 관련 컬렉션인지 확인
        if (!collection.includes('To')) {
            return null;
        }
        
        return handleMessageNotification(
            event.data.after.data(),
            event.data.before.data(),
            `${collection}/${documentId}`
        );
    });
