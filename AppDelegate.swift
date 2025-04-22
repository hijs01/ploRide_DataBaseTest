import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import UserNotifications
import FirebaseFirestore

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        
        if #available(iOS 10.0, *) {
            // UNUserNotificationCenter 설정
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: { granted, error in
                    print("푸시 알림 권한 요청 결과:", granted)
                    if let error = error {
                        print("푸시 알림 권한 에러:", error)
                        return
                    }
                    
                    DispatchQueue.main.async {
                        application.registerForRemoteNotifications()
                    }
                }
            )
        } else {
            let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
            application.registerForRemoteNotifications()
        }
        
        // FCM 델리게이트 설정
        Messaging.messaging().delegate = self
        
        // FCM 자동 등록 활성화
        Messaging.messaging().isAutoInitEnabled = true
        
        return true
    }
    
    // FCM 토큰을 받았을 때 호출되는 메서드
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token:", fcmToken ?? "nil")
        
        // 현재 로그인된 사용자의 UID 가져오기
        if let userId = Auth.auth().currentUser?.uid {
            // Firestore에 토큰 저장
            let db = Firestore.firestore()
            db.collection("users").document(userId).setData([
                "fcm_token": fcmToken ?? "",
                "token_updated_at": FieldValue.serverTimestamp()
            ], merge: true) { err in
                if let err = err {
                    print("토큰 저장 에러:", err)
                } else {
                    print("토큰 저장 성공")
                }
            }
        } else {
            print("사용자가 로그인되어 있지 않음")
        }
        
        // 토큰 갱신 노티피케이션 발송
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: ["token": fcmToken ?? ""]
        )
    }
    
    // 푸시 알림을 받았을 때 호출되는 메서드 (앱이 포그라운드 상태일 때)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("수신된 알림 (포그라운드):", userInfo)
        
        // 포그라운드에서도 알림 표시
        if #available(iOS 14.0, *) {
            completionHandler([[.banner, .list, .sound, .badge]])
        } else {
            completionHandler([[.alert, .sound, .badge]])
        }
    }
    
    // 푸시 알림을 탭했을 때 호출되는 메서드
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("알림 탭:", userInfo)
        
        completionHandler()
    }
    
    // 원격 알림 등록 성공 시 호출
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        print("APNs 토큰 등록 성공:", deviceToken.map { String(format: "%02.2hhx", $0) }.joined())
    }
    
    // 원격 알림 등록 실패 시 호출
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs 토큰 등록 실패:", error)
    }
    
    // 백그라운드에서 알림을 받았을 때 호출
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("백그라운드 알림 수신:", userInfo)
        
        completionHandler(.newData)
    }
} 