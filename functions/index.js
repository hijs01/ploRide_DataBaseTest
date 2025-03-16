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
const logger = require('firebase-functions/logger');
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// 라이드 요청이 생성될 때 드라이버에게 알림 보내기
exports.sendRideRequestNotification = onValueCreated('/rideRequest/{rideId}', async (event) => {
  const rideData = event.data.val();
  
  if (!rideData) {
    console.log('라이드 데이터가 없습니다');
    return null;
  }

  console.log('새로운 라이드 요청:', rideData);

  try {
    // 드라이버의 FCM 토큰 가져오기
    const driverRef = admin.database().ref(`drivers/${rideData.driver_id}`);
    const driverSnapshot = await driverRef.once('value');
    const driverData = driverSnapshot.val();

    if (!driverData || !driverData.fcm_token) {
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
        ride_id: event.params.rideId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        destination: rideData.destination_address || '',
        pickup: rideData.pickup_address || '',
        rider_name: rideData.rider_name || '',
        rider_phone: rideData.rider_phone || '',
      },
      token: driverData.fcm_token,
    };

    // FCM 메시지 전송
    const response = await admin.messaging().send(message);
    console.log('알림 전송 성공:', response);
    
    // 알림 전송 상태 업데이트
    await event.data.ref.update({
      notification_sent: true,
      notification_sent_at: admin.database.ServerValue.TIMESTAMP,
    });

    return null;
  } catch (error) {
    console.error('알림 전송 실패:', error);
    return null;
  }
});

// 라이드 상태가 변경될 때 승객에게 알림 보내기
exports.sendRideStatusNotification = onValueUpdated('/rideRequest/{rideId}/status', async (event) => {
  const newStatus = event.data.after.val();
  const rideId = event.params.rideId;

  try {
    // 라이드 정보 가져오기
    const rideSnapshot = await admin.database()
      .ref(`/rideRequest/${rideId}`)
      .once('value');
    
    const rideData = rideSnapshot.val();
    if (!rideData || !rideData.user_id) {
      console.log('라이드 데이터 또는 사용자 ID를 찾을 수 없습니다');
      return null;
    }

    // 승객의 FCM 토큰 가져오기
    const userSnapshot = await admin.database()
      .ref(`/users/${rideData.user_id}`)
      .once('value');
    
    const userData = userSnapshot.val();
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

    return null;
  } catch (error) {
    console.error('상태 변경 알림 전송 실패:', error);
    return null;
  }
});
