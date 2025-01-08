import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alarm_it/Models/AlarmSettings.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlarmFirestoreService{


  static final CollectionReference _collectionRef = FirebaseFirestore.instance.collection('Alarms');

  void saveAlarm(AlarmCustom alarm){
    print("************* Saving Alarm to firebase ******************");
    final currentUser = FirebaseAuth.instance.currentUser;
    if(currentUser != null){
    _collectionRef
        .add({
      "user": currentUser.uid,
      "alarm": alarm.toJson()
    }).then((res){
      print("Response = " + res.toString());
    });
  }}

  Future<void> editAlarm(AlarmCustom alarm) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      try {
        await _collectionRef
            .where('user', isEqualTo: currentUser.uid)
            .where('alarm.id', isEqualTo: alarm.id)
            .limit(1)
            .get()
            .then((QuerySnapshot querySnapshot) {
          if (querySnapshot.docs.isNotEmpty) {
            querySnapshot.docs.first.reference.update({
              'alarm': alarm.toJson(),
            });
          } else {
            print("Alarm with this ID and user does not exist.");
          }
        });
      } catch (e) {
        print("Error editing alarm: $e");
      }
    }
  }


  Future<void> deleteAlarm(int alarmID) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      print("Deleting Alarm");
      try {
        await _collectionRef
            .where('user', isEqualTo: currentUser.uid)
            .where('alarm.id', isEqualTo: alarmID)
            .limit(1)
            .get()
            .then((QuerySnapshot querySnapshot) {
          if (querySnapshot.docs.isNotEmpty) {
            querySnapshot.docs.first.reference.delete();
            print("Alarm Deleted");
          } else {
            print("Alarm with ID $alarmID and user does not exist.");
          }
        });
      } catch (e) {
        print("Error deleting alarm: $e");
      }
    }
  }


  Future<List<AlarmCustom?>> getAlarms() async{

    var user = FirebaseAuth.instance.currentUser;

    print("Waiting for login");
    while(user == null) user = FirebaseAuth.instance.currentUser;
    print("Getting Alarms");

    QuerySnapshot querySnapshot = await _collectionRef.where('user', isEqualTo: user.uid).get();
    print("Received Data");
    // Get data from docs and convert map to List
    List<AlarmCustom?> allData = querySnapshot.docs.map((doc) => AlarmCustom.fromJson(doc['alarm'])).toList();
    print("***************** DATA *******************");

    return allData;

  }


}