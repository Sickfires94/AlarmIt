import 'dart:core';

import 'package:alarm_it/Services/AlarmFirestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../Models/AlarmSettings.dart';

abstract class AlarmEvent {}
class fetchAlarms extends AlarmEvent{}

abstract class AlarmState{}
class AlarmsInitial extends AlarmState{}
class AlarmsLoading extends AlarmState{}


// class AlarmSyncing extends AlarmState{
//     final List<AlarmCustom?> alarms;
//     AlarmSyncing(this.alarms);
// }

class AlarmsLoaded extends AlarmState{
    final List<AlarmCustom> alarms;
    AlarmsLoaded(this.alarms);
}

class AlarmListBloc extends Bloc<AlarmEvent, AlarmState>{
    AlarmListBloc() : super(AlarmsInitial()){
        on<fetchAlarms> (_onFetchAlarms);
    }

    Future<void> _onFetchAlarms(
        fetchAlarms event,
        Emitter<AlarmState> emit
        ) async {
        emit(AlarmsLoading());
        print("Loading Alarms");
        List<AlarmCustom?> nullableAlarms = await AlarmFirestoreService().getAlarms();
        print("Recieved Alarms" + nullableAlarms.toString());
        List<AlarmCustom> alarms = getNonNullableAlarms(nullableAlarms);
        print("Converted Alarms" + alarms.toString());
        emit(AlarmsLoaded(alarms));
    }

    List<AlarmCustom> getNonNullableAlarms(List<AlarmCustom?> alarms){
        List<AlarmCustom> nonNullableAlarms = [];

        for(final alarm in alarms){
            if (alarm != null) nonNullableAlarms.add(alarm);
        }

        return nonNullableAlarms;
    }

}
