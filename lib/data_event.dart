part of 'data_bloc.dart';

abstract class DataEvent extends Equatable {
  const DataEvent();

  @override
  List<Object> get props => [];
}

class FetchData extends DataEvent {}

class AddData extends DataEvent {
  final DateTime dateTime;

  const AddData(this.dateTime);

  @override
  List<Object> get props => [dateTime];
}
