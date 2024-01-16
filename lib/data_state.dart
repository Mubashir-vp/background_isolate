
part of 'data_bloc.dart';

abstract class DataState extends Equatable {
  const DataState();

  @override
  List<Object> get props => [];
}

class DataInitial extends DataState {}

class DataLoading extends DataState {}

class DataLoaded extends DataState {
  final List<DataModel> dataList;

  const DataLoaded(this.dataList);

  @override
  List<Object> get props => [dataList];
}

class DataError extends DataState {
  final String message;

  const DataError(this.message);

  @override
  List<Object> get props => [message];
}